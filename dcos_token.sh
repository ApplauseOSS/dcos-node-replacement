#!/usr/bin/env bash

#
# dcos_token
#
# returns DC/OS token from configured cluster
function dcos_token() { dcos config show core.dcos_acs_token; };

dcos_token
