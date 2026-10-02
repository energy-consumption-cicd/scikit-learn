#!/usr/bin/env bash

# Literal transcription of job Linux_Runs, matrix entry pylatest_conda_forge_mkl, of azure-pipelines.yml at 646da0f0 (tag 1.8.0),
# with the steps of build_tools/azure/posix.yml.

set -eo pipefail
STAGE="${1:?stage required: build | test}"

LOCK_SHA256=cb46a250215de687e672410e76de046ac362cd9275bb26c7800315229c78ad50
LOCK_MISMATCH_EXIT=93
JUNIT_MISSING_EXIT=94

cd /src

# build_tools/azure/posix.yml:15-24, the job variables, with /src as the work folder.
export TEST_DIR=/src/tmp_folder
export VIRTUALENV=testvenv
export JUNITXML=test-data.xml
export SKLEARN_SKIP_NETWORK_TESTS=1
export CCACHE_DIR=/src/ccache
export CCACHE_COMPRESS=1
export PYTEST_XDIST_VERSION=latest
export COVERAGE=true
export CREATE_ISSUE_ON_TRACKER=true
# azure-pipelines.yml:105-114, the matrix entry; SKLEARN_SKIP_NETWORK_TESTS keeps the job value outside schedules.
export DISTRIB=conda
export LOCK_FILE=./build_tools/azure/pylatest_conda_forge_mkl_linux-64_conda.lock
export SKLEARN_TESTS_GLOBAL_RANDOM_SEED=42
export SCIPY_ARRAY_API=1
# Predefined Azure variables the scripts read, with the values of a push build of the tag commit.
export BUILD_REASON=IndividualCI
export BUILD_SOURCESDIRECTORY=/src
export BUILD_SOURCEVERSIONMESSAGE="[cd build]"

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
    # Step "Install" (posix.yml:50-52): install.sh:62 and the Linux path of scikit_learn_install (:87-130).
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
    # Step "Test Library" (posix.yml:53-55)
    timed test_script build_tools/azure/test_script.sh || rc_tests=$?
    cp -f "$TEST_DIR/$JUNITXML" /timing/junit.xml 2>/dev/null || true
    # Step "Test Docs" (posix.yml:56-59); run whatever the first step returned, as in the HEAD campaign.
    timed test_docs build_tools/azure/test_docs.sh || rc_docs=$?
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
