#!/usr/bin/env bash

#
# dcos_agent_mesos_id <ip>
#
# returns the Mesos ID of an agent, given an IP
dcos_agent_mesos_id() { dcos node | grep agent | grep ${1} | awk '{print $3}'; };

#
# dcos_decommission_agent <ip>
#
# decommissions a node, if it exists
dcos_decommission_agent() {
  local readonly __ip=${1}
  local __output __ret=0
  __output=$(dcos_agent_mesos_id ${__ip} 2>/dev/null)
  __ret=$?
  if [[ ${__ret} -ne 0 ]]; then
    return ${__ret}
  fi
  if [[ ${__output} ]]; then
    dcos node decommission ${__output}
    __ret=$?
  fi
  return 0
}

dcos_decommission_agent ${@}
