#!/usr/bin/env bash

#
# dcos_hdfs_present
#
# returns zero if HDFS is installed
function dcos_hdfs_present() { dcos package list | grep ^hdfs >/dev/null; };

#
# dcos_hdfs_version
#
# returns version of installed HDFS package
function dcos_hdfs_version() { dcos package list | awk '/^hdfs/ {print $2}'; };

#
# dcos_hdfs_cli_install
#
# installs HDFS CLI (always returns true)
function dcos_hdfs_cli_install() {
  dcos package install hdfs --cli --package-version=$(dcos_hdfs_version) --yes >/dev/null
  return
}

#
# dcos_hdfs_lost_pods
#
# returns a list of LOST HDFS tasks
function dcos_hdfs_lost_pods() {
  dcos hdfs pod status --json | jq -r '.pods[].instances[].tasks[] | select(.status == "LOST") | .name'
}

#
# replace a HDFS pod, given a task name
#
# replaces a pod
function dcos_hdfs_pod_replace() { dcos hdfs pod replace ${1/-node/}; };

#
# gets pod status
#
# returns pod status, in JSON
function dcos_hdfs_pod_status_json() { dcos hdfs pod status ${1/-node/} --json; };

#
# get HDFS DFS report
#
# returns DFS REPORT
function dcos_hdfs_dfsadmin_report() {
  dcos node ssh --leader --user=${DCOS_SSH_USER:-${USER}} ${ADDITIONAL_DCOS_SSH_OPTS} \
    'docker run --rm -ti --log-driver=json-file mesosphere/hdfs-client:2.6.4 bash -c \"/configure-hdfs.sh\; /hadoop-2.6.0-cdh5.9.1/bin/hdfs dfsadmin -report\"' 2>/dev/null
}

#
# Return number of under replicated blocks
#
# returns number of blocks
function dcos_hdfs_under_replicated_blocks() { dcos_hdfs_dfsadmin_report | awk '/Under replicated/ {print $4}' | sed "s/\r//g"; };

#
# Return number of missing blocks
#
# retuns number of blocks
function dcos_hdfs_missing_blocks() { dcos_hdfs_dfsadmin_report | awk '/Missing blocks:/ {print $3}' | sed "s/\r//g"; };

#
# Return number of unrecoverable blocks
#
# returns number of blocks
function dcos_hdfs_missing_blocks_no_replica() { dcos_hdfs_dfsadmin_report | awk '/Missing blocks / {print $7}' | sed "s/\r//g"; };

#
# Check if HDFS is healthy
#
# returns false if unhealthy
dcos_hdfs_dfs_healthy() {
  local __loop __blocks
  for __loop in missing_blocks missing_blocks_no_replica; do
    __blocks=$(dcos_hdfs_${__loop})
    if [[ -z ${__blocks} ]] || [[ ${__blocks} -ne 0 ]]; then
      echo "ERROR: HDFS unhealthy! There are ${__blocks} ${__loop} in HDFS!"
      return 1
    fi
    echo "[x] ${__loop} is ${__blocks}... OK"
  done
}

#
# Check if a given task is running
#
# returns 0 if task is running, else 1
function dcos_hdfs_task_running() {
  local readonly __task=${1}
  dcos_hdfs_pod_status_json ${__task} | jq -r ".tasks[] | select(.name == \"${__task}\") | .status" | grep RUNNING >/dev/null
}

#
# Main function
#
# This function will use the other functions to bring HDFS back into a clean state.
# - See if HDFS is installed
# - Check for missing blocks
# - Install necessary dcos CLI for HDFS
# - Get list of LOST tasks
# - Replace all pods for LOST tasks
# - Poll for all pods RUNNING
# - Poll for under-replicated blocks
#
# returns 0 on success, 1 on failure
dcos_hdfs() {
  # return immediately if there's no DC/OS on the cluster
  dcos_hdfs_present || return
  echo "DC/OS HDFS service installed..."
  echo
  # Check HDFS health
  echo "Checking if HDFS is healthy..."
  dcos_hdfs_dfs_healthy || return 1
  echo
  echo "HDFS DFS Admin report:"
  echo
  dcos_hdfs_dfsadmin_report | grep -v 'current working' | head
  echo
  dcos_hdfs_cli_install
  local __task __timeout=300 __backoff=0 __ret=0
  local readonly __lost=$(dcos_hdfs_lost_pods)
  # This is two loops so we start replacements as soon as possible
  for __task in ${__lost}; do
    echo "Replacing pod containing ${__task}"
    dcos_hdfs_pod_replace ${__task} || return 1
  done
  # The second loop does the polling
  for __task in ${__lost}; do
    echo "Polling ${__task} for RUNNING status..."
    until dcos_hdfs_task_running ${__task} || [[ ${__backoff} -ge ${__timeout} ]]; do
      sleep $(( __backoff++ ))
    done
    __ret=$?
    if [[ ${__backoff} -ge ${__timeout} ]]; then
      echo "ERROR: timed out waiting for ${__task}"
      return 1
    fi
  done
  # Final loop waits until replication is complete
  __backoff=0 __timeout=3600
  local __under_replicated=$(dcos_hdfs_under_replicated_blocks)
  if [[ ${__under_replicated} -ne 0 ]]; then
    echo
    echo "Found ${__under_replicated} under replicated blocks... polling for replication completion"
  fi
  until [[ dcos_hdfs_under_replicated_blocks -eq 0 ]] || [[ ${__backoff} -ge ${__timeout} ]]; do
    sleep $(( __backoff++ ))
    # Since this may be a long poll, let's give output every minute
    if [[ $(( ${__backoff} % 60)) -eq 0 ]]; then
      echo "Remaining blocks to replicate: $(dcos_hdfs_under_replicated_blocks)"
    fi
  done
  if [[ -n ${__lost} ]]; then
    # Check HDFS health
    echo "Checking if HDFS is healthy..."
    dcos_hdfs_dfs_healthy || return 1
  fi
  echo
  echo "HDFS service complete"
  echo
}

dcos_hdfs
