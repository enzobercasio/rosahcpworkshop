---
linktitle: Lab 11 - Secure your applications with Network Policies
title: Secure your applications with Network Policies
weight: 11
---

## Introduction

NetworkPolicies are used to control and secure communication between pods within a cluster. They provide a declarative approach to define and enforce network traffic rules, allowing you to specify the desired network behavior. By using NetworkPolicies, you can enhance the overall security of your applications by isolating and segmenting different components within the cluster. These policies enable fine-grained control over network access, allowing you to define ingress and egress rules based on criteria such as IP addresses, ports, and pod selectors.

For this module we will be applying networkpolices to the previously created 'microsweeper-ex' namespace and using the 'microsweeper' app to test these policies. In addition, we will deploy two new applications to test against the 'microsweeper' app


1. Create a new project and a new app. We will be using this pod for testing network connectivity to the microsweeper application

         oc new-project networkpolicy-test

2. Create a new application within this namespace

         cat << EOF | oc apply -f -
        apiVersion: v1
        kind: Pod
        metadata:
        name: networkpolicy-pod
        namespace: networkpolicy-test
        labels:
            app: networkpolicy
        spec:
        securityContext:
            allowPrivilegeEscalation: false
        containers:
            - name: networkpolicy-pod
            image: registry.access.redhat.com/ubi9/ubi-minimal
            command: ["sleep", "infinity"]
        EOF

3. Now we will change to the microsweeper-ex project to start applying the network policies

        oc project microsweeper-ex

4. Fetch the IP address of the `microsweeper` Pod

        MS_IP=$(oc -n microsweeper-ex get pod -l \
            "app.kubernetes.io/name=microsweeper-appservice" \
            -o jsonpath="{.items[0].status.podIP}")
        echo $MS_IP

    Sample Output
    ```tpl
    10.128.2.242
    ```
5. Check to see if the `networkpolicy-pod` can access the microsweeper pod.

        oc -n networkpolicy-test exec -ti pod/networkpolicy-pod -- curl $MS_IP:8080 | head

    Sample Output
    ```tpl
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="X-UA-Compatible" content="ie=edge">
            <title>Microsweeper</title>
            <link rel="stylesheet" href="css/main.css">
            <script
                    src="https://code.jquery.com/jquery-3.2.1.min.js"
    ```
6. It’s common to want to prohibit Pods from accessing each other between projects (namespaces). This can be done with a fairly simple Network Policy.

    This Network Policy will restrict Ingress to the Pods in the project `microsweeper-ex` to just the OpenShift Ingress Pods and only on port 8080.

        cat << EOF | oc apply -f -
        ---
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
        name: allow-from-openshift-ingress
        namespace: microsweeper-ex
        spec:
        ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                network.openshift.io/policy-group: ingress
        podSelector: {}
        policyTypes:
        - Ingress
        EOF

    Sample Output

    ```tpl
        networkpolicy.networking.k8s.io/allow-from-openshift-ingress created
    ```
7. Try to access microsweeper from the `networkpolicy-pod` again

        oc -n networkpolicy-test exec -ti pod/networkpolicy-pod -- curl $MS_IP:8080 | head

    This time it should fail to connect - it will just sit there. Hit Ctrl-C to avoid having to wait until a timeout.

    ```tpl
    Tip: If you have your browser still open to the microsweeper app, you can refresh and see that you can still access it.
    ```

8. Sometimes you want your application to be accessible to other namespaces. You can allow access to just your microsweeper frontend from the networkpolicy-pod in the `networkpolicy-test` namespace like so

        cat <<EOF | oc apply -f -
        kind: NetworkPolicy
        apiVersion: networking.k8s.io/v1
        metadata:
        name: allow-networkpolicy-pod-ap
        namespace: microsweeper-ex
        spec:
        podSelector:
            matchLabels:
            app.kubernetes.io/name: microsweeper-appservice
        ingress:
            - from:
            - namespaceSelector:
                matchLabels:
                    kubernetes.io/metadata.name: networkpolicy-test
                podSelector:
                matchLabels:
                    app: networkpolicy
        EOF

    Sample Output
    ```tpl
    networkpolicy.networking.k8s.io/allow-networkpolicy-pod-ap created
    ```
9. Check to see if `networkpolicy-pod` can access the Pod.

        oc -n networkpolicy-test exec -ti pod/networkpolicy-pod -- curl $MS_IP:8080 | head

    Sample Output   
    ```tpl
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="X-UA-Compatible" content="ie=edge">
            <title>Microsweeper</title>
            <link rel="stylesheet" href="css/main.css">
            <script
                    src="https://code.jquery.com/jquery-3.2.1.min.js"
    ```
10. To verify that only the networkpolicy-pod app can access the microsweeper app, create a new pod with a different label in the `networkpolicy-test` namespace.

        cat << EOF | oc apply -f -
        apiVersion: v1
        kind: Pod
        metadata:
        name: new-test
        namespace: networkpolicy-test
        labels:
            app: new-test
        spec:
        securityContext:
            allowPrivilegeEscalation: false
        containers:
            - name: new-test
            image: registry.access.redhat.com/ubi9/ubi-minimal
            command: ["sleep", "infinity"]
        EOF

11. Try to curl the microsweeper-ex pod from our new pod.

        oc -n networkpolicy-test exec -ti pod/new-test -- curl $MS_IP:8080 | head

    This will fail with a timeout again. Hit Ctrl-C to avoid waiting for a timeout.

For information on setting default network policies for new projects you can read the OpenShift documentation on [modifying the default project template](https://docs.openshift.com/container-platform/latest/networking/network_policy/default-network-policy.html).

## Summary

Here’s what you learned:

* Network Policies are a powerful way to apply zero-trust networking patterns.

* Access to pods can be restricted to other Pods, Namespaces, or other labels.

* Access can be completely denied, allowed, or set to particular ports or services.