---
linktitle: Lab 4 - Upgrade ROSA HCP Cluster 
title: Upgrade ROSA HCP Cluster
weight: 4
---

## Introduction
Red Hat OpenShift Service on AWS (ROSA) provides fully-managed cluster upgrades. The ROSA Site Reliability Engineering (SRE) Team will monitor and manage all ROSA cluster upgrades. Customers get status emails from the SRE team before, during, and after the upgrade. These updates can be scheduled from the OpenShift Cluster Manager (OCM) or from the ROSA CLI.

During ROSA upgrades, one node is upgraded at a time. This is done to ensure customer applications are not impacted during the update, when deployed in a highly-available and fault-tolerant method.

There are two ways to upgrade a ROSA cluster - using OpenShift Cluster Manager or using the `rosa` CLI. In this lab environment we do not have access to the OpenShift Cluster Manager so we will use the rosa CLI.

## Upgrade using the rosa command line interface 

1. Remind yourself of the version of your cluster:

          oc version

   Sample Output
   ```tpl
   Client Version: 4.13.26
   Kustomize Version: v4.5.7
   Server Version: 4.13.26
   Kubernetes Version: v1.26.11+7dfc52e
   ```
2. Find out the available versions

          rosa list upgrades --cluster rosa-${GUID}

 
   Sample Output
   ```tpl
   VERSION  NOTES
   4.16.14  recommended
   ```


    Note: Depending on when you run this command the available version list may be longer than just the next release.


3. You probably don’t want to actually upgrade the cluster right now since that may disrupt your lab environment. Luckily it is possible to schedule an update at a less inconvenient time.

   Get a date and time that is 24 hours from now:

          export UPGRADE_DATE=$(date -d "+24 hours" '+%Y-%m-%d')
          export UPGRADE_TIME=$(date '+%H:%M')

          echo Date: ${UPGRADE_DATE}, Time: ${UPGRADE_TIME}

   Sample Output
   ```tpl
   Date: 2023-04-18, Time: 19:51
   ```

4. Now schedule the cluster upgrade to a version shown in the list of available versions you found earlier (in the example above that is 4.13.25) - answer y when prompted if you really want to upgrade. To be clear, you will need to change the value specified in the --version line below to be something from the list upgrades command you ran before.

          rosa upgrade cluster \
            -c rosa-${GUID} \
            --version 4.16.14 \
            --mode auto \
            --schedule-date ${UPGRADE_DATE} \
            --schedule-time ${UPGRADE_TIME} \
            --control-plane 

   Sample Output
   ```tpl
   I: Ensuring account and operator role policies for cluster '25216tq1cq14etbb8rl91kqg2s1u4ssj' are compatible with upgrade.
   I: Account roles/policies for cluster '25216tq1cq14etbb8rl91kqg2s1u4ssj' are already up-to-date.
   I: Operator roles/policies associated with the cluster '25216tq1cq14etbb8rl91kqg2s1u4ssj' are already up-to-date.
   I: Account and operator roles for cluster 'rosa-bhjks' are compatible with upgrade
   ? Are you sure you want to upgrade cluster to version '4.13.1'? Yes
   I: Upgrade successfully scheduled for cluster 'rosa-6n4s8'
   ```

Congratulations! You’ve successfully scheduled an upgrade of your cluster for tomorrow at this time. While the workshop environment will be deleted before then, you now have the experience to schedule upgrades in the future.

## Additional Resources

### Red Hat OpenShift Upgrade Graph

Occasionally, you may be not be able to go directly from your current version to a desired version. In these cases, you must first upgrade your cluster from your current version, to an intermediary version, and then to your desired version. To help you navigate these decisions, you can take advantage of the [Red Hat OpenShift Upgrade Graph Tool](https://access.redhat.com/labs/ocpupgradegraph/update_path_rosa) (Red Hat portal login required).

In this scenario to upgrade your cluster from version 4.11.0 to 4.12.15, you must first upgrade to 4.11.39, then you can upgrade to 4.12.15. The ROSA Upgrade Graph Tool helps you easily see which version you should upgrade to.

### Links to Documentation

[Upgrading ROSA clusters with STS](https://docs.openshift.com/rosa/upgrading/rosa-upgrading-sts.html)

[Scheduling individual upgrades through the OpenShift Cluster Manager console](https://docs.openshift.com/rosa/upgrading/rosa-upgrading-sts.html#rosa-upgrade-ocm_rosa-upgrading-sts)

[Understanding update channels and releases](https://docs.openshift.com/container-platform/latest/updating/understanding_updates/understanding-update-channels-release.html)

## Summary

Here you learned:

* All upgrades are monitored and managed by the ROSA SRE Team

* Use OpenShift Cluster Manager (OCM) to schedule an upgrade for your ROSA cluster

* Explore the OpenShift Upgrade Graph Tool to see available upgrade paths
