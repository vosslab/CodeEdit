# News

## v26.07 - 2026-07-09

### Highlights

- Renamed the product to SwiftlyCodeEdit: the executable product name, app
  menu title and Quit item, and launch/kill tooling all reflect the new name.
- Cut cold syntax-highlight time from 6293 ms to 67 ms on the ~1400-line smoke
  fixture, so opening a Swift file no longer stalls the editor window.
- Purged 721 files of dead legacy code no longer reachable from any live
  SwiftPM target: unused `Package.swift`-excluded source trees, orphaned test
  suites, unused helper-app directories, and two unused local packages
  (`CodeEditKit`, `WelcomeWindow`).
