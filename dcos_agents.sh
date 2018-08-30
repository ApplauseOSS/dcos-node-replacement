#!/usr/bin/env bash

#
# dcos_agents
#
# returns the DC/OS agent IP addresses
function dcos_agents() { dcos node | awk '/agent/ {print $2}'; };

dcos_agents
