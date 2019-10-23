#!/usr/bin/env bash

export DCOS_USERNAME=${DCOS_USERNAME}
export DCOS_PASSWORD=${DCOS_PASSWORD}

#
# dcos_cli_install [version]
#
# Fetches the dcos CLI
function dcos_cli_install() {
  local readonly __version=${1:-1.12}
  local __os
  if [[ $(type -P dcos) ]]; then
    return 0
  fi
  [[ -d /usr/local/bin ]] || sudo mkdir -p /usr/local/bin
  case $(uname -s) in
    *inux) __os="linux" ;;
    *arwin) __os="darwin" ;;
    *) return 1 ;;
  esac
  curl https://downloads.dcos.io/binaries/cli/${__os}/x86-64/dcos-${__version}/dcos > /tmp/dcos-${__os} || return 1
  sudo mv -f /tmp/dcos-${__os} /usr/local/bin/dcos || return 1
  sudo chmod 755 /usr/local/bin/dcos || return 1
  return 0
}

#
# dcos_cluster_setup <master>
#
# Configures a cluster given a master address
function dcos_cluster_setup() {
  local readonly __master=${1}
  dcos_cli_install || return 1
  dcos cluster setup ${__master} --no-check --username=${DCOS_USERNAME} --password=${DCOS_PASSWORD}
}

dcos_cluster_setup ${@}
