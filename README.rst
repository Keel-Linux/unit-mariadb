unit-mariadb
============

The MariaDB component of Keel Linux, as a fab unit: a directory carrying a
``plan``, an ``overlay/`` and an executable ``conf``, which fab resolves and
applies when the recipe being built has it under ``unit.d/`` (``UNIT_DIRS``
in ``share/product.mk``). Compatible with TurnKey Linux appliances: this is
the MariaDB half of ``turnkeylinux/common``, taken out of the shared tree so
that it can be released, pinned and rolled back on its own (decision 0010).

Why a repository, and why this name
-----------------------------------

Decision 0006 gives appliances the ``keel-`` prefix and leaves
infrastructure unprefixed. A component is neither: it is not an appliance,
and it is not a fork of an upstream repository. ``unit-`` says what the
artefact is in the vocabulary of the build system that consumes it, keeps
every component together in the organization listing, and maps mechanically
onto the directory a recipe assembles, because the name after the dash is
the directory name under ``unit.d`` and therefore the name that appears in
the layer manifest::

    keel-linux/unit-mariadb   ->   unit.d/mariadb   ->   units mariadb@1.0.0

The component is named ``mariadb`` and not ``mysql``, which is what the
shared tree calls it, because the server is MariaDB, the layer is
``mariadb`` and the appliance is ``keel-mariadb``. The old name survives
inside the files as ``/etc/init.d/mysql``, the ``mysql`` service alias and
the ``mysqloptimize`` cron job, all of which are the names Debian and
MariaDB use.

What it carries
---------------

======================  =====================================================
File                    Origin in the shared tree
======================  =====================================================
``plan``                ``plans/turnkey/mysql``, plus Debian's ``mysqltuner``
                        (1.0.1)
``overlay/``            ``overlays/mysql`` (5 files, byte identical)
``conf``                ``conf/mysql``, with an overridable init script
                        directory and without the mysqltuner download (1.0.1)
``version``             the pin ``bt-layer`` records in the layer manifest
======================  =====================================================

What it does not carry, and why:

- ``CONF_VARS += MYSQL_PASS``. fab lets a unit name the variables its conf
  script reads, in a ``conf-vars`` file. This conf script reads none.
  ``MYSQL_PASS`` was written in one line of ``mk/turnkey/mysql.mk`` and read
  nowhere else in the shared tree or in ``keel-mariadb``, where the password
  reaches the database at first boot from the instance description. A dead
  interface is not worth extracting.
- ``COMMON_REMOVELISTS += mysql``. ``removelists/mysql`` is 0 bytes. fab
  applies a unit's ``removelist`` after its conf script, so a component that
  needs one can carry one.

How a recipe consumes it
------------------------

The recipe stops including the shared tree's makefile fragment and stops
including its plan, and the component is materialised as a directory under
the product's ``unit.d/``::

    git clone --branch v1.0.0 https://github.com/keel-linux/unit-mariadb.git \
        $FAB_PATH/products/mariadb/unit.d/mariadb
    bt-layer mariadb --parent core

``bt-layer`` reads ``version``, records ``units mariadb@1.0.0`` in the layer
manifest, and a child layer built on that one subtracts the component
instead of applying it again. That subtraction is not a nicety: this
component's ``conf`` links ``/etc/init.d/mysql`` under ``bash -e`` and fails
with "File exists" the second time, which ``tests/conf.bats`` proves on
purpose.

Assembling ``unit.d`` from the pins a recipe declares is the step decision
0010 names as new code of the project, and it does not exist yet: today the
clone above is the assembly step, and the layer manifest is the record of
what was applied.

Order in the build
------------------

fab applies every unit overlay, then every unit conf script, then every unit
removelist, after the common overlays, conf scripts and patches and before
the common removelists, the product overlay and the product's own
``conf.d``. Two consequences this component lives with:

- The component overlay is applied after the recipe's own overlay reaches
  the tree through ``COMMON_OVERLAYS`` and before it is applied again as
  ``ROOT_OVERLAY``, so a recipe file still wins over a component file. No
  path of this overlay is a path of ``keel-mariadb``'s overlay, so nothing
  depends on it here.
- The conf script needs ``/usr/local/bin/service``, which
  ``removelists-final`` of the shared tree removes. Units run well before
  that, so the script has it. It no longer needs
  ``/usr/local/src/tkl-bashlib``, whose ``dl`` was its only use.

mysqltuner comes from Debian
----------------------------

``conf/mysql`` of the shared tree downloaded ``mysqltuner.pl``,
``basic_passwords.txt`` and ``vulnerabilities.csv`` from the ``master`` branch
of ``jmrenouard/MySQLTuner-perl`` into ``/usr/local/bin``: unpinned and
unchecked, so two builds of the same commit could ship different code, and
nothing would notice code that was not what upstream published. Debian trixie
packages it (``mysqltuner`` 2.6.0), so since 1.0.1 it is in the plan and apt
verifies it. The package installs ``/usr/bin/mysqltuner`` and keeps the two
data files in ``/usr/share/mysqltuner``, where the script looks for them.
``tests/conf.bats`` fails if the conf script fetches anything from the
network again.

Known upstream defects, kept as they are
----------------------------------------

The extraction changed nothing else the image gets, so two upstream defects
came across untouched. Both belong upstream (decision 0008) rather than in a
fork's overlay:

- ``etc/cron.daily/mysqloptimize`` is not executable, so ``run-parts`` has
  never run it on any appliance built from the shared tree.
- ``usr/local/bin/turnkey-mysql-install-perf-info-schemas`` ends with
  ``[[ -n "DEBUG" ]] || rm -rf /usr/loca/src/mariadb-sys*``, a condition that
  is always true over a literal string and a path that is misspelled, so the
  cleanup it intends has never happened either.

Tests
-----

``tests/coverage.sh`` runs the bats suite under kcov and fails below
``COVERAGE_THRESHOLD``. COVERAGE.md records what is measured, what is not
and why.
