---
linktitle: Lab 5 - Managing Worker Nodes
title: Managing Worker Nodes
weight: 5
---

## Introduction
When deploying your ROSA cluster, you can configure many aspects of your worker nodes, but what happens when you need to change your worker nodes after they’ve already been created? These activities include scaling the number of nodes, changing the instance type, adding labels or taints, just to name a few.

Many of these changes are done using Machine Pools. Machine Pools ensure that a specified number of Machine replicas are running at any given time. Think of a Machine Pool as a "template" for the kinds of Machines that make up the worker nodes of your cluster. If you’d like to learn more, see the [Red Hat documentation on worker node management](https://docs.openshift.com/rosa/rosa_cluster_admin/rosa_nodes/rosa-managing-worker-nodes.html).

Here are some of the advantages of using ROSA Machine Pools to manage the size of your cluster

* Scalability - A ROSA Machine Pool enables horizontal scaling of your cluster. It can easily add or remove worker nodes to handle the changes in workload. This flexibility ensures that your cluster can dynamically scale to meet the needs of your applications

* High Availability - ROSA Machine Pools supports the creation of 3 replicas of workers across different availability zones. This redundancy helps ensure high availability of applications by distributing workloads.

* Infrastructure Diversity - ROSA Machine Pools allow you to provision worker nodes of different instance types. This enables you to leverage the best kind of instance family for different workloads.

* Integration with Cluster Autoscaler - ROSA Machine Pools seamlessly integrate with the Cluster Autoscaler feature, which automatically adjusts the number of worker nodes based on the current demand. This integration ensures efficient resource utilization by scaling the cluster up or down as needed, optimizing costs and performance.

## Scaling Worker Nodes 

### Via the CLI

1. First, let’s see what Machine Pools already exist in our cluster. To do so, run the following command

       rosa list machinepools -c rosa-${GUID}

   Sample Output
   ```tpl    
   ID       AUTOSCALING  REPLICAS  INSTANCE TYPE  LABELS    TAINTS    AVAILABILITY ZONE  SUBNET                    DISK SIZE  VERSION  AUTOREPAIR  
   workers  No           2/2       m5.xlarge                          ap-southeast-1c    subnet-0c6e1f11632b044a8  300 GiB    4.15.34  Yes    
   ```
2. Now, let’s take a look at the nodes inside of the ROSA cluster that have been created according to the instructions provided by the above MachineSets. To do so, run the following command:

       oc get nodes

   Sample Output
   ```tpl
   NAME                                            STATUS     ROLES    AGE   VERSION
   ip-10-0-0-237.ap-southeast-1.compute.internal   Ready      worker   14m   v1.28.13+2ca1a23
   ip-10-0-0-42.ap-southeast-1.compute.internal    Ready      worker   24s   v1.28.13+2ca1a23
   ```
   For this workshop, we’ve deployed your ROSA cluster with 2 total worder nodes. 

3. Now that we know that we have two worker nodes, let’s create a MachinePool to add a new worker node using the ROSA CLI. To do so, run the following command

       rosa create machinepool -c rosa-${GUID} --replicas 1 --name workshop --instance-type m5.xlarge

   Sample Output 
   ```tpl
   I: Fetching instance types
   I: Machine pool 'workshop' created successfully on cluster 'rosa-6n4s8'
   I: To view all machine pools, run 'rosa list machinepools -c rosa-6n4s8'     
   ```

   This command adds a single m5.xlarge instance to the first AWS availability zone in the region your cluster is deployed in.

4. Now, let’s scale up our selected MachinePool from one to two machines. To do so, run the following command

       rosa update machinepool -c rosa-${GUID} --replicas 2 workshop

   Sample Output
   ```tpl
   I: Updated machine pool 'workshop' on cluster 'rosa-6n4s8'
   ```

5. Now that we’ve scaled the MachinePool to two machines, we can see that the node is already being created. First, let’s quickly check the output of the `oc get nodes` command we ran earlier

       oc get nodes

   Sample Output
   ```tpl
   NAME                                            STATUS   ROLES    AGE     VERSION
   ip-10-0-0-237.ap-southeast-1.compute.internal   Ready    worker   20m     v1.28.13+2ca1a23
   ip-10-0-0-42.ap-southeast-1.compute.internal    Ready    worker   6m53s   v1.28.13+2ca1a23  
   ip-10-0-0-111.ap-southeast-1.compute.internal   NotReady   worker   0s      v1.28.13+2ca1a23
   ip-10-0-0-111.ap-southeast-1.compute.internal   NotReady   worker   0s      v1.28.13+2ca1a23
   ```
6. Let the above command run until all nodes are in the Ready state. This means that they are ready and available to run Pods in the cluster. Hit CTRL-C to exit the oc command.

7. We don’t need these extra worker nodes for now so let’s scale the cluster back down to a total of 3 worker nodes by scaling down the "Workshop" Machine Pool. To do so, run the following command:

       rosa update machinepool -c rosa-${GUID} --replicas 1 workshop

8. Now that we’ve scaled the MachinePool (and therefore the MachineSet) back down to one machine, we can see the change reflected in the cluster almost immediately. Let’s quickly check the output of the same command we ran before:

        oc get nodes -w

    Sample Output 
    ```tpl
    NAME                                            STATUS   ROLES    AGE    VERSION
    ip-10-0-0-111.ap-southeast-1.compute.internal   Ready    worker   4m4s   v1.28.13+2ca1a23
    ip-10-0-0-237.ap-southeast-1.compute.internal   Ready    worker   25m    v1.28.13+2ca1a23
    ip-10-0-0-42.ap-southeast-1.compute.internal    Ready    worker   12m    v1.28.13+2ca1a23
    ip-10-0-0-74.ap-southeast-1.compute.internal    Ready    worker   4m3s   v1.28.13+2ca1a23
    ip-10-0-0-74.ap-southeast-1.compute.internal    Ready,SchedulingDisabled   worker   4m45s   v1.28.13+2ca1a23
    ```

Congratulations! You’ve successfully scaled your cluster up and back down to two worker nodes.

## Summary

Here you learned:

* Creating a new Machine Pool for your ROSA cluster to add additional nodes to the cluster

* Scaling your new Machine Pool up to add more nodes to the cluster

* Scaling your Machine Pool down to remove worker nodes from the cluster

