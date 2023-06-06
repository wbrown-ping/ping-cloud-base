#!/bin/bash

# ping-cloud-base repo location
export PCB_PATH="${PROJECT_DIR}"

# NOTE: these variables must exactly match those set by your CLUSTER_NAME-cluster.properties file
export CSR_PATH="${HOME}/${CLUSTER_NAME}-cluster-state-repo"
export PR_PATH="${HOME}/${CLUSTER_NAME}-profile-repo"
export CSR_SSH_KEY_PATH="${HOME}/.ssh/gitlab-user"
export PR_SSH_KEY_PATH="${HOME}/.ssh/gitlab-user"
export SSH_ID_KEY_FILE="${HOME}/.ssh/gitlab-user"
export SSH_ID_PUB_FILE="${HOME}/.ssh/gitlab-user.pub"
export ENV_VARS="${CI_SCRIPTS_DIR}/k8s/deploy/ci-cd-cluster.properties"
export PF_PROVISIONING_ENABLED=false
# Change LOCAL to false if you _don't_ want to use a local copy of PCB for git-ops-command
export LOCAL="false"