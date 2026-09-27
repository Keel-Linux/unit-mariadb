#!/usr/bin/env bats
# The build time conf script of the component, run for real against scratch
# directories. Nothing here needs root, a database or a network: tkl-bashlib
# is a stub whose dl() writes the file it is asked for, and service and mysql
# are PATH stubs that record what they were called with.
#
# What these tests are about is the component's contract with the build:
# every line of the script runs once per image, it stops at the first failure
# (bash -e), and running it a second time over the same tree fails on the
# init script symlink. That last one is why bt-layer records the units a
# layer carries and why a child layer subtracts them instead of applying
# them again (decision 0010).

setup() {
    unit="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    root="$BATS_TEST_TMPDIR/root"
    export BIN="$root/usr/local/bin"
    export INITD="$root/etc/init.d"
    export TKL_BASHLIB="$BATS_TEST_TMPDIR/tkl-bashlib"
    mkdir -p "$BIN" "$INITD" "$TKL_BASHLIB" "$BATS_TEST_TMPDIR/stubs"
    : > "$INITD/mariadb"

    # tkl-bashlib, reduced to the one function the script uses. The real dl()
    # fetches a URL into a directory; this one writes the basename of the URL
    # and records the call, and honours DL_FAIL so a failed download can be
    # tested.
    cat > "$TKL_BASHLIB/init.sh" <<'EOF'
dl() {
    echo "dl $1 $2" >> "$CALLS"
    [ -z "$DL_FAIL" ] || return 1
    echo "content of $1" > "$2/$(basename "$1")"
}
EOF

    export CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"
    export SQL="$BATS_TEST_TMPDIR/sql"

    cat > "$BATS_TEST_TMPDIR/stubs/service" <<'EOF'
#!/bin/sh
echo "service $*" >> "$CALLS"
[ -z "$SERVICE_FAIL" ] || exit 1
EOF
    cat > "$BATS_TEST_TMPDIR/stubs/mysql" <<'EOF'
#!/bin/sh
echo "mysql $*" >> "$CALLS"
cat >> "$SQL"
[ -z "$MYSQL_FAIL" ] || exit 1
EOF
    chmod 755 "$BATS_TEST_TMPDIR/stubs/service" "$BATS_TEST_TMPDIR/stubs/mysql"
    export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
}

@test "downloads mysqltuner and its two data files into BIN" {
    run "$unit/conf"
    [ "$status" -eq 0 ]
    [ -x "$BIN/mysqltuner" ]
    [ ! -e "$BIN/mysqltuner.pl" ]
    [ -f "$BIN/basic_passwords.txt" ]
    [ -f "$BIN/vulnerabilities.csv" ]
}

@test "takes mysqltuner from the maintained repository, at master" {
    run "$unit/conf"
    [ "$status" -eq 0 ]
    grep -q 'jmrenouard/MySQLTuner-perl/refs/heads/master/mysqltuner.pl' "$CALLS"
}

@test "links the init script Debian no longer ships" {
    run "$unit/conf"
    [ "$status" -eq 0 ]
    [ "$(readlink "$INITD/mysql")" = "$INITD/mariadb" ]
}

@test "starts the server before the SQL and stops it after" {
    run "$unit/conf"
    [ "$status" -eq 0 ]
    mapfile -t calls < "$CALLS"
    [ "${calls[3]}" = "service mysql start" ]
    [[ "${calls[4]}" == mysql* ]]
    [ "${calls[5]}" = "service mysql stop" ]
    [ "${#calls[@]}" -eq 6 ]
}

@test "removes the anonymous users, the remote root and the test database" {
    run "$unit/conf"
    [ "$status" -eq 0 ]
    grep -q "DELETE FROM user WHERE User=''" "$SQL"
    grep -q "DELETE FROM user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" "$SQL"
    grep -q 'DROP DATABASE IF EXISTS test;' "$SQL"
    grep -q "DELETE FROM db WHERE Db='test' OR Db='test\\\\_%'" "$SQL"
}

@test "keeps root on the loopback of both families" {
    run "$unit/conf"
    [ "$status" -eq 0 ]
    grep -q "'::1'" "$SQL"
    grep -q "'127.0.0.1'" "$SQL"
}

@test "stops at a failed download and configures nothing" {
    DL_FAIL=1 run "$unit/conf"
    [ "$status" -ne 0 ]
    [ ! -e "$INITD/mysql" ]
    [ ! -s "$SQL" ]
}

@test "fails when the server does not start" {
    SERVICE_FAIL=1 run "$unit/conf"
    [ "$status" -ne 0 ]
    [ ! -s "$SQL" ]
}

@test "fails when the server refuses the SQL" {
    MYSQL_FAIL=1 run "$unit/conf"
    [ "$status" -ne 0 ]
    ! grep -q '^service mysql stop$' "$CALLS"
}

@test "fails on a second run over the same tree, which is why a child layer subtracts the unit" {
    run "$unit/conf"
    [ "$status" -eq 0 ]
    run "$unit/conf"
    [ "$status" -ne 0 ]
    [[ "$output" == *"File exists"* ]]
}

@test "fails when tkl-bashlib is not there" {
    rm -f "$TKL_BASHLIB/init.sh"
    run "$unit/conf"
    [ "$status" -ne 0 ]
}
