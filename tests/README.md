# Tests

    bats tests/                       every test
    COVERAGE_THRESHOLD=100 tests/coverage.sh    the gate, kcov over bats

Three files, three jobs:

- `conf.bats` runs the build time conf script for real against scratch
  directories. `service` and `mysql` are PATH stubs that record their calls
  and can be made to fail; a `tkl-bashlib` stub records any `dl()`, and the
  tests prove the script makes none and fetches nothing. Nothing needs root, a database or a network.
- `overlay.bats` covers the daily cron job the overlay ships, with a PATH
  stub, and records the mode it ships with.
- `unit.bats` checks the shape `fab` and `bt-layer` require of a unit, so a
  mistake here fails on a hosted runner in seconds rather than on the build
  host in minutes.

COVERAGE.md says which files are measured and why the other three are not.
