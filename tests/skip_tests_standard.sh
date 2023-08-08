# This file will be sourced during CI/CD execution, and appended to any BRANCH_SKIP_TESTS variables that have been previously declared.
# It is intended for 'standard' (non customer-hub) deploys
export SCHEDULE_SKIP_TESTS="pingcentral/prerequisites/00-test-urls.sh
pingcentral/prerequisites/01-verify-pods.sh"