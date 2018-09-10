#!/usr/bin/env bash

#
# dcos_wait_for <type> <count>
#
# Poll the DC/OS CLI until the count of the given type is reached
function dcos_wait_for() {
  local readonly __type=${1} __count=${2}
  # We do the awk + second grep to ensure its the correct type
  until [[ $(dcos node | awk "\$4 ~ /${__type}/ {print \$4}" | wc -w) -eq ${__count} ]]; do
    sleep 60
  done
}

dcos_wait_for ${@}
