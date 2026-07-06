## 2026-07-06

### Fixes and Maintenance

- Replaced the upstream README with a shorter fork-focused front page.
- Linked the README to the docs that already exist in this repository.
- Added a root `build.sh` wrapper for `xcodebuild` on the `CodeEdit` scheme.
- Split the build helper into `build_debug.sh` and `build_release.sh` to match the app workflow.
- Added an early Xcode simulator-component check so build scripts fail with a clearer message when Xcode is incomplete.
- Vendored the CodeEdit-owned Swift packages into `Packages/` and rewired the project to use local package paths.
- Replaced the runtime `ZIPFoundation` dependency with a local unzip helper backed by the system `unzip` tool.
