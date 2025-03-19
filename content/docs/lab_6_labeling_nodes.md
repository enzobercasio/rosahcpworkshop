---
linktitle: Lab 6 - Labeling Worker Nodes
title: Labeling Worker Nodes
weight: 6
---

## Introduction

Labels are a useful way to select which nodes that an application will run on. These nodes are created by machines which are defined by the MachineSets we worked with in previous sections of this workshop. An example of this would be running a memory intensive application only on a specific node type.

While you can directly add a label to a node, it is not recommended because nodes can be recreated, which would cause the label to disappear. Therefore we need to label the Machine pool itself.

## Set a label for the Machine Pool

1. Just like the last section, let’s use the workshop machine pool to add our label. We will add the label "tier=frontend" to nodes in this machine pool. To do so, run the following command

        rosa edit machinepool -c rosa-${GUID} --labels tier=frontend workshop

    Sample Output
    ```tpl
    I: Updated machine pool 'workshop' on cluster 'rosa-6n4s8'
    ```

2. Now, let’s verify the nodes are properly labeled. To do so, run the following command

        oc get nodes --selector='tier=frontend' -o name

    Sample Output
    ```tpl
    node/ip-10-0-0-165.ap-southeast-1.compute.internal
    node/ip-10-0-0-172.ap-southeast-1.compute.internal  
    ```
You may see between one and two nodes - depending if you did the scaling lab recently (if you did the cluster has probably not scaled down yet). This demonstrates that our machine pool and associated nodes are properly annotated!

## Deploy an app to the labeled nodes 

Now that we’ve successfully labeled our nodes, let’s deploy a workload to demonstrate app placement using `nodeSelector`. This should force our app to only deploy on our labeled nodes.

1. First, let’s create a project (or namespace) for our application. To do so, run the following command

        oc new-project nodeselector-ex

    Sample Output
    ```tpl
    Now using project "nodeselector-ex" on server "https://api.rosa-6n4s8.1c1c.p1.openshiftapps.com:6443".

    You can add applications to this project with the 'new-app' command. For example, try:

        oc new-app rails-postgresql-example

    to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:

        kubectl create deployment hello-node --image=k8s.gcr.io/e2e-test-images/agnhost:2.33 -- /agnhost serve-hostname
    ```

2. Next, let’s deploy our application and associated resources that will target our labeled nodes. To do so, run the following command:

       cat << EOF | oc apply -f -
       kind: Deployment
       apiVersion: apps/v1
       metadata:
         name: nodeselector-app
         namespace: nodeselector-ex
       spec:
         replicas: 1
         selector:
           matchLabels:
             app: nodeselector-app
         template:
           metadata:
             labels:
               app: nodeselector-app
           spec:
             nodeSelector:
               tier: frontend
             containers:
               - name: hello-openshift
                 image: "docker.io/openshift/hello-openshift"
                 ports:
                   - containerPort: 8080
                     protocol: TCP
                   - containerPort: 8888
                     protocol: TCP
                 securityContext:
                   allowPrivilegeEscalation: false
                   capabilities:
                     drop:
                       - ALL
       EOF

    Sample Output
    ```tpl
    deployment.apps/nodeselector-app created
    ```

4. Double check the name of the node to compare it to the output above to ensure the node selector worked to put the pod on the correct node.

        oc get nodes --selector='tier=frontend' -o name

    Sample Output 

        node/ip-10-0-133-248.us-east-2.compute.internal
        node/ip-10-0-146-31.us-east-2.compute.internal
        
5. Next create a `service` using the `oc expose` command

        oc expose deployment nodeselector-app

    Sample Output
    ```tpl
    service/nodeselector-app exposed
    ```

6. Expose the newly created `service` with a `route`

        oc create route edge --service=nodeselector-app  --insecure-policy=Redirect

    Sample Output
    ```tpl
    route.route.openshift.io/nodeselector-app created
    ```

7. Fetch the URL for the newly created route

        oc get routes/nodeselector-app -o json | jq -r '.spec.host'

    Then visit the URL presented in a new tab in your web browser.

    Note that the application is exposed over the default ingress using a predetermined URL and trusted TLS certificate. This is done using the OpenShift `Route` resource which is an extension to the Kubernetes `Ingress` resource.

8. Now let’s scale the cluster back down to a total of 2 worker nodes by deleting the "Workshop" Machine Pool. To do so, run the following command:

        rosa delete machinepool -c rosa-${GUID} workshop --yes

    Sample Output 
    ```tpl
    I: Successfully deleted machine pool 'workshop' from cluster 'rosa-6n4s8'
    ```

9. You can validate that the MachinePool has been deleted by using the rosa cli

        rosa list machinepools -c rosa-${GUID}

Congratulations! You’ve successfully demonstrated the ability to label nodes and target those nodes using `nodeSelector`.

## Summary

Here you learned:

* Add labels to Machine Pools

* Deploy an application on nodes with certain labels using nodeSelector
