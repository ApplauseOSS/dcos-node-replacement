#!/usr/bin/env bash

#
# dcos_leader
#
# returns DC/OS leader IP
function dcos_leader() { dcos node | grep leader | awk '{print $2}'; };

dcos_leader
