---
linktitle: Lab 9 - Deploy an application with AWS Database
title: Deploy an application with AWS Database
weight: 9
---

## Introduction

It’s time for us to put our cluster to work and deploy a workload! We’re going to build an example Java application, [microsweeper](https://github.com/redhat-mw-demos/microsweeper-quarkus/tree/ROSA), using [Quarkus](https://quarkus.io/) (a Kubernetes-native Java stack) and [Amazon DynamoDB](https://aws.amazon.com/dynamodb). We’ll then deploy the application to our ROSA cluster and connect to the database over AWS’s secure network.

This lab demonstrates how ROSA (an AWS native service) can easily and securely access and utilize other AWS native services using AWS Secure Token Service (STS). To achieve this, we will be using AWS IAM, Amazon DynamoDB, and a service account within OpenShift. After configuring the latter, we will use both Quarkus - a Kubernetes-native Java framework optimized for containers - and Source-to-Image (S2I) - a toolkit for building container images from source code - to deploy the microsweeper application.


## Create an Amazon DynamoDB Instance

1. First, let’s create a project (also known as a namespace). A project is a unit of organization within OpenShift that provides isolation for applications and resources. To do so, run the following command

        oc new-project microsweeper-ex
    
    Sample Output
    ```tpl
    Now using project "microsweeper-ex" on server "https://api.rosa-6n4s8.1c1c.p1.openshiftapps.com:6443".

    You can add applications to this project with the 'new-app' command. For example, try:

        oc new-app rails-postgresql-example

    to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:

        kubectl create deployment hello-node --image=k8s.gcr.io/e2e-test-images/agnhost:2.33 -- /agnhost serve-hostname
    ```
2. Next, create the Amazon DynamoDB table resource. Amazon DynamoDB will be used to store information from our application and ROSA will utilize AWS Secure Token Service (STS) to access this native service. More information on STS and how it is utilized in ROSA will be provided in the next section. For now let’s create the Amazon DynamoDB table, To do so, run the following command

        aws dynamodb create-table \
            --table-name microsweeper-scores-${GUID} \
            --attribute-definitions AttributeName=name,AttributeType=S \
            --key-schema AttributeName=name,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

    Sample Output
    ```tpl
        {
            "TableDescription": {
                "AttributeDefinitions": [
                    {
                        "AttributeName": "name",
                        "AttributeType": "S"
                    }
                ],
                "TableName": "microsweeper-scores-6n4s8",
                "KeySchema": [
                    {
                        "AttributeName": "name",
                        "KeyType": "HASH"
                    }
                ],
                "TableStatus": "CREATING",
                "CreationDateTime": 1681832377.864,
                "ProvisionedThroughput": {
                    "NumberOfDecreasesToday": 0,
                    "ReadCapacityUnits": 1,
                    "WriteCapacityUnits": 1
                },
                "TableSizeBytes": 0,
                "ItemCount": 0,
                "TableArn": "arn:aws:dynamodb:us-east-2:264091519843:table/microsweeper-scores-6n4s8",
                "TableId": "37be72fe-3dea-411c-871d-467c12607691"
            }
        }
    ```
## IAM Roles for Service Account (IRSA) Configuration
Our application uses AWS Secure Token Service(STS) to establish connections with Amazon DynamoDB. Traditionally, one would use static IAM credentials for this purpose, but this approach goes against AWS' recommended best practices. Instead, AWS suggests utilizing their Secure Token Service (STS). Fortunately, our ROSA cluster has already been deployed using AWS STS, making it effortless to adopt IAM Roles for Service Accounts (IRSA), also known as pod identity.

Service accounts play a crucial role in managing the permissions and access control of applications running within ROSA. They act as identities for pods and allow them to interact securely with various AWS services.

IAM roles, on the other hand, define a set of permissions that can be assumed by trusted entities within AWS. By associating an AWS IAM role with a service account, we enable the pods in our ROSA cluster to leverage the permissions defined within that role. This means that instead of relying on static IAM credentials, our application can obtain temporary security tokens from AWS STS by assuming the associated IAM role.

This approach aligns with AWS' recommended best practices and provides several benefits. Firstly, it enhances security by reducing the risk associated with long-lived static credentials. Secondly, it simplifies the management of access controls by leveraging IAM roles, which can be centrally managed and easily updated. Finally, it enables seamless integration with AWS services, such as DynamoDB, by granting the necessary permissions to the service accounts associated with our pods.

1. First, create a service account to use to assume an IAM role. To do so, run the following command

        oc -n microsweeper-ex create serviceaccount microsweeper

    Sample Output
    ```tpl
    serviceaccount/microsweeper created
    ```
2. Next, let’s create a trust policy document which will define what service account can assume our role. To create the trust policy document, run the following command

        cat <<EOF > ${HOME}/trust-policy.json
        {
        "Version": "2012-10-17",
        "Statement": [
            {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):oidc-provider/$(rosa describe cluster -c rosa-${GUID} -o json | jq -r .aws.sts.oidc_endpoint_url | sed -e 's/^https:\/\///')"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                "$(rosa describe cluster -c rosa-${GUID} -o json | jq -r .aws.sts.oidc_endpoint_url | sed -e 's/^https:\/\///'):sub": "system:serviceaccount:microsweeper-ex:microsweeper"
                }
            }
            }
        ]
        }
        EOF

3. Next, let’s take the trust policy document and use it to create a role. To do so, run the following command

        aws iam create-role --role-name irsa-${GUID} --assume-role-policy-document file://${HOME}/trust-policy.json --description "IRSA Role (${GUID}"

    Sample Output
    ```tpl
        {
            "Role": {
                "Path": "/",
                "RoleName": "irsa_6n4s8",
                "RoleId": "AROAT27IUZNRSSYVO24ET",
                "Arn": "arn:aws:iam::264091519843:role/irsa_6n4s8",
                "CreateDate": "2023-04-18T18:15:48Z",
                "AssumeRolePolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Principal": {
                                "Federated": "arn:aws:iam::264091519843:oidc-provider/rh-oidc.s3.us-east-1.amazonaws.com/235ftpmaq3oavfin8mt600af4sar9oej"
                            },
                            "Action": "sts:AssumeRoleWithWebIdentity",
                            "Condition": {
                                "StringEquals": {
                                    "rh-oidc.s3.us-east-1.amazonaws.com/235ftpmaq3oavfin8mt600af4sar9oej:sub": "system:serviceaccount:microsweeper-ex:microsweeper"
                                }
                            }
                        }
                    ]
                }
            }
        }
    ```
4. Next, let’s attach the `AmazonDynamoDBFullAccess` policy to our newly created IAM role. This will allow our application to read and write to our Amazon DynamoDB table. To do so, run the following command

        aws iam attach-role-policy --role-name irsa-${GUID} --policy-arn=arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

5. Finally, let’s annotate the service account with the ARN of the IAM role we created above. To do so, run the following command

        oc -n microsweeper-ex annotate serviceaccount microsweeper eks.amazonaws.com/role-arn=arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):role/irsa-${GUID}

    Sample Output
    ```tpl
    serviceaccount/microsweeper annotated
    ```
## Build and Deploy the Microsweeper app

Now that we’ve got a DynamoDB instance up and running and our IRSA configuration completed, let’s build and deploy our application.

1. In order to build the application you will need the Java JDK 17 and the Quarkus CLI installed. Java JDK 17 is already installed on your bastion VM so let’s install the Quarkus CLI

        curl -Ls https://sh.jbang.dev | bash -s - trust add https://repo1.maven.org/maven2/io/quarkus/quarkus-cli/
        curl -Ls https://sh.jbang.dev | bash -s - app install --fresh --force quarkus@quarkusio

        echo "export JAVA_HOME=/usr/lib/jvm/jre-17-openjdk" >>${HOME}/.bashrc
        echo "export PATH=\$JAVA_HOME/bin:\$PATH" >>${HOME}/.bashrc

        source ${HOME}/.bashrc

2. Double check the Quarkus CLI version

        quarkus --version

    Sample Output
    ```tpl
    3.7.2
    ```
3. Now, let’s clone the application from GitHub. To do so, run the following command

        cd ${HOME}

        git clone https://github.com/rh-mobb/rosa-workshop-app.git

4. Next, let’s change directory into the newly cloned Git repository. To do so, run the following command

        cd ${HOME}/rosa-workshop-app

5. Next, we will add the OpenShift extension to the Quarkus CLI. To do so, run the following command

        quarkus ext add openshift

    Sample Output
    ```tpl
    Looking for the newly published extensions in registry.quarkus.io
    👍  Extension io.quarkus:quarkus-openshift was already installed
    ```    
6. Now, we’ll configure Quarkus to use the DynamoDB instance that we created earlier in this section. To do so, we’ll create an `application.properties` file using by running the following command:

        cat <<EOF > ${HOME}/rosa-workshop-app/src/main/resources/application.properties
        # AWS DynamoDB configurations
        %dev.quarkus.dynamodb.endpoint-override=http://localhost:8000
        %prod.quarkus.openshift.env.vars.aws_region=$(aws configure get region)
        %prod.quarkus.dynamodb.aws.credentials.type=default
        dynamodb.table=microsweeper-scores-${GUID}

        # OpenShift configurations
        %prod.quarkus.kubernetes-client.trust-certs=true
        %prod.quarkus.kubernetes.deploy=true
        %prod.quarkus.kubernetes.deployment-target=openshift
        %prod.quarkus.openshift.build-strategy=docker
        %prod.quarkus.openshift.route.expose=true
        %prod.quarkus.openshift.service-account=microsweeper

        # To make Quarkus use Deployment instead of DeploymentConfig
        %prod.quarkus.openshift.deployment-kind=Deployment
        %prod.quarkus.container-image.group=microsweeper-ex
        EOF

7. Now that we’ve provided the proper configuration, we will build our application. We’ll do this using [source-to-image](https://github.com/openshift/source-to-image), a tool built-in to OpenShift. To start the build and deploy, run the following command:

        quarkus build --no-tests

    Sample Output
    ```tpl
        [...Lots of Output Omitted...]
        [INFO] Installing /home/rosa/rosa-workshop-app/target/microsweeper-appservice-1.0.0-SNAPSHOT.jar to /home/rosa/.m2/repository/org/acme/microsweeper-appservice/1.0.0-SNAPSHOT/microsweeper-appservice-1.0.0-SNAPSHOT.jar
        [INFO] Installing /home/rosa/rosa-workshop-app/pom.xml to /home/rosa/.m2/repository/org/acme/microsweeper-appservice/1.0.0-SNAPSHOT/microsweeper-appservice-1.0.0-SNAPSHOT.pom
        [INFO] ------------------------------------------------------------------------
        [INFO] BUILD SUCCESS
        [INFO] ------------------------------------------------------------------------
        [INFO] Total time: 02:02 min
        [INFO] Finished at: 2023-04-18T18:32:26Z
        [INFO] ------------------------------------------------------------------------
    ```
## Test the application

In the route section of the OpenShift Web Console, click the URL under Location. 

You can also get the the URL for your application using the command line:

        echo "http://$(oc -n microsweeper-ex get route microsweeper-appservice -o jsonpath='{.spec.host}')"

Sample Output

        http://microsweeper-appservice-microsweeper-ex.apps.rosa-6n4s8.1c1c.p1.openshiftapps.com


Warning: This is an http URL. Some browsers (Chrome) replace http with https automatically which will result in a application not available error. Either use another browser or fix the URL manually in the URL bar.


## Application IP

Let’s take a quick look at what IP the application resolves to.

Back in your bastion VM, run the following command:

        nslookup $(oc -n microsweeper-ex get route microsweeper-appservice -o jsonpath='{.spec.host}')

Sample Output
```tpl
Server:		192.168.0.2
Address:	192.168.0.2#53

Non-authoritative answer:
Name:	microsweeper-appservice-microsweeper-ex.apps.rosa-6n4s8.1c1c.p1.openshiftapps.com
Address: 54.185.165.99
Name:	microsweeper-appservice-microsweeper-ex.apps.rosa-6n4s8.1c1c.p1.openshiftapps.com
Address: 54.191.151.187
```
Notice the IP address; can you guess where it comes from?

It comes from the ROSA Load Balancer. In this workshop, we are using a public cluster which means the load balancer is exposed to the Internet. If this was a private cluster, you would have to have connectivity to the VPC ROSA is running on. This could be via a VPN connection, AWS DirectConnect, or something else.

## Summary

Here you learned:

* Create an AWS DynamoDB table for your application to use

* Create a service account and AWS IAM resources to use IAM Roles for Service Accounts (IRSA).

* Deploy the Microsweeper app and connect it to AWS DynamoDB as the backend database

* Access the publicly exposed Microsweeper app using OpenShift routes.

