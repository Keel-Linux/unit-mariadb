# Coverage

Standard: decisions 0003 (90 percent per repository, 95 for code the project
writes) and 0004 (bats plus kcov for shell). The acceptance test of a
component is the layer that consumes it: `keel-mariadb` builds it, boots it
in LXC and proves the database answers, which is why this repository does not
carry a boot test of its own.

## Measured 2026-10-07

| File | Test | Lines | Note |
| --- | --- | --- | --- |
| conf | tests/conf.bats (10 tests) | 100 percent (5/5) under kcov | every line and every failure path: no download and nothing fetched from the network, no need for tkl-bashlib, the init script symlink, the start and stop around the SQL, a server that does not start, a server that refuses the SQL, and a second run over the same tree |
| overlay/etc/cron.daily/mysqloptimize | tests/overlay.bats (3 tests) | 100 percent (1/1) under kcov | the command it runs, the exit code it returns, and the mode it ships with |
| overlay/usr/local/bin/turnkey-mysql-install-perf-info-schemas | none | 0 | see below |
| overlay/usr/lib/inithooks/bin/mysqlconf.py | none | 0 | see below |
| overlay/usr/lib/confconsole/plugins.d/System_Settings/Mysql_perf_info.py | none | 0 | see below |

Total over the two measured files: **100 percent (6/6)**, 19 bats tests over three files (conf, overlay, unit shape).
`tests/coverage.sh` fails below `COVERAGE_THRESHOLD`, which the workflow sets
to 100, the measured number. It is only ever raised (decision 0006).

    $ COVERAGE_THRESHOLD=100 tests/coverage.sh
    kcov line coverage (threshold 100 percent):
     100.00  1/1  mysqloptimize
     100.00  5/5  conf

## What is not measured, and what would change that

Three of the five files the overlay ships are not measured, and the reason is
the same for all three: **this repository may not change a byte of what the
image gets.** The extraction is proven by rebuilding the `mariadb` layer and
comparing it to a build from the shared tree, and a file edited to make it
testable would show up in that comparison as a difference the extraction
caused. So the only file that could be adapted is `conf`, which fab copies
into the chroot, runs and removes, and which therefore ships nowhere.

- `turnkey-mysql-install-perf-info-schemas` writes
  `/etc/mysql/conf.d/performance_schema.cnf` and unpacks a download under
  `/usr/local/src`, both absolute. Redirecting them needs two lines of the
  same kind the conf script got. Those two lines belong upstream (decision
  0008), and this file can be measured here on the day upstream takes them,
  or the day the project decides to carry a patched copy and say so in the
  changelog. Covering only the argument parsing and leaving the install path
  out would put the file in the report at about 60 percent, which would lower
  the gate for no gain.
- `mysqlconf.py` and `Mysql_perf_info.py` are Python, which decision 0003
  measures with pytest rather than kcov, and both are upstream code this
  component carries unchanged. `keel-mariadb` stubs `mysqlconf.py` in its own
  hook tests, so the path that matters to the appliance, the password
  reaching the database, is measured there.

## Plan

- Offer the three parameterisations upstream: the conf script ones this
  repository already carries, and the two
  `turnkey-mysql-install-perf-info-schemas` needs. Measure that file here
  once they land, and raise the gate.
- Add pytest coverage of `mysqlconf.py` when the inithooks fork gains a
  Dialog stub, which is the same blocker `keel-mariadb` records for
  `bin/dbpass.py`.
- The two upstream defects README.rst lists (a cron job that is not
  executable, a cleanup that never runs) are candidates for the same upstream
  pull request. Neither is fixed here, because a component that changes what
  the image does is not the same component.
