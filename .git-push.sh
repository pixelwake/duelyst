#!/bin/bash
GIT_SSH_COMMAND="ssh -i ~/.ssh/project_dvasia -o IdentitiesOnly=yes" git push "$@"
