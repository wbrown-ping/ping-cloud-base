#!/bin/bash
##################################################################
# Common variables
##################################################################

test "${VERBOSE}" && set -x

export PROJECT_DIR="${PROJECT_DIR:-${CI_PROJECT_DIR}}"
CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"

# Override environment variables with optional file supplied from the outside
ENV_VARS_FILE="${1}"

# Integration tests to skip.  Unit tests cannot be skipped.
SKIP_TESTS="${SKIP_TESTS:-pingdelegator/01-admin-user-login.sh \
  pingaccess/08-artifact-test.sh}"

########################################################################################################################
# Echoes a message prepended with the current time
#
# Arguments
#   ${1} -> The message to echo
########################################################################################################################
log() {
  LOG_FILE=${LOG_FILE:-/tmp/dev-env.log}
  echo "$(date) ${1}" | tee -a "${LOG_FILE}"
}

# all environment variables
set_env_vars() {
  export BELUGA_ENV_NAME="${CLUSTER_NAME}-${CI_COMMIT_REF_SLUG}"
  export CLUSTER_NAME="${SELECTED_KUBE_NAME:-ci-cd}"
  export DASH_REPO_URL="${DASH_REPO_URL:-https://github.com/pingidentity/ping-cloud-dashboards}"
  export DASH_REPO_BRANCH="${DASH_REPO_BRANCH:-main}"
  export ENV=${BELUGA_ENV_NAME}
  export KUBE_NAME_UNDERSCORES=$(echo ${SELECTED_KUBE_NAME} | tr '-' '_')
  export LOG_LINES_TO_TEST=2
  export PGO_BACKUP_BUCKET_NAME=${CLUSTER_NAME}-backup-bucket
  export REGION_NICK_NAME=${REGION}

  if [[ ${CI_COMMIT_REF_SLUG} != master ]]; then
    export ENVIRONMENT=-${CI_COMMIT_REF_SLUG}
  fi

  if test -z "${ENV_VARS_FILE}"; then
    log "Using environment variables set in properties file"
    . "${CI_SCRIPTS_DIR}/k8s/deploy/ci-cd-cluster.properties"

  elif test -f "${ENV_VARS_FILE}"; then
    log "Using environment variables defined in file ${ENV_VARS_FILE}"
    set -a; source "${ENV_VARS_FILE}"; set +a
  else
    log "ENV_VARS_FILE points to a non-existent file: ${ENV_VARS_FILE}"
    exit 1
  fi

  NEW_RELIC_LICENSE_KEY="${NEW_RELIC_LICENSE_KEY:-ssm://pcpt/sre/new-relic/java-agent-license-key}"
  if [[ ${NEW_RELIC_LICENSE_KEY} == "ssm://"* ]]; then
    if ! ssm_value=$(get_ssm_val "${NEW_RELIC_LICENSE_KEY#ssm:/}"); then
      log "Warn: ${ssm_value}"
      log "Setting NEW_RELIC_LICENSE_KEY to unused"
      NEW_RELIC_LICENSE_KEY="unused"
    else
      NEW_RELIC_LICENSE_KEY="${ssm_value}"
    fi
  fi

  export GLOBAL_TENANT_DOMAIN="${GLOBAL_TENANT_DOMAIN:-$(echo "${TENANT_DOMAIN}"|sed -e "s/[^.]*.\(.*\)/global.\1/")}"
  export PF_PROVISIONING_ENABLED=${PF_PROVISIONING_ENABLED:-true}
  export NEW_RELIC_ENVIRONMENT_NAME=${TENANT_NAME}_${ENV}_${REGION}_k8s-cluster
  export NEW_RELIC_LICENSE_KEY_BASE64=$(base64_no_newlines "${NEW_RELIC_LICENSE_KEY}")
  export DATASYNC_P1AS_SYNC_SERVER="pingdirectory-0"

  # Timing
  export LOG_SYNC_SECONDS="${LOG_SYNC_SECONDS:-5}"
  export UPLOAD_TIMEOUT_SECONDS="${UPLOAD_TIMEOUT_SECONDS:-20}"
  export CURL_TIMEOUT_SECONDS="${CURL_TIMEOUT_SECONDS:-450}"

  export ADMIN_USER=administrator
  export ADMIN_PASS=2FederateM0re

  export PD_SEED_LDAPS_PORT=636

  export CLUSTER_NAME_LC=$(echo "${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')
  export LOG_GROUP_NAME="/aws/containerinsights/${CLUSTER_NAME}/application"

  FQDN=${ENVIRONMENT}.${TENANT_DOMAIN}

  # Monitoring
  LOGS_CONSOLE=https://logs${FQDN}
  PROMETHEUS=https://prometheus${FQDN}
  GRAFANA=https://monitoring${FQDN}

  # Pingdirectory
  PINGDIRECTORY_API=https://pingdirectory${FQDN}
  PINGDIRECTORY_ADMIN=pingdirectory-admin${FQDN}

  # Pingfederate
  # admin services:
  PINGFEDERATE_CONSOLE=https://pingfederate-admin${FQDN}/pingfederate/app
  PINGFEDERATE_API=https://pingfederate-admin-api${FQDN}/pf-admin-api/v1/version

  # The trailing / is required to avoid a 302
  PINGFEDERATE_API_DOCS=https://pingfederate-admin${FQDN}/pf-admin-api/api-docs/
  PINGFEDERATE_ADMIN_API=https://pingfederate-admin-api${FQDN}/pf-admin-api/v1

  # runtime services:
  PINGFEDERATE_AUTH_ENDPOINT=https://pingfederate${FQDN}
  PINGFEDERATE_OAUTH_PLAYGROUND=https://pingfederate${FQDN}/OAuthPlayground

  # Pingaccess
  # admin services:
  PINGACCESS_CONSOLE=https://pingaccess-admin${FQDN}
  PINGACCESS_SWAGGER=https://pingaccess-admin${FQDN}/pa-admin-api/api-docs
  PINGACCESS_API=https://pingaccess-admin${FQDN}/pa-admin-api/v3

  # runtime services:
  PINGACCESS_RUNTIME=https://pingaccess${FQDN}
  PINGACCESS_AGENT=https://pingaccess-agent${FQDN}

  # PingAccess WAS
  # admin services:
  # The trailing / is required to avoid a 302
  PINGACCESS_WAS_SWAGGER=https://pingaccess-was-admin${FQDN}/pa-admin-api/v3/api-docs/
  PINGACCESS_WAS_CONSOLE=https://pingaccess-was-admin${FQDN}
  PINGACCESS_WAS_API=https://pingaccess-was-admin${FQDN}/pa-admin-api/v3

  # runtime services:
  PINGACCESS_WAS_RUNTIME=https://pingaccess-was${FQDN}

  # Ping Delegated Admin
  PINGDELEGATOR_CONSOLE=https://pingdelegator${FQDN}/delegator

  # PingCentral
  MYSQL_SERVICE_HOST="beluga-${SELECTED_KUBE_NAME:-ci-cd}-mysql.cmpxy5bpieb9.us-west-2.rds.amazonaws.com"
  MYSQL_SERVICE_PORT=3306
  MYSQL_USER_SSM=/aws/reference/secretsmanager//pcpt/ping-central/dbserver#username
  MYSQL_PASSWORD_SSM=/aws/reference/secretsmanager//pcpt/ping-central/dbserver#password

  # Pingcloud-metadata service:
  PINGCLOUD_METADATA_API=https://metadata${FQDN}

  # Pingcloud-healthcheck service:
  PINGCLOUD_HEALTHCHECK_API=https://healthcheck${FQDN}

  # PingCentral service
  PINGCENTRAL_CONSOLE=https://pingcentral${FQDN}

  # MySQL database names cannot have dashes. So transform dashes into underscores.
  ENV_NAME_NO_DASHES=$(echo ${CI_COMMIT_REF_SLUG} | tr '-' '_')

  # If PCB deploy, don't append branch name to ping-cloud namespace
  if [[ ${PROJECT_DIR} == *"ping-cloud-base"* ]]; then
    export PING_CLOUD_NAMESPACE="ping-cloud"
  else
    export PING_CLOUD_NAMESPACE="ping-cloud-$CI_COMMIT_REF_SLUG"
  fi

  # PingOne deploy env vars
  log "Setting env vars for PingOne deployment"
  # CUSTOMER_SSO_SSM_PATH_PREFIX can be removed once added to CreateCluster script
  export CUSTOMER_SSO_SSM_PATH_PREFIX="/${SELECTED_KUBE_NAME}/pcpt/customer/sso"
}

########################################################################################################################
# Sets env vars specific to PingOne API integration
########################################################################################################################
set_pingone_api_env_vars() {
  P1_BASE_ENV_VARS=$(get_ssm_val "/pcpt/pingone/env-vars")
  eval $P1_BASE_ENV_VARS
}

pip_install_shared_pingone_scripts() {
  pip install git+https://gitlab.corp.pingidentity.com/ping-cloud-private-tenant/ping-cloud-tools.git@master#subdirectory=pingone
}

########################################################################################################################
# Configures kubectl to be able to talk to the Kubernetes API server based on the following environment variables:
#
#   - SELECTED_KUBE_NAME
#   - AWS_ACCOUNT_ROLE_ARN
#
# If the environment variables are not present, then the function will exit with a non-zero return code.
########################################################################################################################
configure_kube() {
  if test -n "${SKIP_CONFIGURE_KUBE}" || test -z "${CI_SERVER}"; then
    log "Skipping KUBE configuration"
    return
  fi

  check_env_vars "SELECTED_KUBE_NAME" "AWS_ACCOUNT_ROLE_ARN"
  HAS_REQUIRED_VARS=${?}

  if test ${HAS_REQUIRED_VARS} -ne 0; then
    exit 1
  fi

  log "Configuring KUBE"

  # Use AWS profile 'default' because this is the profile the AWS Access Key/Secret key go under in the 'configure_aws'
  # function. This profile then assumes the role specified by $AWS_ACCOUNT_ROLE_ARN, within the kube config.
  aws eks update-kubeconfig \
    --profile "default" \
    --role-arn "${AWS_ACCOUNT_ROLE_ARN}" \
    --alias "${SELECTED_KUBE_NAME}" \
    --name "${SELECTED_KUBE_NAME}" \
    --region us-west-2

  kubectl config use-context "${SELECTED_KUBE_NAME}"
}

########################################################################################################################
# Configures the aws CLI to be able to talk to the AWS API server based on the following environment variables:
#
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - AWS_DEFAULT_REGION
#   - AWS_ACCOUNT_ROLE_ARN
#
# If the environment variables are not present, then the function will exit with a non-zero return code. The AWS config
# and credentials file will be set up with a profile of ${AWS_PROFILE} environment variable defined in the common.sh
# file.
########################################################################################################################
configure_aws() {
  if test -n "${SKIP_CONFIGURE_AWS}" || test -z "${CI_SERVER}"; then
    log "Skipping AWS CLI configuration"
    return
  fi

  check_env_vars "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_DEFAULT_REGION" "AWS_ACCOUNT_ROLE_ARN" "AWS_PROFILE"
  HAS_REQUIRED_VARS=${?}

  if test ${HAS_REQUIRED_VARS} -ne 0; then
    exit 1
  fi

  log "Configuring AWS CLI"
  mkdir -p ~/.aws

  cat > ~/.aws/config <<EOF
  [default]
  output = json

  [profile ${AWS_PROFILE}]
  output = json
  region = ${AWS_DEFAULT_REGION}
  source_profile = default
  role_arn = ${AWS_ACCOUNT_ROLE_ARN}
EOF

  cat > ~/.aws/credentials <<EOF
  [default]
  aws_access_key_id = ${AWS_ACCESS_KEY_ID}
  aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}

  [${AWS_PROFILE}]
  role_arn = ${AWS_ACCOUNT_ROLE_ARN}
EOF
}

########################################################################################################################
# Retrieve the value associated with the provided parameter from AWS parameter store or AWS Secrets Manager.
#
# Arguments
#   ${1} -> The SSM parameter name.
#
# Returns
#   The value of the parameter name if found, or the error message stating why the command failed.
########################################################################################################################
get_ssm_val() {
  param_name="$1"
  if ! ssm_val="$(aws ssm get-parameters \
            --profile "${AWS_PROFILE}" \
            --region "${REGION}" \
            --names "${param_name%#*}" \
            --query 'Parameters[*].Value' \
            --with-decryption \
            --output text)"; then
    echo "$ssm_val"
    return 1
  fi

  if [[ "$param_name" == *"secretsmanager"* ]]; then
    # grep for the value of the secrets manager object's key
    # the object's key is the string following the '#' in the param_name variable
    echo "$ssm_val" | grep -Eo "${param_name#*#}[^,]*" | grep -Eo "[^:]*$" | tr -d '"'
  else
    echo "$ssm_val"
  fi
}

########################################################################################################################
# Determine whether to skip the tests in the file with the provided name. If the SKIP_TESTS environment variable is set
# and contains the name of the file with its parent directory, then that test file will be skipped. For example, to
# skip the PingDirectory tests in files 03-backup-restore.sh and 20-pd-recovery-on-delete-pv.sh, set SKIP_TESTS to
# 'pingdirectory/03-backup-restore.sh chaos/20-pd-recovery-on-delete-pv.sh'.
#
# Arguments
#   ${1} -> The fully-qualified name of the test file.
#
# Returns
#   0 -> if the test should be skipped; 1 -> if the test should not be skipped.
########################################################################################################################
skipTest() {
  test -z "${SKIP_TESTS}" && return 1

  local test_file="${1}"

  readonly dir_name=$(basename "$(dirname "${test_file}")")
  readonly file_name=$(basename "${test_file}")
  readonly test_file_short_name="${dir_name}/${file_name}"

  echo "${SKIP_TESTS}" | grep -q "${test_file_short_name}" &> /dev/null

  if test $? -eq 0; then
    log "SKIP_TESTS is set to skip test file: ${test_file_short_name}"
    return 0
  fi

  return 1
}

########################################################################################################################
# Check if the k8 resources are ready to run tests.
# BLOCKS until they are ready or timeout is reached
#
# Arguments:
# $1 - the namespace to check
# $2 - map of the k8s resources to check (ex: "statefulset.apps/pingfederate statefulset.apps/pingaccess"
# $3 - the timeout to use
########################################################################################################################
check_if_ready() {
  local ns_to_check="${1}"
  local k8s_resources_to_check="${2}"
  test -n "${3}" && timeout="${3}" || timeout="60"

  for resource in ${k8s_resources_to_check}; do
    echo "Waiting for rollout of ${resource} with a timeout of ${timeout} seconds"
    wait_for_rollout "${resource}" "${ns_to_check}" "${timeout}"
  done

  # Print out the ingress objects for logs and the ping stack
  printf '\n--- Ingress URLs ---\n'
  kubectl get ingress -A

  # Print out the pods for the ping stack
  printf '\n\n--- Pod status ---'
  kubectl get pods -n "${ns_to_check}"
}

########################################################################################################################
# Clean up DNS records in route53
#
# NOTE: the below logic for removing dns-records has to removed in future when we update the external-dns version
# https://github.com/kubernetes-sigs/external-dns/issues/3219 #should follow this bug for more updates
#
# Arguments
#   $1 -> TENANT_DOMAIN
########################################################################################################################
delete_dns_records(){
  #get the list of DNS records for the cluster(TENANT_DOMAIN) and delete them
  #since we should have the access to TENANT_DOMAIN use that to figure out DNS records
  log "Cleaning up the External DNS domain records"
  local hosted_zone_name="${1}"
  #get the hosted_zone_id using the aws cli
  local hosted_zone_id=$(aws --profile "${AWS_PROFILE}" route53 list-hosted-zones-by-name \
                      --dns-name "${hosted_zone_name}" 2>/dev/null | \
                      jq -r ".HostedZones[] | select(.Name == \"${hosted_zone_name}.\") | .Id" | \
                      cut -d'/' -f3)
  #add a if condition to check hosted_zone_id and then delete the record sets
  #if the hosted zone id is not returned or empty then error out and exit the script.
  if test -n "${hosted_zone_id}"; then
    #since now we have hosted_zone_id, get the records sets excluding NS and SOA using the hosted_zone_id
    #redirect the error messages to /dev/null when the command get executed.
    record_sets=$(aws --profile "${AWS_PROFILE}" route53 list-resource-record-sets \
                    --hosted-zone-id "${hosted_zone_id}" \
                    --query "ResourceRecordSets[?Type != 'NS' && Type != 'SOA']" 2>/dev/null | jq -c ".[]")
    #now we have the record_sets, loop over and delete one by one if record_sets is non-empty
      if test -n "${record_sets}"; then
        record_sets_size=$(echo "${record_sets}" | jq -s "length")
        log "Found ^^ $record_sets_size ^^ records inside ${hosted_zone_name}"
        for record_set in ${record_sets}; do
            aws --profile "${AWS_PROFILE}" route53 change-resource-record-sets --hosted-zone-id "${hosted_zone_id}" \
                --change-batch "{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":${record_set}}]}" > /dev/null 2>&1
        done
        log "DNS records clean up complete for ${hosted_zone_name}"
      else
        log "No DNS records found in ${hosted_zone_name} except the default records"
      fi
  else
    log "no hosted_zone_id returned for ${hosted_zone_name}. Exiting the script now"
    exit 1
  fi
}

########################################################################################################################
# Gets rollout status and waits to return until either the timeout is reached or the rollout is ready
#
# Arguments
#   $1 -> resource to check rollout status
#   $2 -> namespace for resource
#   $3 -> timeout for check
########################################################################################################################
wait_for_rollout() {
  local resource="${1}"
  local namespace="${2}"
  local timeout="${3}"
  time kubectl rollout status "${resource}" --timeout "${timeout}s" -n "${namespace}" -w
}

########################################################################################################################
# base64-encode the provided string or file contents and remove any new lines (both line feeds and carriage returns).
#
# Arguments
#   ${1} -> The string to base-64 encode, or a file whose contents to base64-encode.
########################################################################################################################
# TODO: This is duplicate of method in PCB utils.sh try to address with PDO-5229
base64_no_newlines() {
  if test -f "${1}"; then
    cat "${1}" | base64 | tr -d '\r?\n'
  else
    echo -n "${1}" | base64 | tr -d '\r?\n'
  fi
}

########################################################################################################################
# Verify that the provided environment variables are set.
#
# Arguments
#   ${*} -> The list of required environment variables.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
check_env_vars() {
  STATUS=0
  for NAME in ${*}; do
    VALUE="${!NAME}"
    if test -z "${VALUE}"; then
      echo "${NAME} environment variable must be set"
      STATUS=1
    fi
  done
  return ${STATUS}
}

########################################################################################################################
# Build all kustomizations under the provided directory and its sub-directories.
#
# Arguments
#   ${1} -> The fully-qualified base directory.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_kustomizations_in_dir() {
  DIR=${1}

  log "Building all kustomizations in directory ${DIR}"

  STATUS=0
  KUSTOMIZATION_FILES=$(find "${DIR}" -name kustomization.yaml)

  for KUSTOMIZATION_FILE in ${KUSTOMIZATION_FILES}; do
    KUSTOMIZATION_DIR=$(dirname ${KUSTOMIZATION_FILE})

    if grep "kind: Component" ${KUSTOMIZATION_FILE}
    then
      log "${KUSTOMIZATION_DIR} is a Component. Skipping"
      continue
    fi

    log "Processing kustomization.yaml in ${KUSTOMIZATION_DIR}"
    kustomize build "${build_load_arg}" "${build_load_arg_value}" "${KUSTOMIZATION_DIR}" 1> /dev/null
    BUILD_RESULT=${?}
    log "Build result for directory ${KUSTOMIZATION_DIR}: ${BUILD_RESULT}"

    test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}
  done

  log "Build result for base directory ${DIR}: ${STATUS}"

  return ${STATUS}
}

########################################################################################################################
# Builds all kustomizations in the generated code directory. Intended to only be used for building manifests generated by
# the generate-cluster-state.sh script.
#
# Arguments
#   ${1} -> The fully-qualified directory that contains the generated code.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_generated_code() {
  DIR="$1"

  build_cluster_state_code "${DIR}"
  CLUSTER_STATE_BUILD_STATUS=$?

  build_bootstrap_code "${DIR}"
  BOOTSTRAP_BUILD_STATUS=$?

  if test ${CLUSTER_STATE_BUILD_STATUS} -eq 0 && test ${BOOTSTRAP_BUILD_STATUS} -eq 0; then
    return 0
  else
    return 1
  fi
}

########################################################################################################################
# Builds all kustomizations within the cluster-state directory of the generated code directory. Intended to only be
# used for building manifests generated by the generate-cluster-state.sh script.
#
# Arguments
#   ${1} -> The fully-qualified directory that contains the generated code.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_cluster_state_code() {
  DIR="$1"

  STATUS=0
  log "Building cluster state code in directory ${DIR}"

  BASE_DIRS=$(find "${DIR}/cluster-state/k8s-configs" -name base -type d -maxdepth 2)

  GIT_OPS_CMD_NAME='git-ops-command.sh'
  GIT_OPS_CMD="$(find "${DIR}" -name "${GIT_OPS_CMD_NAME}" -type f)"

  for BASE_DIR in ${BASE_DIRS}; do
    DIR_NAME="$(dirname "${BASE_DIR}")"
    CDE="$(basename "${DIR_NAME}")"
    REGION="$(ls "${DIR_NAME}" | grep -v 'base')"

    log "Processing manifests for region '${REGION}' and CDE '${CDE}'"
    cd "${BASE_DIR}"/..

    cp "${GIT_OPS_CMD}" .
    ./"${GIT_OPS_CMD_NAME}" "${REGION}" > /dev/null
    BUILD_RESULT=$?
    log "Build result for manifests for region '${REGION}' and CDE '${CDE}': ${BUILD_RESULT}"

    rm -f "${GIT_OPS_CMD_NAME}"
    cd - &>/dev/null

    test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}
  done

  log "Build result for cluster state code in directory ${DIR}: ${STATUS}"
  return ${STATUS}
}

########################################################################################################################
# Builds all kustomizations within the fluxcd directory of the generated code directory. Intended to only be
# used for building manifests generated by the generate-cluster-state.sh script.
#
# Arguments
#   ${1} -> The fully-qualified directory that contains the generated code.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_bootstrap_code() {
  DIR="$1"

  STATUS=0
  log "Building bootstrap code in directory ${DIR}"

  BOOTSTRAP_DIR="${DIR}"/fluxcd
  CDE_DIRS="$(ls "${BOOTSTRAP_DIR}")"

  for CDE in ${CDE_DIRS}; do
    log "Building bootstrap code for CDE '${CDE}'"
    build_kustomizations_in_dir "${BOOTSTRAP_DIR}/${CDE}"
    BUILD_RESULT=$?
    log "Build result for bootstrap code for CDE '${CDE}': ${BUILD_RESULT}"

    test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}
  done

  log "Build result for bootstrap code in directory ${DIR}: ${STATUS}"
  return ${STATUS}
}

set_env_vars
configure_aws
configure_kube
set_pingone_api_env_vars