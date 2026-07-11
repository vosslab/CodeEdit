#!/usr/bin/env python3
"""Measure per-keystroke latency in the plain editor and record a baseline.

Generates a roughly 1 MB Swift-like source fixture in a temp path, launches
./.build/debug/SwiftlyCodeEdit with CODEEDIT_DEBUG_SOURCE_FILE pointed at the
fixture and CODEEDIT_KEYSTROKE_BENCH=200, and --kill-after as a backstop.
Parses every KEYSTROKE_MS marker from the runtime log, reports min/median/p95,
and writes test-results/perf/keystroke_latency.txt with the stats plus
hw.model, macOS version, swift toolchain version, the HEAD git commit, and a
code_state note. Each KEYSTROKE_MS value times the full end-to-end edit window
(mutation + status refresh + span compute + attribute paint + layout), because
the bench waits on the highlighter's completion seam before recording each edit.

Gate design is two-part and not both wired up yet:
  --record-baseline (default): records the measured p95 as the new baseline
    file and always exits 0, regardless of the numbers. Use this to establish
    or refresh the recorded baseline.
  --gate: exits non-zero when p95 exceeds the absolute budget (16 ms) or
    exceeds the recorded baseline by more than 20 percent. This flag is
    reserved for a later work package (WP-Q6) to switch on; passing it today
    still runs the same measurement, only the exit behavior differs.

Single-writer rule: /tmp/codeedit_runtime.log is a single shared file written
by every DEBUG build of SwiftlyCodeEdit (see CodeEdit/Utils/DebugRuntimeLog.swift)
and read by every e2e harness in this repo (e2e_launch_time.py, e2e_screenshot_colors.py,
scripts/plain_editor_smoke.sh, this file). Only one SwiftlyCodeEdit process, and only
one harness reading or clearing that log, may run at a time. A second concurrent
launch clears or interleaves into the same file and silently corrupts whichever
harness is mid-run. This harness refuses to start while another SwiftlyCodeEdit
process is already running; it cannot detect a concurrent harness script, so
callers are still responsible for not running two log-touching harnesses at once.
"""

# Standard Library
import re
import os
import time
import argparse
import pathlib
import statistics
import subprocess

EDIT_COUNT = 200
# Each measured edit now waits for the whole-document rehighlight it triggers to
# repaint (span compute + attribute paint + layout), so per-edit cost runs a few
# seconds and the full 200-edit run can exceed 15 minutes on the baseline
# hardware. The poll deadline bounds the harness; --kill-after is the app's own
# self-terminate backstop and must exceed the run length, so it sits above the
# poll deadline (the harness terminates the app itself the moment DONE appears).
KILL_AFTER_SECONDS = 2700
LAUNCH_TIMEOUT_SECONDS = 30
BENCH_POLL_DEADLINE_SECONDS = 2400
FIXTURE_TARGET_BYTES = 1_000_000
BUDGET_P95_MS = 16.0
REGRESSION_THRESHOLD_FRACTION = 0.20
RUNTIME_LOG_PATH = pathlib.Path("/tmp/codeedit_runtime.log")  # nosec B108 - fixed path written by DebugRuntimeLog.swift
FIXTURE_PATH = pathlib.Path("/tmp/codeedit_e2e_keystroke_latency_fixture.swift")  # nosec B108 - fixed scratch path for this harness
KEYSTROKE_MS_PATTERN = re.compile(r"KEYSTROKE_MS=([0-9.]+)")
KEYSTROKE_DONE_PATTERN = re.compile(r"KEYSTROKE_BENCH_DONE=(\d+)")
# The synchronous status-bar refresh cost per keystroke, logged by the chrome
# model (CodeFileView.swift). KEYSTROKE_MS is the whole edit window (mutation +
# status refresh + highlight); parsing STATUS_REFRESH_MS separately makes a
# future status-subsystem regression attributable rather than hidden inside the
# combined number (WP-Q2 follow-on).
STATUS_REFRESH_MS_PATTERN = re.compile(r"STATUS_REFRESH_MS=([0-9.]+)")


#============================================
def parse_args() -> argparse.Namespace:
	"""Parse command-line arguments.

	Returns:
		argparse.Namespace: parsed arguments with a record_baseline/gate mode.
	"""
	parser = argparse.ArgumentParser(description="Measure keystroke latency in the plain editor")
	mode_group = parser.add_mutually_exclusive_group()
	mode_group.add_argument(
		'-r', '--record-baseline', dest='record_baseline', action='store_true',
		help="record the measured p95 as the baseline and always exit 0",
	)
	mode_group.add_argument(
		'-g', '--gate', dest='record_baseline', action='store_false',
		help="exit non-zero on an absolute-budget or regression-threshold miss",
	)
	parser.set_defaults(record_baseline=True)
	args = parser.parse_args()
	return args


#============================================
def get_repo_root() -> pathlib.Path:
	"""Return the repository root via git rev-parse.

	Returns:
		pathlib.Path: absolute path to the repository root.
	"""
	result = subprocess.run(
		["git", "rev-parse", "--show-toplevel"],
		capture_output=True, text=True, check=True,
	)
	return pathlib.Path(result.stdout.strip())


#============================================
def get_git_commit() -> str:
	"""Return the current git commit sha via git rev-parse HEAD.

	Returns:
		str: the full HEAD commit sha, so a recorded baseline is attributable
			to a specific revision for later regression comparison.
	"""
	result = subprocess.run(
		["git", "rev-parse", "HEAD"],
		capture_output=True, text=True, check=True,
	)
	return result.stdout.strip()


#============================================
def get_app_path(repo_root: pathlib.Path) -> pathlib.Path:
	"""Return the built debug binary path, failing loudly if it is missing.

	Args:
		repo_root: repository root path.

	Returns:
		pathlib.Path: path to the built SwiftlyCodeEdit debug binary.
	"""
	app_path = repo_root / ".build" / "debug" / "SwiftlyCodeEdit"
	if not app_path.exists():
		raise FileNotFoundError(
			f"Built app not found at {app_path}. Run ./build_debug.sh first."
		)
	return app_path


#============================================
def generate_fixture_file(fixture_path: pathlib.Path) -> int:
	"""Write a roughly 1 MB Swift-like source fixture to a temp path.

	The fixture is generated at runtime and is never a committed repo file.

	Args:
		fixture_path: destination path for the generated fixture.

	Returns:
		int: the size in bytes of the written fixture.
	"""
	function_template = (
		"func plainEditorBenchSample_{index}(value: Int) -> Int {{\n"
		"    let doubled = value * 2\n"
		"    let label = \"sample line {index}\"\n"
		"    if doubled > 0 {{\n"
		"        return doubled + label.count\n"
		"    }}\n"
		"    return value\n"
		"}}\n\n"
	)

	fixture_text = ""
	function_index = 0
	while len(fixture_text) < FIXTURE_TARGET_BYTES:
		fixture_text += function_template.format(index=function_index)
		function_index += 1

	fixture_path.write_text(fixture_text)
	return len(fixture_text.encode("utf-8"))


#============================================
def get_hardware_model() -> str:
	"""Return the Mac hardware model string via sysctl.

	Returns:
		str: the hw.model sysctl value.
	"""
	result = subprocess.run(
		["sysctl", "-n", "hw.model"],
		capture_output=True, text=True, check=True,
	)
	return result.stdout.strip()


#============================================
def get_macos_version() -> str:
	"""Return the macOS product version via sw_vers.

	Returns:
		str: the macOS productVersion string.
	"""
	result = subprocess.run(
		["sw_vers", "-productVersion"],
		capture_output=True, text=True, check=True,
	)
	return result.stdout.strip()


#============================================
def get_swift_version() -> str:
	"""Return the swift toolchain version string via `swift --version`.

	Returns:
		str: the first line of `swift --version` output.
	"""
	result = subprocess.run(
		["swift", "--version"],
		capture_output=True, text=True, check=True,
	)
	return result.stdout.strip().splitlines()[0]


#============================================
def refuse_if_another_codeedit_is_running() -> None:
	"""Raise if a SwiftlyCodeEdit process is already running.

	Enforces the single-writer rule on /tmp/codeedit_runtime.log: a second
	concurrent app instance would clear or interleave into the same log this
	harness is reading, silently corrupting the in-flight measurement.

	Raises:
		RuntimeError: another SwiftlyCodeEdit process is already alive.
	"""
	result = subprocess.run(
		["pgrep", "-x", "SwiftlyCodeEdit"],
		capture_output=True, text=True,
	)
	running_pids = result.stdout.strip()
	if running_pids:
		raise RuntimeError(
			"Another SwiftlyCodeEdit process is already running (pid(s) "
			f"{running_pids}). It shares /tmp/codeedit_runtime.log with this harness; "
			"wait for it to exit before starting a new keystroke latency run."
		)


#============================================
def wait_for_bench_done(process: subprocess.Popen, deadline_seconds: float) -> str:
	"""Poll the runtime log until KEYSTROKE_BENCH_DONE appears or the deadline passes.

	Checks the app process each pass so a crash fails fast with the log tail,
	rather than hanging until the full deadline elapses.

	Args:
		process: the launched app process, polled for early exit each pass.
		deadline_seconds: maximum number of seconds to poll before giving up.

	Returns:
		str: the full runtime log text once the done marker is found.

	Raises:
		RuntimeError: the app exited before the marker appeared, or the deadline
			passed with no marker.
	"""
	poll_interval_seconds = 0.5
	elapsed_seconds = 0.0
	while elapsed_seconds < deadline_seconds:
		if process.poll() is not None:
			runtime_log_text = RUNTIME_LOG_PATH.read_text()
			log_tail = "\n".join(runtime_log_text.splitlines()[-20:])
			raise RuntimeError(
				f"SwiftlyCodeEdit exited early (code {process.returncode}) before "
				f"KEYSTROKE_BENCH_DONE appeared. Last runtime log lines:\n{log_tail}"
			)
		runtime_log_text = RUNTIME_LOG_PATH.read_text()
		if KEYSTROKE_DONE_PATTERN.search(runtime_log_text) is not None:
			return runtime_log_text
		time.sleep(poll_interval_seconds)
		elapsed_seconds += poll_interval_seconds
	raise RuntimeError(
		f"KEYSTROKE_BENCH_DONE marker not found in runtime log after {deadline_seconds} seconds."
	)


#============================================
def terminate_process(process: subprocess.Popen) -> None:
	"""Terminate the app process if still alive, escalating to kill if it lingers.

	Args:
		process: the launched app process to shut down.
	"""
	if process.poll() is not None:
		return
	process.terminate()
	if wait_for_exit(process, LAUNCH_TIMEOUT_SECONDS):
		return
	# terminate did not take; escalate to a hard kill so the run cannot leak a
	# process onto the shared runtime log.
	process.kill()
	wait_for_exit(process, LAUNCH_TIMEOUT_SECONDS)


#============================================
def wait_for_exit(process: subprocess.Popen, timeout_seconds: float) -> bool:
	"""Wait up to timeout_seconds for the process to exit.

	Args:
		process: the process to wait on.
		timeout_seconds: maximum seconds to wait.

	Returns:
		bool: True if the process exited within the timeout, False otherwise.
	"""
	deadline = time.monotonic() + timeout_seconds
	while time.monotonic() < deadline:
		if process.poll() is not None:
			return True
		time.sleep(0.1)
	return process.poll() is not None


#============================================
def run_bench(app_path: pathlib.Path, fixture_path: pathlib.Path) -> list[float]:
	"""Launch the app, poll for completion, and parse the marker lines.

	The bench edits dirty the document, so the app's own --kill-after quit path
	blocks on the standard unsaved-changes save prompt and never actually exits.
	Instead of waiting on the process to exit on its own, this polls the runtime
	log for the KEYSTROKE_BENCH_DONE marker and then terminates the process
	itself. --kill-after is still passed as a validation-only backstop.

	Args:
		app_path: path to the built app binary.
		fixture_path: fixture source file to open on launch.

	Returns:
		tuple[list[float], list[float]]: the measured KEYSTROKE_MS values (one per
			simulated edit) and every STATUS_REFRESH_MS value logged during the run.
	"""
	refuse_if_another_codeedit_is_running()

	# Clear the shared runtime log before this run so its markers cannot be
	# confused with markers left over from a prior run.
	RUNTIME_LOG_PATH.write_text("")

	launch_env = os.environ.copy()
	launch_env["CODEEDIT_DEBUG_SOURCE_FILE"] = str(fixture_path)
	launch_env["CODEEDIT_KEYSTROKE_BENCH"] = str(EDIT_COUNT)

	process = subprocess.Popen(
		[str(app_path), f"--kill-after={KILL_AFTER_SECONDS}"],
		env=launch_env,
	)

	# Always terminate the launched app, whether the bench finished, timed out,
	# or the app crashed mid-run, so a failure never leaves a stray instance
	# holding the shared runtime log.
	try:
		runtime_log_text = wait_for_bench_done(process, deadline_seconds=BENCH_POLL_DEADLINE_SECONDS)
	finally:
		terminate_process(process)

	keystroke_times_ms = [float(value) for value in KEYSTROKE_MS_PATTERN.findall(runtime_log_text)]
	if len(keystroke_times_ms) != EDIT_COUNT:
		raise RuntimeError(
			f"Expected {EDIT_COUNT} KEYSTROKE_MS markers, found {len(keystroke_times_ms)}."
		)
	status_times_ms = [float(value) for value in STATUS_REFRESH_MS_PATTERN.findall(runtime_log_text)]
	return keystroke_times_ms, status_times_ms


#============================================
def compute_percentile_95(values: list[float]) -> float:
	"""Return the 95th percentile of the given values using linear interpolation.

	Args:
		values: measured values.

	Returns:
		float: the 95th percentile value.
	"""
	sorted_values = sorted(values)
	rank = 0.95 * (len(sorted_values) - 1)
	lower_index = int(rank)
	upper_index = min(lower_index + 1, len(sorted_values) - 1)
	fraction = rank - lower_index
	interpolated = sorted_values[lower_index] + fraction * (sorted_values[upper_index] - sorted_values[lower_index])
	return interpolated


#============================================
def read_recorded_baseline_p95(results_file: pathlib.Path) -> float | None:
	"""Read the previously recorded p95_ms value from the results file, if any.

	Args:
		results_file: path to the results report file.

	Returns:
		float | None: the recorded p95_ms value, or None if no baseline exists.
	"""
	if not results_file.exists():
		return None
	report_text = results_file.read_text()
	match = re.search(r"^p95_ms=([0-9.]+)$", report_text, re.MULTILINE)
	if match is None:
		return None
	return float(match.group(1))


#============================================
def bounded_code_state() -> str:
	"""Describe the bounded-rehighlight measurement window for the report.

	Reads the same CODEEDIT_HIGHLIGHT_STRATEGY switch the Swift side reads, so the
	recorded code_state names the region strategy that actually ran.

	Returns:
		str: a code_state description naming the active WP-Q6 region strategy.
	"""
	# The Swift default (no env, or "edited") is the shipped edited-line window.
	strategy = os.environ.get("CODEEDIT_HIGHLIGHT_STRATEGY", "edited")
	if strategy == "visible":
		region_note = "visible-range window (viewport lines)"
	else:
		region_note = "edited-line window (edited line plus 40 context lines each side)"
	code_state = (
		"WP-Q6 bounded rehighlight, " + region_note + "; end-to-end per-edit "
		"window: mutation + status refresh + bounded region span compute + "
		"attribute paint + layout (settled via PlainSyntaxHighlighter completion seam)"
	)
	return code_state


#============================================
def write_results_report(
	results_file: pathlib.Path, hardware_model: str, macos_version: str, swift_version: str,
	git_commit: str, fixture_bytes: int, keystroke_times_ms: list[float],
	min_ms: float, median_ms: float, p95_ms: float, status_times_ms: list[float],
) -> None:
	"""Write the measured keystroke latency stats and environment info to a report.

	Args:
		results_file: destination path for the report.
		hardware_model: the hw.model sysctl value.
		macos_version: the macOS productVersion string.
		swift_version: the swift toolchain version string.
		git_commit: the HEAD commit sha this baseline was measured against.
		fixture_bytes: size in bytes of the generated fixture.
		keystroke_times_ms: all measured KEYSTROKE_MS values.
		min_ms: minimum of keystroke_times_ms.
		median_ms: median of keystroke_times_ms.
		p95_ms: 95th percentile of keystroke_times_ms.
		status_times_ms: every STATUS_REFRESH_MS value logged during the run, the
			synchronous status-bar cost isolated from the highlight cost.
	"""
	# Records the measurement window and the active bounded-rehighlight strategy so
	# a later reader knows each KEYSTROKE_MS value is end-to-end (mutation through
	# paint), and which WP-Q6 region strategy produced it.
	code_state = bounded_code_state()
	report_lines = []
	report_lines.append(f"hardware_model={hardware_model}")
	report_lines.append(f"macos_version={macos_version}")
	report_lines.append(f"swift_version={swift_version}")
	report_lines.append(f"git_commit={git_commit}")
	report_lines.append(f"code_state={code_state}")
	report_lines.append(f"edit_count={EDIT_COUNT}")
	report_lines.append(f"fixture_bytes={fixture_bytes}")
	report_lines.append(f"min_ms={min_ms}")
	report_lines.append(f"median_ms={median_ms}")
	report_lines.append(f"p95_ms={p95_ms}")
	report_lines.append(f"budget_p95_ms={BUDGET_P95_MS}")
	report_lines.append(f"regression_threshold_fraction={REGRESSION_THRESHOLD_FRACTION}")
	# The status-bar refresh cost, reported separately so a status regression is
	# attributable and not hidden inside the combined keystroke number.
	if status_times_ms:
		report_lines.append(f"status_refresh_min_ms={min(status_times_ms)}")
		report_lines.append(f"status_refresh_median_ms={statistics.median(status_times_ms)}")
		report_lines.append(f"status_refresh_p95_ms={compute_percentile_95(status_times_ms)}")
		report_lines.append(f"status_refresh_count={len(status_times_ms)}")
	report_text = "\n".join(report_lines) + "\n"

	results_file.parent.mkdir(parents=True, exist_ok=True)
	results_file.write_text(report_text)


#============================================
def main() -> None:
	"""Measure keystroke latency once, record or gate on the result."""
	args = parse_args()
	repo_root = get_repo_root()
	app_path = get_app_path(repo_root)

	fixture_bytes = generate_fixture_file(FIXTURE_PATH)
	print(f"generated fixture: {FIXTURE_PATH} ({fixture_bytes} bytes)")

	results_file = repo_root / "test-results" / "perf" / "keystroke_latency.txt"
	recorded_baseline_p95_ms = read_recorded_baseline_p95(results_file)

	keystroke_times_ms, status_times_ms = run_bench(app_path, FIXTURE_PATH)
	min_ms = min(keystroke_times_ms)
	median_ms = statistics.median(keystroke_times_ms)
	p95_ms = compute_percentile_95(keystroke_times_ms)
	print(f"min_ms={min_ms} median_ms={median_ms} p95_ms={p95_ms}")

	# Report the status-bar refresh cost on its own so it can be tracked apart from
	# the highlight cost that dominates the combined keystroke window.
	if status_times_ms:
		status_p95_ms = compute_percentile_95(status_times_ms)
		print(
			f"status_refresh_ms: min={min(status_times_ms)} "
			f"median={statistics.median(status_times_ms)} p95={status_p95_ms} "
			f"count={len(status_times_ms)}"
		)

	hardware_model = get_hardware_model()
	macos_version = get_macos_version()
	swift_version = get_swift_version()
	git_commit = get_git_commit()
	write_results_report(
		results_file, hardware_model, macos_version, swift_version,
		git_commit, fixture_bytes, keystroke_times_ms, min_ms, median_ms, p95_ms, status_times_ms,
	)
	print(f"wrote results to {results_file}")

	if args.record_baseline:
		print("record-baseline mode: exiting 0 regardless of the measured numbers")
		return

	if p95_ms > BUDGET_P95_MS:
		raise SystemExit(f"KEYSTROKE_MS p95 {p95_ms} exceeds absolute budget {BUDGET_P95_MS}")

	if recorded_baseline_p95_ms is None:
		raise SystemExit("No recorded baseline p95_ms found. Run with --record-baseline first.")

	regression_limit_ms = recorded_baseline_p95_ms * (1 + REGRESSION_THRESHOLD_FRACTION)
	if p95_ms > regression_limit_ms:
		raise SystemExit(
			f"KEYSTROKE_MS p95 {p95_ms} exceeds regression limit {regression_limit_ms} "
			f"({REGRESSION_THRESHOLD_FRACTION * 100:.0f}% over recorded baseline {recorded_baseline_p95_ms})"
		)


if __name__ == '__main__':
	main()
