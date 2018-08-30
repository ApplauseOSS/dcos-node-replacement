#!/usr/bin/env bash

#
# dcos_agent_snapshot_sanity <ip>
#
# Verifies the sanity of agent snapshot
function dcos_agent_snapshot_sanity() {
  local readonly __ip=${1}
  local __output __ret=0
  __output=$($(pwd -P)/dcos_ssh.sh ${__ip} "curl -fsSL http://${__ip}:5051/metrics/snapshot" 2>/dev/null)
  __ret=$?
  if [[ ${__ret} -ne 0 ]]; then
    return ${__ret}
  fi
  # Fail if we're not registered
  if [[ $(echo ${__output} | jq '."slave/registered"') -ne 1 ]]; then
    return 1
  fi
  return 0
}

#
# dcos_cockroach_sanity <ip>
#
# Verifies the sanity of a cockroachdb
function dcos_cockroach_sanity() {
  local readonly __ip=${1}
  $(pwd -P)/dcos_ssh.sh ${__ip} "sudo /opt/mesosphere/bin/cockroach node status --ranges --certs-dir=/run/dcos/pki/cockroach --host=${__ip} --format=csv" 2>/dev/null | grep -v '^#' | tail -n +2 | rev | cut -d, -f1 | rev
}

#
# dcos_leader_sanity <ip>
#
# Verifies the sanity of leader.mesos DNS entry
function dcos_leader_sanity() {
  local readonly __ip=${1} __leader=$($(pwd -P)/dcos_leader.sh)
  local __output __ret=0
  __output=$($(pwd -P)/dcos_ssh.sh ${__ip} "host leader.mesos" 2>/dev/null | awk '{print $4}' | head -n 1)
  __ret=$?
  if [[ ${__ret} -ne 0 ]]; then
    return ${__ret}
  fi
  if [[ ${__output} != ${__leader} ]]; then
    return 1
  fi
  return 0
}

#
# dcos_master_snapshot_sanity <ip>
#
# Verifies the sanity of master snapshot
function dcos_master_snapshot_sanity() {
  local readonly __ip=${1}
  local __output __ret=0
  __output=$($(pwd -P)/dcos_ssh.sh ${__ip} "curl -fsSL http://${__ip}:5050/metrics/snapshot" 2>/dev/null)
  __ret=$?
  if [[ ${__ret} -ne 0 ]]; then
    return ${__ret}
  fi
  # Fail if we're not recovered
  if [[ $(echo ${__output} | jq '."registrar/log/recovered"') -ne 1 ]]; then
    return 1
  fi
  return 0
}

#
# dcos_zookeeper_sanity <ip>
#
# Verifies the sanity of ZooKeeper
function dcos_zookeeper_sanity() {
  local readonly __ip=${1}
  local __output __ret=0
  __output=$($(pwd -P)/dcos_ssh.sh ${__ip} "curl -fsSL http://localhost:8181/exhibitor/v1/cluster/status" 2>/dev/null)
  __ret=$?
  if [[ ${__ret} -ne 0 ]]; then
    return ${__ret}
  fi
  # Fail if master isn't serving
  if [[ $(echo ${__output} | jq ".[] | select(.hostname == \"${__ip}\") | .description" | sed 's/"//g') != 'serving' ]]; then
    return 1
  fi
  if [[ $(echo ${__output} | jq ".[] | select(.hostname == \"${__ip}\") | .isLeader") == true ]]; then
    # We're a leader, so output true
    echo true
  else
    echo false
  fi
  return 0
}

#
# dcos_sanity_check <check>
#
# Verifies the sanity of a given check type
function dcos_sanity_check() {
  local readonly __check=${1}
  local __failed=0
  case ${__check} in
    agent_snapshot)
      local readonly __agents=$($(pwd -P)/dcos_agents.sh)
      local __host
      for __host in ${__agents}; do
        dcos_agent_snapshot_sanity ${__host} || return $?
      done
      return 0 # redundant, but explicit
    ;;
    cockroachdb)
      local readonly __masters=$($(pwd -P)/dcos_masters.sh)
      local __host __output __ret=0
      for __host in ${__masters}; do
        for __output in $(dcos_cockroach_sanity ${__host}); do
          __ret=$?
          if [[ ${__ret} -ne 0 ]]; then
            return ${__ret}
          fi
          if [[ ${__output} -ne 0 ]]; then
            __failed=1
            break
          fi
        done
        if [[ ${__failed} -ne 0 ]]; then
          break
        fi
      done
      return ${__failed}
    ;;
    leader)
      local readonly __masters=$($(pwd -P)/dcos_masters.sh)
      local __host
      for __host in ${__masters}; do
        dcos_leader_sanity ${__host} || return $?
      done
      return 0 # redundant, but explicit
    ;;
    master_snapshot|snapshot)
      local readonly __masters=$($(pwd -P)/dcos_masters.sh)
      local __host
      for __host in ${__masters}; do
        dcos_master_snapshot_sanity ${__host} || return $?
      done
      return 0 # redundant, but explicit
    ;;
    zookeeper)
      local readonly __masters=$($(pwd -P)/dcos_masters.sh)
      local __host __output __leader=0 __ret=0
      for __host in ${__masters}; do
        for __output in $(dcos_zookeeper_sanity ${__host}); do
          __ret=$?
          if [[ ${__ret} -ne 0 ]]; then
            return ${__ret}
          fi
          if [[ ${__output} == true ]]; then
            # We're a leader
            __leader=1
          fi
        done
      done
      # At this point, we will have a leader
      if [[ ${__leader} -ne 1 ]]; then
        return 1
      fi
      return 0 # redundant, but explicit
    ;;
  esac
}

dcos_sanity_check ${@}
