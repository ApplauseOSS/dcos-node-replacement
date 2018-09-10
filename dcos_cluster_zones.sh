#!/usr/bin/env bash

#
# dcos_cluster_zones
#
# returns a list of zones for DC/OS agents
function dcos_cluster_zones() { dcos node | grep agent | awk '{print $6}' | sort -u; };

dcos_cluster_zones
