#!/bin/bash

# These aliases are for use with a personal developer CDE environment
# Add this file as a source in your ~/.bash_profile for use with the terminal
# To use these functions, set the required variables below

# These aliases & functions were created to be dynamic & able to be tailored to each developers preference.
# Developers may use any of the aliases & functions independently, but there are two cumulative functions for
# deploying a cde environment like a new customer & updating an existing cde environment to a new version.
# The steps to do these are below:
#
# Deploying a CDE env like a new customer:
# 1. (If LOCAL=false) Make sure all needed changes have been committed to the branch you want to deploy
# 2. Run deploy_cde_env passing in the environment (dev/test/stage/customer-hub/prod), branch, and region you want to deploy
#    Ex: deploy_cde_env customer-hub v1.15-release-branch us-west-2
# Note: From here if you would like to deploy another env without code changes, you can just delete this env (delete_cde_env)
#       & then run deploy_bootstrap passing in the new env (Ex: deploy_bootstrap dev)
# Note: If you are deploying PGO/PF provisioning, you will get errors trying to deploy with LOCAL=true due to CRD size.
#       Either apply the CRD server-side manually or have ArgoCD deploy it by using LOCAL=false
#
# Updating a running CDE env to a new version:
# 1. Ensure you have a CDE env running & if LOCAL=false, make sure all needed changes have been committed to the branch you want to update to
# 2. Run update_cde_env passing in the environment (dev/test/stage/customer-hub/prod) & the branch you want to update to
#    Ex: update_cde_env customer-hub v1.16-release-branch
# 3. When the script pauses for you to reconcile the env_vars & secrets, go to the CSR/PR make your changes,
#    commit them, & then go back to the terminal & press any key to continue
#
#
# Tearing down a running CDE env:
# 1. Run delete_cde_env passing in the environment (dev/test/stage/customer-hub/prod) you need to teardown
#    Ex: delete_cde_env dev

# Re-enable Argo Sync (this means you have a deployment running already in your cluster):
# 1. Run the alias 'enable_argo'
#    Ex: $ enable_argo

# Disable Argo Sync (this means you have a deployment running already in your cluster):
# 1. Run the alias 'disable_argo'
#    Ex: $ disable_argo

# The below variables are required for the aliases & functions to work

# The path to your Ping-Cloud-Base Repo. Ex: /Users/username/ping-cloud-base
# This repo also needs an additional remote setup called "mirror" that goes to your public dev PCB repo
# This repo also should be set as K8S_GIT_URL in your ENV_VARS file
PCB_PATH="${PCB_PATH}"
# The path to your Ping-Cloud-Tools Repo. Ex: /Users/username/ping-cloud-tools
PCT_PATH="${PCT_PATH}"
# The path to your Cluster State Repo. Ex: /Users/username/cluster-state-repo
CSR_PATH="${CSR_PATH}"
# The path to your Profile Repo. Ex: /Users/username/profile-repo
PR_PATH="${PR_PATH}"
# The path to the ssh key for your public developer PCB repo. Ex: ~/.ssh/github_rsa
PCB_SSH_KEY_PATH="${PCB_SSH_KEY_PATH}"
# The path to the ssh key for your CSR. If this is the same as PCB set it to $PCB_SSH_KEY_PATH
CSR_SSH_KEY_PATH="${CSR_SSH_KEY_PATH}"
# The path to the ssh key for your profile repo. If this is the same as PCB set it to $PCB_SSH_KEY_PATH
PR_SSH_KEY_PATH="${PR_SSH_KEY_PATH}"
# The path to your environment variables file for deployment. Ex: /Users/username/env_vars.sh
ENV_VARS="${ENV_VARS}"
# Set LOCAL to "true" if you want to use local copy of ping-cloud-base instead of having to reference a mirrored version
LOCAL="${LOCAL}"

SUPPORTED_ENVIRONMENT_TYPES="${SUPPORTED_ENVIRONMENT_TYPES}"

source "${PCB_PATH}/pingcloud-scripts.sh"

K8S_UTILS_VERSION=1.0.1
pingcloud-scripts::source_script k8s_utils ${K8S_UTILS_VERSION}

# Generates the CSR for all environments from the current local PCB git branch
# shellcheck disable=SC2120
generate_csr() {
  start=$(pwd)
  cd "${PCB_PATH}" || exit
  # shellcheck disable=SC1090
  source "${ENV_VARS}"
  SUPPORTED_ENVIRONMENT_TYPES=${SUPPORTED_ENVIRONMENT_TYPES:-${1}} IS_BELUGA_ENV=true code-gen/generate-cluster-state.sh
  cd "${start}" || exit
}

# Pushes the generated CSR for all environments in /tmp/sandbox to the remote CSR
# Requires generate script to have been ran
# shellcheck disable=SC2120
push_csr() {
  start=$(pwd)
  # shellcheck disable=SC2164
  cd "${CSR_PATH}" || exit
  SUPPORTED_ENVIRONMENT_TYPES=${SUPPORTED_ENVIRONMENT_TYPES:-${1}} GIT_SSH_COMMAND="ssh -i ${CSR_SSH_KEY_PATH}" IS_PRIMARY=true INCLUDE_PROFILES_IN_CSR=false /tmp/sandbox/push-cluster-state.sh
  cd "${start}" || exit
}

# Pushes the generated PR for all environments in /tmp/sandbox to the remote PR
# Requires generate script to have been ran
# shellcheck disable=SC2120
push_profile_repo() {
  start=$(pwd)
  cd "${PR_PATH}" || exit
  SUPPORTED_ENVIRONMENT_TYPES=${SUPPORTED_ENVIRONMENT_TYPES:-${1}} GIT_SSH_COMMAND="ssh -i ${PR_SSH_KEY_PATH}" IS_PRIMARY=true IS_PROFILE_REPO=true /tmp/sandbox/push-cluster-state.sh
  cd "${start}" || exit
}

# Prompt for a keypress to continue. Customise prompt with $*
function pause {
  >/dev/tty printf '%s' "${*:-Press any key to continue... }"
  [[ $ZSH_VERSION ]] && read -krs  # Use -u0 to read from STDIN
  [[ $BASH_VERSION ]] && </dev/tty read -rsn1
  printf '\n'
}

# Enable Argo Sync for P1AS deployments v1.17 and below
enable_argo_v1_17() {
  app="$(kubectl get application -n argocd | grep ping-cloud | awk "{ print \$1 }")"
  kubectl -n argocd patch --type='merge' application "${app}" -p "{\"spec\":{\"syncPolicy\": {\"automated\": {\"prune\": true}}}}"
  pod="$(kubectl get pod -n argocd | grep argo | awk "{ print \$1 }")"
  kubectl delete pod "${pod}" -n argocd > /dev/null
}

# Disable Argo Sync for P1AS deployments v1.17 and below
disable_argo_v1_17() {
  app="$(kubectl get application -n argocd | grep ping-cloud | awk "{ print \$1 }")"
  kubectl -n argocd patch --type='merge' application "${app}" -p "{\"spec\":{\"syncPolicy\":null}}"
}

# Enable Argo Sync for P1AS deployments v1.18 and above
# Also a handy method for restarting all ArgoCD pods at once
enable_argo() {
  app_sets="$(kubectl get applicationset -n argocd | grep ping-cloud-all-cdes | awk "{ print \$1 }")"
  echo "${app_sets}" | xargs  kubectl -n argocd patch --type='merge' applicationset  -p "{\"spec\":{\"template\":{\"spec\":{\"syncPolicy\": {\"automated\": {\"prune\": true}}}}}}"
  pods="$(kubectl get pod -n argocd | grep argo | awk "{ print \$1 }")"
  echo "${pods}" | xargs kubectl delete pod "${pod}" -n argocd > /dev/null
}

# Disable Argo Sync for P1AS deployments v1.18 and above
disable_argo() {
  app_sets="$(kubectl get applicationset -n argocd | grep ping-cloud-all-cdes | awk "{ print \$1 }")"
  echo "${app_sets}" | xargs kubectl -n argocd patch --type='merge' applicationset -p "{\"spec\":{\"template\":{\"spec\":{\"syncPolicy\":null}}}}"
}

# Pushes the PCB gitlab branch to the remote PCB mirror
push_pcb_mirror() {
  #Ex: push_pcb_mirror v1.16-release-branch
  if test -z "$1"; then
    echo "branch name required as parameter"
    return
  fi
  start=$(pwd)
  cd "${PCB_PATH}" || exit
  git checkout "$1"
  GIT_SSH_COMMAND="ssh -i ${PCB_SSH_KEY_PATH}" git push mirror
  cd "${start}" || exit
}

# Runs the git-ops command
git_ops() {
  # Ex: git_ops us-east-2
  if test -z "$1"; then
    echo "region required as parameter"
    return
  fi
  start=$(pwd)
  cd "${CSR_PATH}/k8s-configs/" || exit
  # Only apply from file if debug is set to true
  if [[ "${DEBUG}" == "true" ]]; then
    DEBUG=true LOCAL=${LOCAL} PCB_PATH=${PCB_PATH} ./git-ops-command.sh "$1"
    kubectl apply -f /tmp/uber-debug.yaml
  else
    DEBUG=false LOCAL=${LOCAL} PCB_PATH=${PCB_PATH} ./git-ops-command.sh "$1" | kubectl apply -f -
  fi
  cd "${start}" || exit
}

# Deploys minimal bootstrap required to avoid crash loop of the ping-cloud stack (argo, cert manager, etc.)
# Requires generate script to have been ran
# Note: This function will enable Argo sync
deploy_bootstrap() {
  #Ex: deploy_bootstrap dev
  if test -z "$1"; then
    echo "environment required as parameter"
    return
  fi
  start=$(pwd)
  cd /tmp/sandbox/fluxcd/"$1" || exit
  kustomize build | kubectl apply -f -
  cd "${start}" || exit
}

# Cumulative function to deploy a cde environment
deploy_cde_env() {
  if [ "$#" -ne "3" ]; then
      echo "Usage: 'deploy_cde_env dev v1.16-release-branch us-west-2'"
      return
  fi
  start=$(pwd)
  if [[ ${LOCAL} != "true" ]]; then
    push_pcb_mirror "$2"
  fi
  echo "Generating CSR"
  generate_csr "$1"
  echo "Pushing CSR"
  push_csr "$1"
  echo "Pushing profile repo"
  push_profile_repo "$1"
  echo "contents of fluxcd/dev/kustomzation.yaml"
  cat /tmp/sandbox/fluxcd/dev/kustomization.yaml
  echo "Deploy bootstrap"
  deploy_bootstrap "$1"
  git_ops
  if [[ ${LOCAL} == "true" ]]; then
    echo "Using local build, disabling ArgoCD"
    disable_argo
    echo "Using local build, running git-ops to deploy uber yaml"
    git_ops "$3"
    echo "Using local build, disabling ArgoCD resources created during git-ops command"
    disable_argo
  fi
  cd "${start}" || exit
}


# Deletes a CDE env from the cluster
delete_cde_env() {
  #Ex: delete_cde_env dev
  if test -z "$1"; then
    echo "environment required as parameter"
    return
  fi
  start=$(pwd)
  # Delete argo first so it doesn't try to resync the other namespaces
  if [ -d "/tmp/sandbox/fluxcd/$1" ]; then
    cd /tmp/sandbox/fluxcd/"$1" || exit
    kustomize build | kubectl delete -f - || true
  fi
  # Delete all other namespaces
  utils::cleanup_k8s_resources
  cd "${start}" || exit
}

# Runs the update wrapper script on the CSR
update_csr() {
  #Ex: update_csr dev v1.16-release-branch
  if test -z "$1" || test -z "$2"; then
    echo "environment & branch name required as parameters"
    return
  fi
  start=$(pwd)
  cd "${CSR_PATH}" || exit
  GIT_SSH_COMMAND="ssh -i ${CSR_SSH_KEY_PATH}" BASE64_DECODE_OPT=-d SUPPORTED_ENVIRONMENT_TYPES=${SUPPORTED_ENVIRONMENT_TYPES:-${1}} NEW_VERSION=$2 PING_CLOUD_BASE_REPO_URL=${K8S_GIT_URL} ./update-cluster-state-wrapper.sh
  cd "${start}" || exit
}

# Runs the update profile script on the PR
update_pr() {
  #Ex: update_pr dev v1.16-release-branch
  if test -z "$1" || test -z "$2"; then
    echo "environment & branch name required as parameters"
    return
  fi
  start=$(pwd)
  cd "${PR_PATH}" || exit
  GIT_SSH_COMMAND="ssh -i ${PR_SSH_KEY_PATH}" BASE64_DECODE_OPT=-d SUPPORTED_ENVIRONMENT_TYPES=${SUPPORTED_ENVIRONMENT_TYPES:-${1}} NEW_VERSION=$2 PING_CLOUD_BASE_REPO_URL=${K8S_GIT_URL} ./update-profile-wrapper.sh
  cd "${start}" || exit
}

# Renames & pushes the new branch in the CSR and PR
push_update() {
  #Ex: push_update dev v1.16-release-branch
  if test -z "$1" || test -z "$2"; then
    echo "environment & branch name required as parameters"
    return
  fi
  start=$(pwd)
  repos=("${CSR_PATH}" "${PR_PATH}")
  branch="$1"
  if [ "${branch}" = "prod" ]; then
    branch="master"
  fi
  for repo in "${repos[@]}"; do
    cd "${repo}" || exit
    git checkout ${branch}
    #Note: This prepends a random number to the old branch. So you may want to rename or clean this up after running
    git branch -m "$RANDOM-${branch}"
    git checkout "$2-${branch}"
    git branch -m "${branch}"
    GIT_SSH_COMMAND="ssh -i ${CSR_SSH_KEY_PATH}" git push --set-upstream origin ${branch}
  done
  cd "${start}" || exit
}

# Cumulative function to update a cde environment to a new version after committing code to the desired PCB git branch
update_cde_env() {
  #Ex: update_cde_env dev v1.16-release-branch
  if test -z "$1" || test -z "$2"; then
    echo "environment & branch name required as parameters"
    return
  fi
  start=$(pwd)
  # shellcheck disable=SC1090
  source "${ENV_VARS}"
  push_pcb_mirror "$2"
  update_csr "$1" "$2"
  update_pr "$1" "$2"
  echo ""
  echo "*******************************************************************************************"
  echo "Please go reconcile env_vars/secrets & commit the changes on the new branch in the CSR & PR"
  echo "*******************************************************************************************"
  echo ""
  pause 'Press any key when you are ready for the script to continue'
  push_update "$1" "$2"
  cd "${start}" || exit
}
