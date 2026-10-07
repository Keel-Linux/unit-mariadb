#!/usr/bin/env bats
# The shape fab and bt-layer require of a unit, checked here so that a
# mistake in this repository fails on a hosted runner in seconds instead of
# on the build host in minutes.
#
# The rules are bin/layer-lib of buildtasks: a unit carries at least one of
# plan, overlay, conf and removelist; a conf that is not executable is
# skipped by fab without a word; the version is a single token fab and the
# manifest can carry.

setup() {
    unit="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "the conf script is executable, or fab would skip it in silence" {
    [ -x "$unit/conf" ]
}

@test "the plan is there and names the four packages of the component" {
    [ -f "$unit/plan" ]
    run grep -c '^[a-z0-9]' "$unit/plan"
    [ "$output" = "4" ]
    grep -qx 'mysqltuner' "$unit/plan"
    grep -qx 'default-mysql-server' "$unit/plan"
    grep -qx 'python3-pymysql' "$unit/plan"
    grep -qx 'webmin-mysql' "$unit/plan"
}

@test "the version is one line a layer manifest can carry" {
    [ "$(wc -l < "$unit/version")" -eq 1 ]
    run cat "$unit/version"
    [[ "$output" =~ ^[A-Za-z0-9][A-Za-z0-9._+~-]*$ ]]
    [ "${#output}" -le 64 ]
}

@test "the version is the version of the newest changelog entry" {
    run head -n 1 "$unit/changelog"
    [ "$output" = "unit-mariadb-$(cat "$unit/version") (1) keel; urgency=low" ]
}

@test "the overlay ships exactly the files the shared tree had" {
    run bash -c "cd '$unit/overlay' && find . -type f | sort"
    [ "$status" -eq 0 ]
    expected="./etc/cron.daily/mysqloptimize
./etc/mysql/conf.d/force_utf8mb4.cnf
./usr/lib/confconsole/plugins.d/System_Settings/Mysql_perf_info.py
./usr/lib/inithooks/bin/mysqlconf.py
./usr/local/bin/turnkey-mysql-install-perf-info-schemas"
    [ "$output" = "$expected" ]
}

@test "no removelist and no conf-vars, which the changelog explains" {
    [ ! -e "$unit/removelist" ]
    [ ! -e "$unit/conf-vars" ]
}
