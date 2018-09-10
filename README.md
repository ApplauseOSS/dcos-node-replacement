# README

This repository contains scripts to perform a node replacement on a DC/OS
cluster. It uses the `dcos` CLI tool to communicate with a DC/OS cluster
and the `aws` CLI tool to communicate with AWS. It's assumed that AWS
credentials have already been fetched or this is running on an instance
with an instance profile capable of performing the EC2 actions.

## Quick Start

It's not required to export username and password, unless you want to
run without interaction.

```
export DCOS_USERNAME=<username>
export DCOS_PASSWORD=<password>

./dcos_cluster_setup.sh <master_url>
./runner
```

## Order

### Sanity

* `dcos_sanity_check zookeeper` returns 0
* `dcos_sanity_check leader` returns 0

### Preparation

* Run core-infrastructure
* `dcos_backup.sh` to start backup (wait for it to complete)

### Masters

* Remove 1 non-leader master
  * `dcos_sanity_check.sh cockroachdb` return 0
  * `dcos_sanity_check.sh master_snapshot` return 0
* Remove another non-leader master
  * `dcos_sanity_check.sh cockroachdb` return 0
  * `dcos_sanity_check.sh master_snapshot` return 0
* Remove former leader
  * `dcos_sanity_check.sh cockroachdb` return 0
  * `dcos_sanity_check.sh master_snapshot` return 0

### Agents

* Get zone list from `dcos_cluster_zones.sh`

#### Per-zone

* Get agent IPs: `dcos_agents_by_zone.sh <zone>`
* For each IP: `aws_terminate.sh` <ip>
* Wait for agents up using `dcos_agents_by_zone.sh <zone>`

