#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

get_expected_files() {
  kubectl logs -n "${PING_CLOUD_NAMESPACE}" \
    $(kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" | grep pingaccess-backup | cut -d/ -f2) |
  tail -1 |
  tr ' ' '\n' |
  sort
}

get_actual_files() {
  local bucket_url=$(get_ssm_val "${BACKUP_URL#ssm:/}")
  local bucket_url_no_protocol=${bucket_url#s3://}
  DAYS_AGO=1

  aws s3api list-objects \
    --bucket "${bucket_url_no_protocol}" \
    --prefix 'pingaccess/' \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

oneTimeSetUp(){
  # Save off backup file in case test does not complete and leaves it with 1 or more 'exit 1' statements inserted into it
  kubectl exec pingaccess-admin-0 -c pingaccess-admin -n ping-cloud -- sh -c 'cp /opt/staging/hooks/90-upload-backup-s3.sh /tmp/90-upload-backup-s3.sh'
}

oneTimeTearDown(){
  # Revert the original file back when tests are done execting
  kubectl exec pingaccess-admin-0 -c pingaccess-admin -n ping-cloud -- sh -c 'cp /tmp/90-upload-backup-s3.sh /opt/staging/hooks/90-upload-backup-s3.sh'
  # Delete lingering backup jobs and their associated pods
  log "Deleting backup job(teardown)"
  kubectl delete -f "${UPLOAD_JOB}" -n "${PING_CLOUD_NAMESPACE}"
}

testPingAccessBackup() {
  UPLOAD_JOB="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingaccess/admin/aws/backup.yaml

  log "Deleting backup job"
  kubectl delete -f "${UPLOAD_JOB}" -n "${PING_CLOUD_NAMESPACE}"

  log "Applying backup job"
  kubectl apply -f "${UPLOAD_JOB}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl apply command to create the PingAccess upload job should have succeeded" 0 $?

  log "Waiting for backup job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/pingaccess-backup -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl wait command for the backup job should have succeeded" 0 $?

  sleep 10

  log "Expected backup files:"
  expected_results=$(get_expected_files)
  echo "${expected_results}"

  log "Actual backup files:"
  actual_results=$(get_actual_files)
  echo "${actual_results}"

  assertContains "The expected_files were not contained within the actual_files" "${actual_results}" "${expected_results}"
}

testPingAccessBackupCapturesFailure() {
  UPLOAD_JOB="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingaccess/admin/aws/backup.yaml

  log "Deleting backup job(setup)"
  kubectl delete -f "${UPLOAD_JOB}" -n "${PING_CLOUD_NAMESPACE}"

  log "Disabling upload backup hook script"
  kubectl exec pingaccess-admin-0 -c pingaccess-admin -n ping-cloud -- sh -c "sed -i '1i exit 1' /opt/staging/hooks/90-upload-backup-s3.sh"

  log "Applying backup job"
  kubectl apply -f "${UPLOAD_JOB}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl apply command to create the PingAccess upload job should have succeeded" 0 $?

  log "Waiting for backup job to fail"
  sleep 10
  verify_resource "job" "${PING_CLOUD_NAMESPACE}" "pingaccess-backup"
  assertEquals "Backup job should not have succeded" 1 $? 

  log "Re-enabling backup hook script"
  kubectl exec pingaccess-admin-0 -c pingaccess-admin -n "${PING_CLOUD_NAMESPACE}" -- sh -c "sed -i '1d' /opt/staging/hooks/90-upload-backup-s3.sh"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}