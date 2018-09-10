#!/usr/bin/env bash

#
# dcos_agents_by_zone <zone>
#
# returns a list of DC/OS agent IP addresses within a given zone
dcos_agents_by_zone() { dcos node | grep agent | grep ${1} | awk '{print $2}'; };

dcos_agents_by_zone ${@}
