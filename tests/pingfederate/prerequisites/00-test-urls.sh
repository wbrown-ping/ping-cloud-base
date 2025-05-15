#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# Switching to Private Ingress to test URLs given PingFederate Basic Auth is being blocked by PingAccess-WAS
PINGFEDERATE_PRIVATE="https://pingfederate-admin-api.${DNS_ZONE}"
PINGFEDERATE_CONSOLE="${PINGFEDERATE_PRIVATE}/pingfederate/app"
PINGFEDERATE_API_DOCS="${PINGFEDERATE_PRIVATE}/pf-admin-api/api-docs/"
PINGFEDERATE_API="${PINGFEDERATE_PRIVATE}/pf-admin-api/v1/version"

testUrls() {

  exit_code=0
  for i in {1..10}
  do
    testUrlsExpect2xx "${PINGFEDERATE_CONSOLE}" "${PINGFEDERATE_API_DOCS}" "${PINGFEDERATE_API}"
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
      log "The PingFederate endpoints are inaccessible.  This is attempt ${i} of 10.  Wait 60 seconds and then try again..."
      sleep 60
    else
      break
    fi
  done

  assertEquals 0 $exit_code
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}