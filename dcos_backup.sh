#!/usr/bin/env bash

# Install/upgrade DC/OS Enterprise CLI
dcos package install dcos-enterprise-cli --yes 2>&1 >/dev/null

#
# dcos_backup_ready <label> [timeout]
#
# Wait for backup to complete, with back-off and timeout
function dcos_backup_ready() {
  local readonly __label=${1} __timeout=${2:-60}
  local __backoff=0
  until dcos backup list ${__label} | grep ${__label} | awk '{print $3}' | grep STATUS_READY >/dev/null || [[ ${__backoff} -ge ${__timeout} ]]; do
    sleep $(( __backoff++ ))
  done
}

#
# dcos_backup [label]
#
# Creates a backup, returns 0 on success, 1 on failure to schedule, 2 on failure to backup
dcos_backup() {
  local readonly __label=${1:-bu-$(date +%s)}
  local __ret
  dcos backup create --label=${__label} || return 1
  dcos_backup_ready ${__label} || return 2
}

dcos_backup ${@}
