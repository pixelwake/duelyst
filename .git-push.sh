#!/bin/bash
GIT_SSH_COMMAND="ssh -i ~/.ssh/duelyst_deploy -o IdentitiesOnly=yes" git push "$@"
