#!/bin/bash
set -e

test "${VERBOSE}" && set -x

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh
. ${SCRIPT_HOME}/../../pingcloud-scripts.sh
. ${SCRIPT_HOME}/../../build/ecr-common.sh
CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"

BASH_UTILS_VERSION=1.0.0
pingcloud-scripts::source_script bash_utils ${BASH_UTILS_VERSION}

pushd "${PROJECT_DIR}"

if [[ ${PROJECT_DIR} == *"ping-cloud-base"* ]]; then
  export DASH_REPO_BRANCH=$(grep "DASH_REPO_BRANCH" ${PROJECT_DIR}/code-gen/templates/common/base/env_vars | cut -d "=" -f 2)
  # PCB deployment to Kubernetes
  . ${PROJECT_DIR}/utils.sh

  pip_install_shared_pingone_scripts
  log "Deleting P1 resources created by deployment if they already exist"
  p1_deployment_cleanup
  log "Deleting P1 Environment if it already exists"
  cicd_p1_env_setup_and_teardown Teardown 2>/dev/null || true
  log "Creating P1 Environment"
  cicd_p1_env_setup_and_teardown Setup

  #clean up the previous deployment dns records before deploying
  # delete_dns_records "${TENANT_DOMAIN}"

  source "${CI_SCRIPTS_DIR}/k8s/deploy/dev_cde_aliases_cicd_config.sh"
  log "sourcing config"
  source "${CI_SCRIPTS_DIR}/k8s/deploy/dev_cde_aliases.sh"
  export LOCAL="true"

  echo "cloning CSR & PR into ${CSR_PATH} and ${PR_PATH}"
  mkdir -p "${CSR_PATH}"
  mkdir -p "${PR_PATH}"

GIT_SSH_COMMAND="ssh -i ${CSR_SSH_KEY_PATH}" git clone ssh://APKA2IO25QZRRRNUAQPP@git-codecommit.us-west-2.amazonaws.com/v1/repos/gitlab-cicd-cluster-state-repo "${CSR_PATH}/"
GIT_SSH_COMMAND="ssh -i ${PR_SSH_KEY_PATH}" git clone ssh://APKA2IO25QZRRRNUAQPP@git-codecommit.us-west-2.amazonaws.com/v1/repos/gitlab-cicd-profile-repo "${PR_PATH}/"
  # Apply Custom Resource Definitions separate, due to size, if applicable
  utils::apply_crds "${PROJECT_DIR}"

  # note because LOCAL=true, the branch here doesn't really matter
  deploy_cde_env dev "v1.19-release-branch" "us-west-2"

  # A PingDirectory pod can take up to 15 minutes to deploy in the CI/CD cluster. There are three sets of dependencies
  # today from:
  #
  #     1. PA engine -> PA admin -> PF admin -> PD
  #     2. PF engine -> PF admin -> PD
  #     3. PA WAS engine -> PA WAS admin
  #
  # So checking the rollout status of the end dependencies should be enough after PD is rolled out. We'll give each 2.5
  # minutes after PD is ready. This should be more than enough time because as soon as pingdirectory-0 is ready, the
  # rollout of the others will begin, and they don't take nearly as much time as a single PD server. So the entire Ping
  # stack must be rolled out in no more than (15 * num of PD replicas (2) + 2.5 * number of end dependents) minutes.

  # Wait for PD to become ready
  check_if_ready "${PING_CLOUD_NAMESPACE}" "statefulset.apps/pingdirectory" "1800"

  # Print out the pingdirectory hostname
  printf '\n--- LDAP hostname ---\n'
  kubectl get svc pingdirectory-admin -n "${PING_CLOUD_NAMESPACE}" \
    -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}'

  # Wait for PF & PA
  K8S_RESOURCES_TO_CHECK="statefulset.apps/pingfederate statefulset.apps/pingaccess statefulset.apps/pingaccess-was"
  CHECK_IF_READY_TIMEOUT="300"
else
  # Microservice app deployment to Kubernetes

  configure_environment
  set_chart_version "${CI_PROJECT_DIR}/deploy/${CI_PROJECT_NAME}"

  log "Installing ${CI_PROJECT_NAME} helm chart"
  helm upgrade -install -n "${PING_CLOUD_NAMESPACE}" --create-namespace "${CI_PROJECT_NAME}" oci://${ECR_REGISTRY}/${CI_PROJECT_NAME} --version ${CHART_VERSION}
fi

if test -n "${K8S_RESOURCES_TO_CHECK}"; then
  check_if_ready "${PING_CLOUD_NAMESPACE}" "${K8S_RESOURCES_TO_CHECK}" "${CHECK_IF_READY_TIMEOUT}"
fi

popd > /dev/null 2>&1
