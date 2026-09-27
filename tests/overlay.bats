#!/usr/bin/env bats
# The shell the overlay ships and this repository can measure without
# changing a byte of it: the daily cron job. It names a command and nothing
# else, so a PATH stub is the whole fixture.
#
# COVERAGE.md says why usr/local/bin/turnkey-mysql-install-perf-info-schemas
# is not measured here.

setup() {
    unit="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"
    mkdir -p "$BATS_TEST_TMPDIR/stubs"
    cat > "$BATS_TEST_TMPDIR/stubs/mysqloptimize" <<'EOF'
#!/bin/sh
echo "mysqloptimize $*" >> "$CALLS"
[ -z "$OPTIMIZE_FAIL" ] || exit 3
EOF
    chmod 755 "$BATS_TEST_TMPDIR/stubs/mysqloptimize"
    export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
    cron="$unit/overlay/etc/cron.daily/mysqloptimize"
}

@test "the daily job optimizes every database and says nothing" {
    run bash "$cron"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(cat "$CALLS")" = "mysqloptimize --all-databases" ]
}

@test "the daily job reports the exit code of the command it runs" {
    OPTIMIZE_FAIL=1 run bash "$cron"
    [ "$status" -eq 3 ]
}

@test "the daily job is not executable, as the shared tree shipped it" {
    # Not a wish: cron.daily runs a file only when it is executable, so this
    # job has never run on any appliance built from the shared tree. The
    # extraction keeps the mode it found, because a component that changes
    # what the image does is not the same component. Fixing it belongs
    # upstream (decision 0008), and the layer that picks the fix up will be
    # the one whose changelog says so.
    [ ! -x "$cron" ]
}
