#!/bin/bash

# ping-cloud-base repo location
export PCB_PATH="${PROJECT_DIR}"

# NOTE: these variables must exactly match those set by your CLUSTER_NAME-cluster.properties file
export CSR_PATH="${HOME}/gitlab-cicd-cluster-state-repo"
export PR_PATH="${HOME}/gitlab-cicd-profile-repo"
# export PCB_SSH_KEY_PATH="${HOME}/.ssh/YOUR_GITHUB_SSH_KEY"
export CSR_SSH_KEY_PATH="${HOME}/.ssh/gitlab-user"
export PR_SSH_KEY_PATH="${HOME}/.ssh/gitlab-user"
export SSH_ID_KEY_FILE="${CI_SCRIPTS_DIR}/k8s/deploy/gitlab-user"
export SSH_ID_PUB_FILE="${CI_SCRIPTS_DIR}/k8s/deploy/gitlab-user.pub"
export ENV_VARS="${CI_SCRIPTS_DIR}/k8s/deploy/ci-cd-cluster.properties"
# export GIT_SSH_COMMAND="ssh -i ${CSR_SSH_KEY_PATH}" git clone ssh://APKA2IO25QZR6GGC7TSH@git-codecommit.us-west-2.amazonaws.com/v1/repos/gitlab-cicd-cluster-state-repo "${CSR_DIR}/"
# export GIT_SSH_COMMAND="ssh -i ${PR_SSH_KEY_PATH}" git clone ssh://APKA2IO25QZR6GGC7TSH@git-codecommit.us-west-2.amazonaws.com/v1/repos/gitlab-cicd-profile-repo "${PR_DIR}/"

# Change LOCAL to false if you _don't_ want to use a local copy of PCB for git-ops-command
export LOCAL="false"
