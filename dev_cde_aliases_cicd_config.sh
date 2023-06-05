#!/bin/bash

# ping-cloud-base repo location
export PCB_PATH="${PROJECT_DIR}"

# NOTE: these variables must exactly match those set by your CLUSTER_NAME-cluster.properties file
export CSR_PATH="${HOME}/${CLUSTER_NAME}-cluster-state-repo"
export PR_PATH="${HOME}/${CLUSTER_NAME}-profile-repo"
# export PCB_SSH_KEY_PATH="${HOME}/.ssh/YOUR_GITHUB_SSH_KEY"
export CSR_SSH_KEY_PATH="${HOME}/.ssh/gitlab-user"
export PR_SSH_KEY_PATH="${HOME}/.ssh/gitlab-user"
export SSH_ID_KEY_FILE="${HOME}/.ssh/gitlab-user"
export SSH_ID_PUB_FILE="${HOME}/.ssh/gitlab-user.pub"
export ENV_VARS="${CI_SCRIPTS_DIR}/k8s/deploy/ci-cd-cluster.properties"
# echo "Cloning CSR & PR into ${CSR_PATH} and ${PR_PATH}"
# GIT_SSH_COMMAND="ssh -i ${CSR_SSH_KEY_PATH}" git clone ssh://APKA2IO25QZRRRNUAQPP@git-codecommit.us-west-2.amazonaws.com/v1/repos/${CLUSTER_NAME}-cluster-state-repo "${CSR_PATH}/"
# GIT_SSH_COMMAND="ssh -i ${PR_SSH_KEY_PATH}" git clone ssh://APKA2IO25QZRRRNUAQPP@git-codecommit.us-west-2.amazonaws.com/v1/repos/${CLUSTER_NAME}-profile-repo "${PR_PATH}/"

# Change LOCAL to false if you _don't_ want to use a local copy of PCB for git-ops-command
export LOCAL="false"

# Can add this to properties file ^^
