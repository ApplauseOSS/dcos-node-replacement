#!/usr/bin/env bash

export DCOS_USERNAME=${DCOS_USERNAME}
export DCOS_PASSWORD=${DCOS_PASSWORD}

#
# dcos_auth <cluster>
#
# Authorizes a session against the given cluster
function dcos_auth() {
  local readonly __cluster=${1}
  if [[ $(dcos config show cluster.name) != ${1} ]]; then
    dcos cluster attach ${1} || return 1
  fi
  dcos auth login --username=${DCOS_USERNAME} --password-env=DCOS_PASSWORD
}

dcos_auth ${@}
