---
linktitle: Lab 12 - Make your application resilient
title: Make your application resilient
weight: 12
---

## Introduction

ROSA is designed with high availability and resiliency in mind. Within ROSA there are multiple tools at your disposal to leverage this highly available and resilient architecture to ensure maximum uptime and availability for your applications. Disruptions can occur for a variety of different reasons, but with proper configuration of the application, you can eliminate application disruption.

Limits and Requests can be used to both allocate and restrict the amount of resources an application can use, pod disruption budgets ensure that you always have a particular number of your application pods running and the Horizontal Pod Autoscaler can automatically increase and decrease pod count as needed.

In this section of the workshop, we will use the previously deployed microsweeper application, ensure the application is resilient to node failure, and scale the application when under load.

## Setting Limits and Requests on an Application 

1. First, let’s set limits and requests on the previously deployed microsweeper application.

         oc -n microsweeper-ex set resources deployment/microsweeper-appservice \
            --limits=cpu=60m,memory=250Mi \
            --requests=cpu=50m,memory=200Mi

    Requests state the minimum CPU and memory requirements for a container. This will ensure that the pod is placed on a node that can meet those requirements. Limits set the maximum amount of CPU and Memory that can be consumed by a container and ensure that a whole container does not consume all of the resources on a node. Setting limits and requests for deployments is best practice for resource management and ensuring the stability and reliability of your applications.


        oc adm top pods -n microsweeper-ex

    Sample Output
    ```tpl
    NAME                                       CPU(cores)   MEMORY(bytes)
    microsweeper-appservice-65799476b6-vh9q7   0m           191Mi
    ```
2. Now that we’ve updated the resource, we can see that a new pod was automatically rolled out with these new limits and requests. To do so, run the following command.

        oc get pods -n microsweeper-ex

    We’ll see a new pod (created 28 seconds earlier in this case):

    Sample Output
    ```tpl
    [user0_mobbws@bastion ~]$ oc get pods microsweeper-ex
    NAME                                       READY   STATUS      RESTARTS   AGE
    microsweeper-appservice-1-build            0/1     Completed   0          17h
    microsweeper-appservice-69596ccc54-fsw2b   1/1     Running      0          28s
    ```
    To see what the limits and requests added to the pod, run the following command:

        oc get pods -l app.kubernetes.io/name=microsweeper-appservice \
            -o yaml -n microsweeper-ex | grep limits -A5
            
    Sample Output
    ```tpl
        limits:
            cpu: 60m
            memory: 250Mi
        requests:
            cpu: 50m
            memory: 200Mi
    ```
 3. We can now use the route of the application to ensure the application is functioning with the new limits and requests. To get the route, run the following command

        oc -n microsweeper-ex get route microsweeper-appservice \
         -o jsonpath='http://{.spec.host}{"\n"}'    

    Then visit the URL presented in a new tab in your web browser (using HTTP). For example, your output will look something similar to:

    Sample Output
    ```tpl
    http://microsweeper-appservice-microsweeper-ex.apps.test-cluster.2ubs.p1.openshiftapps.com
    ```
    In that case, you’d visit `http://microsweeper-appservice-microsweeper-ex.apps.test-cluster.2ubs.p1.openshiftapps.com` in your browser.

4. Initially, this application is deployed with only one pod. In the event a worker node goes down or the pod crashes, there will be an outage of the application. To prevent that, let’s scale the number of instances of our applications up to three. To do so, run the following command

        oc -n microsweeper-ex scale deployment \
            microsweeper-appservice --replicas=3

5. Next, let’s check to see that the application has scaled. To do so, run the following command to see the pods

        oc -n microsweeper-ex get pods

    Sample Output
    ```tpl
    NAME                                       READY   STATUS      RESTARTS   AGE
    microsweeper-appservice-1-build            0/1     Completed   0          18h
    microsweeper-appservice-69596ccc54-6lstj   1/1     Running     0          2m41s
    microsweeper-appservice-69596ccc54-fsw2b   1/1     Running     0          39m
    microsweeper-appservice-69596ccc54-rkpgj   1/1     Running     0          2m41s
    ```
6. In addition you can see the number of pods, how many are on the current version, and how many are available by running the following

        oc -n microsweeper-ex get deployment microsweeper-appservice

    Sample Output
    ```tpl
    NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
    microsweeper-appservice   3/3     3            3           18h
    ```
## Pod Disruption Budget

A Pod Disruption Budget (PDB) allows you to limit the disruption to your application when its pods need to be rescheduled for upgrades or routine maintenance work on ROSA nodes. In essence, it lets developers define the minimum tolerable operational requirements for a deployment so that it remains stable even during a disruption.

For example, microsweeper-appservice deployed as part of the last step contains three replicas distributed evenly across three nodes. We can tolerate losing one pod, so we create a PDB that requires a minimum of one replica.

A `PodDisruptionBudget` object’s configuration consists of the following key parts:

* A label selector, which is a label query over a set of pods.

* An availability level, which specifies the minimum number of pods that must be available simultaneously, either:

    * minAvailable is the number of pods that must always be available, even during a disruption.
    * maxUnavailable is the number of pods that can be unavailable during a disruption.


Warning: A maxUnavailable of 0% or 0 or a minAvailable of 100% or equal to the number of replicas can be used but will block nodes from being drained and can result in application instability during maintenance activities.


1. Let’s create a Pod Disruption Budget for our `microsweeper-appservice` application. To do so, run the following command. 

        cat <<EOF | oc apply -f -
        apiVersion: policy/v1
        kind: PodDisruptionBudget
        metadata:
        name: microsweeper-appservice-pdb
        namespace: microsweeper-ex
        spec:
        minAvailable: 1
        selector:
            matchLabels:
            deployment: microsweeper-appservice
        EOF

    After creating the PDB, the OpenShift API will ensure at least one pod of `microsweeper-appservice` is running all the time, even when maintenance is going on within the cluster.

2. Next, let’s check the status of Pod Disruption Budget. To do so, run the following command

        oc -n microsweeper-ex get poddisruptionbudgets

    Sample Output
    ```tpl
    NAME              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
    microsweeper-appservice-pdb   1               N/A               0         39s
    ```
## Horizontal Pod Autoscaler

As a developer, you can utilize a horizontal pod autoscaler (HPA) in ROSA clusters to automate scaling of replication controllers or deployment configurations. The HPA adjusts the scale based on metrics gathered from the associated pods. It is applicable to deployments, replica sets, replication controllers, and stateful sets.

The HPA (Horizontal Pod Autoscaler) provides you with automated scaling capabilities, optimizing resource management and improving application performance. By leveraging an HPA, you can ensure your applications dynamically scale up or down based on workload. This automation reduces the manual effort of adjusting application scale and ensures efficient resource utilization, by only using resources that are needed at a certain time. Additionally, the HPA’s ease of configuration and compatibility with various workload types make it a flexible and scalable solution for developers in managing their applications.

In this exercise we will scale the microsweeper-appservice application based on CPU utilization:

* Scale out when average CPU utilization is greater than 50% of CPU limit

* Maximum pods is 4

* Scale down to min replicas if utilization is lower than threshold for 60 sec

1. First, we should create the HorizontalPodAutoscaler. To do so, run the following command

        cat <<EOF | oc apply -f -
        apiVersion: autoscaling/v2
        kind: HorizontalPodAutoscaler
        metadata:
        name: microsweeper-appservice-cpu
        namespace: microsweeper-ex
        spec:
        scaleTargetRef:
            apiVersion: apps/v1
            kind: Deployment
            name: microsweeper-appservice
        minReplicas: 2
        maxReplicas: 4
        metrics:
            - type: Resource
            resource:
                name: cpu
                target:
                averageUtilization: 50
                type: Utilization
        behavior:
            scaleDown:
            stabilizationWindowSeconds: 60
            policies:
            - type: Percent
                value: 100
                periodSeconds: 15
        EOF

2. Next, check the status of the HPA. To do so, run the following command

        oc -n microsweeper-ex get horizontalpodautoscaler/microsweeper-appservice-cpu

    Sample Output
    ```tpl
    NAME              REFERENCE                                        TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
    microsweeper-appservice-cpu   Deployment/microsweeper-appservice   0%/50%    2         4         3          43s
    ```
3. Next, let’s generate some load against the `microsweeper-appservice` application. To do so, run the following command

        FRONTEND_URL=http://$(oc -n microsweeper-ex get route microsweeper-appservice -o jsonpath='{.spec.host}')/

        ab -c100 -n10000 ${FRONTEND_URL}

4. Apache Bench will take around 100 seconds to complete (you can also hit CTRL-C to kill the ab command). Then immediately check the status of Horizontal Pod Autoscaler. To do so, run the following command:

        oc -n microsweeper-ex get horizontalpodautoscaler/microsweeper-appservice-cpu

    Sample Output
    ```tpl
    NAME                          REFERENCE                            TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
    microsweeper-appservice-cpu   Deployment/microsweeper-appservice   135%/50%   2         4         4          7m37s
    ```
    This means you are now running 4 replicas, instead of the original three that we started with.

5. Once you’ve killed the `ab` command, the traffic going to `microsweeper-appservice` service will cool down and after a 60 second cool down period, your application’s replica count will drop back down to two. To demonstrate this, run the following command

        oc -n microsweeper-ex get horizontalpodautoscaler/microsweeper-appservice-cpu --watch

    After a minute or two, your output should be similar to below
    ```tpl
    NAME                          REFERENCE                            TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
    microsweeper-appservice-cpu   Deployment/microsweeper-appservice   0%/50%     2         4         4          19m
    microsweeper-appservice-cpu   Deployment/microsweeper-appservice   0%/50%     2         4         4          19m
    microsweeper-appservice-cpu   Deployment/microsweeper-appservice   0%/50%     2         4         2          20m
    ```
## Summary

Here’s what you learned:

* Set Limits and Requests on the Microsweeper application from the previous section

* Scale the Microsweeper application up and down

* Set a Pod Disruption Budget on the Microsweeper application

* Set a Horizontal Pod Autoscaler to automatically scale application based on load.