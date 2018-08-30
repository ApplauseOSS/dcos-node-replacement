#!/usr/bin/env bash

#
# dcos_masters
#
# returns the list of DC/OS masters
function dcos_masters() { dcos node | grep master | awk '{print $2}'; };

dcos_masters
