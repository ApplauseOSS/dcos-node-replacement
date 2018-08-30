#!/usr/bin/env bash

#
# dcos_ssh <ip> [command]
#
# Performs an SSH to a DC/OS node and runs an optional command
function dcos_ssh() {
  local readonly __ip=${1}
  shift
  local readonly __command=${@}
  if [[ ${JUMPHOST_IP} ]]; then
    local readonly __proxy="--proxy-ip=${JUMPHOST_IP}"
  fi
  local readonly __user=${SSH_USER:-${USER}}
  dcos node ssh \
    --user=${__user} \
    ${__proxy} \
    --option StrictHostKeyChecking=no \
    --private-ip=${__ip} \
    "${__command}" | sed 's/Connection to .* closed.//g' | sed 's/\r//g'
}

dcos_ssh ${@}
