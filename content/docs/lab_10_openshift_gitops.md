---
linktitle: Lab 10 - Deploy an application with Red Hat OpenShift GitOps
title: Deploy an application with Red Hat OpenShift GitOps
weight: 10
---

## Introduction

Red Hat® OpenShift® GitOps is an operator that provides a workflow that integrates git repositories, continuous integration/continuous delivery (CI/CD) tools, and Kubernetes to realize faster, more secure, scalable software development, without compromising quality.

OpenShift GitOps enables customers to build and integrate declarative git driven CD workflows directly into their application development platform.

There’s no single tool that converts a development pipeline to "DevOps". By implementing a GitOps framework, updates and changes are pushed through declarative code, automating infrastructure and deployment requirements, and CI/CD.

OpenShift GitOps takes advantage of [Argo CD](https://argoproj.github.io/cd) and integrates it into Red Hat OpenShift to deliver a consistent, fully supported, declarative Kubernetes platform to configure and use with GitOps principles.

OpenShift and OpenShift GitOps:

* Apply consistency across cluster and deployment lifecycles

* Consolidate administration and management of applications across on-premises and cloud environments

* Check the state of clusters making application constraints known early

* Rollback code changes across clusters

* Roll out new changes submitted via Git


## Create an Amazon DynamoDB Instance

1. From the OpenShift Console Administrator view click through HOME -> Operators -> Operator Hub, search for "Red Hat Openshift GitOps" and click Install.

For the update channel select gitops-1.11. Leave all other defaults and click Install.

2. Wait until the operator shows as successfully installed (Installed operator - ready for use).

3. In your bastion VM create a new project

        oc new-project bgd
    
    Sample Output
    ```tpl
    Now using project "bgd" on server "https://api.rosa-6n4s8.1c1c.p1.openshiftapps.com:6443".

    You can add applications to this project with the 'new-app' command. For example, try:

        oc new-app rails-postgresql-example

    to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:

        kubectl create deployment hello-node --image=k8s.gcr.io/e2e-test-images/agnhost:2.33 -- /agnhost serve-hostname
    ```
4. Deploy ArgoCD into your project

       cat <<EOF | oc apply -f -
       apiVersion: argoproj.io/v1alpha1
       kind: ArgoCD
       metadata:
         name: argocd
       spec:
         sso:
           dex:
             openShiftOAuth: true
             resources:
               limits:
                 cpu: 500m
                 memory: 256Mi
               requests:
                 cpu: 250m
                 memory: 128Mi
           provider: dex
         rbac:
           defaultPolicy: "role:readonly"
           policy: "g, system:authenticated, role:admin"
           scopes: "[groups]"
         server:
           insecure: true
           route:
             enabled: true
             tls:
               insecureEdgeTerminationPolicy: Redirect
               termination: edge
       EOF


    Sample Output
    ```tpl
    argocd.argoproj.io/argocd created
    ```
5. Wait for ArgoCD to be ready

        oc rollout status deploy/argocd-server -n bgd
    
    Sample Output
    ```tpl
    deployment "argocd-server" successfully rolled out
    ```
6. Apply the GitOps application for your application

       cat <<EOF | oc apply -f -
       apiVersion: argoproj.io/v1alpha1
       kind: Application
       metadata:
         name: bgd-app
         namespace: bgd
       spec:
         destination:
           namespace: bgd
           server: https://kubernetes.default.svc
         project: default
         source:
           path: apps/bgd/base
           repoURL: https://github.com/rh-mobb/gitops-bgd-app
           targetRevision: main
         syncPolicy:
           automated:
             prune: true
             selfHeal: false
           syncOptions:
           - CreateNamespace=false
       EOF


    Sample Output
    ```tpl
    application.argoproj.io/bgd-app created
    ```
7. Find the URL for your Argo CD dashboard, copy it to your web browser and log in using your OpenShift credentials (remind yourself what your password for user admin is by typing echo `$COGNITO_ADMIN_PASSWORD - {ssh_password}-2@23` if you accepted the default)

        oc get route argocd-server -n bgd -o jsonpath='{.spec.host}{"\n"}'
    
    Sample Output
    ```tpl
    argocd-server-bgd.apps.rosa-6n4s8.1c1c.p1.openshiftapps.com
    ```
8. Click on the Application to show its topology

9. Verify that OpenShift sees the Deployment as rolled out

        oc rollout status deploy/bgd

    Sample Output
    ```tpl
    deployment "bgd" successfully rolled out
    ```
10. Get the route and browse to it in your browser

        oc get route bgd -n bgd -o jsonpath='{.spec.host}{"\n"}'

    Sample Output
    ```tpl
    bgd-bgd.apps.rosa-6n4s8.1c1c.p1.openshiftapps.com
    ```
11. You should see a green box in the website

12. Patch the OpenShift resource to force it to be out of sync with the github repository. To do this we’re going to turn the tile blue by changing the deployed code directly. This means the value set in the deployed code ("blue") and the value in the repo ("green") are now different

        oc -n bgd patch deploy/bgd --type='json' \
            -p='[{"op": "replace", "path":
            "/spec/template/spec/containers/0/env/0/value", "value":"blue"}]'

    Sample Output
    ```tpl
    deployment.apps/bgd patched
    ```
13. Refresh Your browser and you should see a blue box in the website

14. Meanwhile check ArgoCD it should show the application as out of sync. Click the Sync button and then click on Synchronize to have it revert the change you made directly to the code deployed in OpenShift

15. Check again, you should see a green box in the website

Congratulations! You have successfully deployed OpenShift Gitops
