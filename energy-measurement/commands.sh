#!/usr/bin/env bash

# Literal transcription of job unit-tests, cell "Linux x86-64 pylatest_conda_forge_mkl", of unit-tests.yml at 9bafc1c9.

set -eo pipefail
STAGE="${1:?stage required: build | test}"

LOCK_SHA256=83164622aff987a8a9a4625ccb216683e09ede0f9873ebd7dcf684c5c8d3cb82
LOCK_MISMATCH_EXIT=93
JUNIT_MISSING_EXIT=94

cd /src

# unit-tests.yml:18-23, the workflow environment, with /src as the workspace.
export VIRTUALENV=testvenv
export TEST_DIR=/src/tmp_folder
export CCACHE_DIR=/src/ccache
export COVERAGE=true
export JUNITXML=test-data.xml
# unit-tests.yml:128-137 through `env: ${{ matrix }}` (:222), with the push value of SKLEARN_SKIP_NETWORK_TESTS.
export name="Linux x86-64 pylatest_conda_forge_mkl"
export os=ubuntu-22.04
export DISTRIB=conda
export LOCK_FILE=build_tools/github/pylatest_conda_forge_mkl_linux-64_conda.lock
export SKLEARN_TESTS_GLOBAL_RANDOM_SEED=42
export SCIPY_ARRAY_API=1
export SKLEARN_SKIP_NETWORK_TESTS=1
# unit-tests.yml:230-235 and :279-280
export JOB_NAME="$name"
export COMMIT_MESSAGE="MNT Remove unused scripts from maint_tools (#34886)"
export SELECTED_TESTS=""

if [ "$(sha256sum "$LOCK_FILE" | cut -d' ' -f1)" != "$LOCK_SHA256" ]; then
  echo "$LOCK_FILE does not match the pre-registered sha256 $LOCK_SHA256" >&2
  exit "$LOCK_MISMATCH_EXIT"
fi

record_memory() {
  cp /sys/fs/cgroup/memory.peak /timing/memory_peak.txt 2>/dev/null || true
  cp /sys/fs/cgroup/memory.events /timing/memory_events.txt 2>/dev/null || true
}

trap record_memory EXIT

timed() {
  local label="$1" t0 t1 rc=0
  shift
  t0=$(date +%s.%N)
  "$@" || rc=$?
  t1=$(date +%s.%N)
  echo "$label,$rc,$(awk "BEGIN {printf \"%.3f\", $t1 - $t0}")" >> /timing/commands.csv
  return "$rc"
}

case "$STAGE" in

  build)
    # Step "Build scikit-learn" (:252-253): install.sh:62 and the Linux path of scikit_learn_install (:91-134).
    # install.sh is not called whole because its main() also creates the environment and downloads browsers.
    set -x
    source build_tools/shared.sh
    activate_environment
    CCACHE_LINKS_DIR="/tmp/ccache"
    CCACHE_BIN=`which ccache || echo ""`
    mkdir ${CCACHE_LINKS_DIR}
    for name in gcc g++ cc c++ clang clang++ i686-linux-gnu-gcc i686-linux-gnu-c++ x86_64-linux-gnu-gcc x86_64-linux-gnu-c++ \
                x86_64-apple-darwin13.4.0-clang x86_64-apple-darwin13.4.0-clang++ \
                arm64-apple-darwin20.0.0-clang arm64-apple-darwin20.0.0-clang++; do
    ln -s ${CCACHE_BIN} "${CCACHE_LINKS_DIR}/${name}"
    done
    export PATH="${CCACHE_LINKS_DIR}:${PATH}"
    ccache -M 512M
    ccache -z
    show_installed_libraries
    export LDFLAGS="$LDFLAGS -Wl,--sysroot=/"
    pip install --verbose --no-build-isolation --editable .
    ccache -s || echo "ccache not installed, skipping ccache statistics"
    ;;

  test)
    : > /timing/commands.csv
    rc_tests=0
    rc_docs=0
    # Step "Run tests" (:277-282)
    timed test_script bash -l build_tools/github/test_script.sh || rc_tests=$?
    cp -f "$TEST_DIR/$JUNITXML" /timing/junit.xml 2>/dev/null || true
    # Step "Run doctests in .py and .rst files" (:284-286)
    timed test_docs bash -l build_tools/github/test_docs.sh || rc_docs=$?
    # The job fails when either step fails; the stage exit is the larger of the two.
    rc=$(( rc_tests > rc_docs ? rc_tests : rc_docs ))
    if [ ! -f /timing/junit.xml ] && [ "$rc" -lt "$JUNIT_MISSING_EXIT" ]; then
      rc="$JUNIT_MISSING_EXIT"
    fi
    exit "$rc"
    ;;

  *)
    echo "unknown stage: $STAGE" >&2
    exit 2
    ;;

esac
