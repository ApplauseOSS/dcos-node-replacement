#!/usr/bin/env bash

#
# aws_instance_id <ip>
#
# returns an instance ID from a given IP address
function aws_instance_id() {
  local readonly __ip=${1} __region=${2:-us-east-1}
  aws ec2 describe-instances --region=${__region} \
    --filters "Name=private-ip-address,Values=${__ip}" \
    --query "Reservations[].Instances[].InstanceId|[0]" | \
    tr -d '"'
}

#
# aws_instance_state <id> [region]
#
# return the state of an AWS instance
function aws_instance_state() {
  local readonly __id=${1} __region=${2:-us-east-1}
  aws ec2 describe-instances --region=${__region} --filters "Name=instance-id,Values=${__id}" \
    --query "Reservations[].Instances[].State.Name|[0]" | \
    tr -d '"'
}

#
# aws_until_state <state> <id> [timeout]
#
# polls instance until given state, with back-off and timeout
function aws_until_state() {
  local readonly __state=${1} __id=${2} __timeout=${3:-60} __backoff=0 __ret=0
  until [[ $(aws_instance_state ${__id}) == ${__state} ]] || [[ ${__backoff} -ge ${__timeout} ]]; do
    sleep $(( __backoff++ ))
  done
  __ret=$?
  if [[ ${__backoff} -ge ${__timeout} ]]; then
    return 1
  fi
  return ${__ret}
}

#
# aws_terminate <ip> [timeout]
#
# Terminates a given instance by its IP address
function aws_terminate() {
  local readonly __ip=${1} __timeout=${2:-120}
  local __dry_run __id __result __ret
  [[ ${DRY_RUN} ]] && __dry_run="--dry-run"
  __id=$(aws_instance_id ${__ip})
  ### TODO: region is hard-coded here... improve
  __result=$(aws ec2 terminate-instances --region=us-east-1 --instance-ids ${__id} ${__dry_run} 2>&1 >/dev/null)
  __ret=$?
  if [[ ${__ret} -eq 255 ]]; then
    echo "User specified DRY_RUN... skipping"
    return # do nothing, as we're in a dry-run
  elif [[ ${__ret} -ne 0 ]]; then
    return ${__ret}
  fi
  if [[ ${DEBUG} ]]; then
    aws_until_state terminated ${__id} ${__timeout} || return $?
  else
    sleep 3 # slight sleep to reduce errors
  fi
  return
}

aws_terminate ${@}
