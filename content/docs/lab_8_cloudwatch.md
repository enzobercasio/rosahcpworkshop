---
linktitle: Lab 8 - Configure Red Hat OpenShift Logging with AWS Cloudwatch
title: Configure Red Hat OpenShift Logging with AWS Cloudwatch
weight: 8
---

## Introduction

Red Hat OpenShift Service on AWS (ROSA) clusters store log data inside the cluster by default. Understanding metrics and logs is critical in successfully running your cluster. Included with ROSA is the OpenShift Cluster Logging Operator, which is intended to simplify log management and analysis within a ROSA cluster, offering centralized log collection, powerful search capabilities, visualization tools, and integration with other monitoring systems like [Amazon CloudWatch](https://aws.amazon.com/cloudwatch/).

Amazon CloudWatch is a monitoring and observability service provided by Amazon Web Services. It allows you to collect, store, analyze and visualize logs, metrics and events from various AWS resources and applications. Since ROSA is a first party AWS service, it integrates with Amazon CloudWatch and forwards its infrastructure, audit and application logs to Amazon CloudWatch.

In this section of the workshop, we’ll configure ROSA to forward logs to Amazon CloudWatch.


## Prepare Amazon CloudWatch


1. First, let’s set some helper variables that we’ll need throughout this section of the workshop. To do so, run the following command

       export OIDC_ENDPOINT=$(oc get authentication.config.openshift.io \
        cluster -o json | jq -r .spec.serviceAccountIssuer | \
        sed  's|^https://||')

       export AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
        --query Account --output text)

       echo OIDC_Endpoint: ${OIDC_ENDPOINT}, AWS Account ID: ${AWS_ACCOUNT_ID}
    
   Sample Output
    ```tpl
    OIDC_Endpoint: rh-oidc.s3.us-east-1.amazonaws.com/235ftpmaq3oavfin8mt600af4sar9oej, AWS Account ID: 264091519843
    ```

2.  Validate that a policy `RosaCloudWatch` already exists and if it does not create it

        POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='RosaCloudWatch'].{ARN:Arn}" --output text)

        if [[ -z "${POLICY_ARN}" ]]; then
        cat << EOF > ${HOME}/policy.json
        {
        "Version": "2012-10-17",
        "Statement": [
        {
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams",
                    "logs:PutLogEvents",
                    "logs:PutRetentionPolicy"
                ],
                "Resource": "arn:aws:logs:*:*:*"
        }
        ]
        }
        EOF

        POLICY_ARN=$(aws iam create-policy --policy-name "RosaCloudWatch" \
        --policy-document file:///${HOME}/policy.json --query Policy.Arn --output text)
        fi

        echo ${POLICY_ARN}

    Sample Output
    ```tpl
    arn:aws:iam::588550307242:policy/RosaCloudWatch
    ```

3. Next, let’s create a trust policy document which will define what service account can assume our role. To create the trust policy document, run the following command

       cat <<EOF > ${HOME}/cloudwatch-trust-policy.json
       {
         "Version": "2012-10-17",
         "Statement": [{
           "Effect": "Allow",
           "Principal": {
           "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_ENDPOINT}"
           },
           "Action": "sts:AssumeRoleWithWebIdentity",
           "Condition": {
             "StringEquals": {
               "${OIDC_ENDPOINT}:sub": "system:serviceaccount:openshift-logging:logcollector"
             }
           }
         }]
       }
       EOF

4. Next, let’s take the trust policy document and use it to create a role. To do so, run the following command

        ROLE_ARN=$(aws iam create-role --role-name "RosaCloudWatch-${GUID}" \
        --assume-role-policy-document file://${HOME}/cloudwatch-trust-policy.json \
        --tags "Key=rosa-workshop,Value=true" \
        --query Role.Arn --output text)

        echo ${ROLE_ARN}

    Sample Output
    ```tpl
    arn:aws:iam::264091519843:role/RosaCloudWatch-6n4s8
    ```

5. Now, let’s attach the pre-created RosaCloudWatch IAM policy to the newly created IAM role.

        aws iam attach-role-policy \
        --role-name "RosaCloudWatch-${GUID}" \
        --policy-arn "${POLICY_ARN}"

## Configure Cluster Logging 

The CLO (Cluster Logging Operator) provides a set of APIs to control collection and forwarding of logs from all pods and nodes in a cluster. This includes application logs (from regular pods), infrastructure logs (from system pods and node logs), and audit logs (special node logs with legal/security implications). In this section we will install cluster logging operator on the ROSA cluster and configure it to forward logs to Amazon CloudWatch.

1. Now, we need to deploy the OpenShift Cluster Logging Operator. We’ll need a Namespace, an OperatorGroup, and a Subscription. To do so, run the following command

       cat << EOF | oc apply -f -
       apiVersion: v1
       kind: Namespace
       metadata:
         name: openshift-logging
         annotations:
           openshift.io/node-selector: ""
         labels:
           openshift.io/cluster-monitoring: "true"
       ---
       apiVersion: operators.coreos.com/v1
       kind: OperatorGroup
       metadata:
         name: cluster-logging
         namespace: openshift-logging
       spec:
         targetNamespaces:
         - openshift-logging
       ---
       apiVersion: operators.coreos.com/v1alpha1
       kind: Subscription
       metadata:
         labels:
           operators.coreos.com/cluster-logging.openshift-logging: ""
         name: cluster-logging
         namespace: openshift-logging
       spec:
         channel: stable
         installPlanApproval: Automatic
         name: cluster-logging
         source: redhat-operators
         sourceNamespace: openshift-marketplace
       EOF

    Sample Output
    ```tpl
    namespace/openshift-logging configured
    operatorgroup.operators.coreos.com/cluster-logging created
    subscription.operators.coreos.com/cluster-logging created
    ```
2. Now, we will wait for the OpenShift Cluster Logging Operator to install. To do so, we can run the following command to watch the status of the installation

        oc -n openshift-logging rollout status deployment \
            cluster-logging-operator


    After a minute or two, your output should look something like this: 

      ```tpl
        deployment "cluster-logging-operator" successfully rolled out
      ```
    
    
    Note: If you get an error Error from server (NotFound): deployments.apps "cluster-logging-operator" not found wait a few seconds and try again.
    

3. Next, we need to create a secret containing the ARN of the IAM role that we previously created above. To do so, run the following command

       cat << EOF | oc apply -f -
       ---
       apiVersion: v1
       kind: Secret
       metadata:
         name: cloudwatch-credentials
         namespace: openshift-logging
       stringData:
         role_arn: ${ROLE_ARN}
       EOF

    Sample Output
    ```tpl
    secret/cloudwatch-credentials created
    ```
4. Next, let’s configure the OpenShift Cluster Logging Operator by creating a Cluster Log Forwarding custom resource that will forward logs to Amazon CloudWatch. To do so, run the following command

       cat << EOF | oc apply -f -
       apiVersion: "logging.openshift.io/v1"
       kind: ClusterLogForwarder
       metadata:
         name: instance
         namespace: openshift-logging
       spec:
         outputs:
           - name: cw
             type: cloudwatch
             cloudwatch:
               groupBy: namespaceName
               groupPrefix: rosa-${WS_USER/_/-}
               region: ${AWS_DEFAULT_REGION}
             secret:
               name: cloudwatch-credentials
         pipelines:
            - name: to-cloudwatch
              inputRefs:
                - infrastructure
                - audit
                - application
              outputRefs:
                - cw
       EOF


    Sample Output
    ```tpl
    clusterlogforwarder.logging.openshift.io/instance created
    ```
5. Next, let’s create a Cluster Logging custom resource which will enable the OpenShift Cluster Logging Operator to start collecting logs.

       cat << EOF | oc apply -f -
       ---
       apiVersion: logging.openshift.io/v1
       kind: ClusterLogging
       metadata:
         name: instance
         namespace: openshift-logging
       spec:
         collection:
           logs:
             type: fluentd
         forwarder:
           fluentd: {}
       managementState: Managed
       EOF

    Sample Output
    ```tpl
    clusterlogging.logging.openshift.io/instance created
    ```
6. After a few minutes, you should begin to see log groups inside of Amazon CloudWatch

        aws logs describe-log-groups \
            --log-group-name-prefix rosa-${GUID}

    Sample Output
    ```tpl
        {
            "logGroups": [
                {
                    "logGroupName": "rosa-fxxj9.audit",
                    "creationTime": 1682098364311,
                    "metricFilterCount": 0,
                    "arn": "arn:aws:logs:us-east-2:511846242393:log-group:rosa-fxxj9.audit:*",
                    "storedBytes": 0
                },
                {
                    "logGroupName": "rosa-fxxj9.infrastructure",
                    "creationTime": 1682098364399,
                    "metricFilterCount": 0,
                    "arn": "arn:aws:logs:us-east-2:511846242393:log-group:rosa-fxxj9.infrastructure:*",
                    "storedBytes": 0
                }
            ]
        }
    ```
Congratulations!

You’ve successfully forwarded your cluster’s logs to the Amazon CloudWatch service.


## Summary

Here you learned:

* Create an AWS IAM trust policy and role to grant your cluster access to Amazon CloudWatch

* Install the OpenShift Cluster Logging Operator in your cluster

* Configure ClusterLogForwarder and ClusterLogging objects to forward infrastructure, audit and application logs to Amazon CloudWatch

