---
linktitle: Lab 2 - Create a ROSA HCP Cluster
title: Deploy your cluster using a Hosted Control Plane
weight: 2
---

## Deploy your cluster using a Hosted Control Plane
In this section we will deploy a ROSA cluster using Hosted Control Plane (HCP).

In short, with ROSA HCP you can decouple the control plane from the data plane (workers). This is a new deployment model for ROSA in which the control plane is hosted in a Red Hat owned AWS account. Therefore the control plane is no longer hosted in your AWS account thus reducing your AWS infrastructure expenses. The control plane is dedicated to each cluster and is highly available. See the documentation for more about [Hosted Control Planes](https://docs.openshift.com/container-platform/4.15/architecture/control-plane.html#hosted-control-planes-overview_control-plane).

## Prerequisites

ROSA HCP requires a few things to be created before deploying the cluster:

1. ELB service role

2. VPC - This is a "bring-your-own VPC" model (also referred to as BYO-VPC)

3. OIDC configuration (and an OIDC provider with that specific configuration)

Let’s create those first.

#### Ensure ELB service role exists

Run the following to check for the role and create it if it is missing.

        aws iam get-role --role-name "AWSServiceRoleForElasticLoadBalancing" || aws iam create-service-linked-role --aws-service-name "elasticloadbalancing.amazonaws.com"

#### VPC

1. Set a few environment variables for your networking configuration:

         export VPC_CIDR=10.0.0.0/16
         export PUBLIC_CIDR_SUBNET=10.0.1.0/24
         export PRIVATE_CIDR_SUBNET=10.0.0.0/24
         export CLUSTER_NAME=rosa-${GUID}

   and save them in your .bashrc

         echo "export VPC_CIDR=$VPC_CIDR" >>$HOME/.bashrc
         echo "export PUBLIC_CIDR_SUBNET=$PUBLIC_CIDR_SUBNET" >>$HOME/.bashrc
         echo "export PRIVATE_CIDR_SUBNET=$PRIVATE_CIDR_SUBNET" >>$HOME/.bashrc
         echo "export CLUSTER_NAME=$CLUSTER_NAME" >>$HOME/.bashrc

2. Create the VPC

          export VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query Vpc.VpcId --output text)
          
          echo "export VPC_ID=$VPC_ID" >>$HOME/.bashrc

3. Create Tags

          aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$CLUSTER_NAME

4. Enable DNS Hostname

          aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

5. Now you can create the public subnet and add tags

          export PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUBLIC_CIDR_SUBNET --query Subnet.SubnetId --output text)

          echo "export PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID" >>$HOME/.bashrc

          aws ec2 create-tags --resources $PUBLIC_SUBNET_ID --tags Key=Name,Value=$CLUSTER_NAME-public

6. Create the private subnet and add tags

          export PRIVATE_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIVATE_CIDR_SUBNET --query Subnet.SubnetId --output text)

          echo "export PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID" >>$HOME/.bashrc

          aws ec2 create-tags --resources $PRIVATE_SUBNET_ID --tags Key=Name,Value=$CLUSTER_NAME-private

7. Create an internet gateway for outbound traffic and attach it to the VPC

          export IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)

          echo "export IGW_ID=$IGW_ID" >>$HOME/.bashrc

          aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$CLUSTER_NAME

          aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

8. Create a route table for outbound traffic and associate it to the public subnet.

          export PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text)

          echo "export PUBLIC_ROUTE_TABLE_ID=$PUBLIC_ROUTE_TABLE_ID" >>$HOME/.bashrc

          aws ec2 create-tags --resources $PUBLIC_ROUTE_TABLE_ID --tags Key=Name,Value=$CLUSTER_NAME

          aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

          aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID --route-table-id $PUBLIC_ROUTE_TABLE_ID

9. Create a NAT gateway in the public subnet for outgoing traffic from the private network.

          export NAT_IP_ADDRESS=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)

          echo "export NAT_IP_ADDRESS=$NAT_IP_ADDRESS" >>$HOME/.bashrc

          export NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_ID --allocation-id $NAT_IP_ADDRESS --query NatGateway.NatGatewayId --output text)

          echo "export NAT_GATEWAY_ID=$NAT_GATEWAY_ID" >>$HOME/.bashrc

          aws ec2 create-tags --resources $NAT_IP_ADDRESS --resources $NAT_GATEWAY_ID --tags Key=Name,Value=$CLUSTER_NAME

10. Wait 10 seconds for the NAT gateway to be ready then create a route table for the private subnet to the NAT gateway.

          sleep 10

          export PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text)

          echo "export PRIVATE_ROUTE_TABLE_ID=$PRIVATE_ROUTE_TABLE_ID" >>$HOME/.bashrc

          aws ec2 create-tags --resources $PRIVATE_ROUTE_TABLE_ID $NAT_IP_ADDRESS --tags Key=Name,Value=$CLUSTER_NAME-private

          aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GATEWAY_ID

          aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_ID --route-table-id $PRIVATE_ROUTE_TABLE_ID

     See the [documentation](https://docs.openshift.com/rosa/rosa_planning/rosa-sts-aws-prereqs.html#rosa-vpc_rosa-sts-aws-prereqs) for more about VPC requirements.

  11. Confirm that the environment variables that you need to create the cluster are, in fact, set.

          echo "Public Subnet: $PUBLIC_SUBNET_ID"; echo "Private Subnet: $PRIVATE_SUBNET_ID"

      Sample Output
      ```tpl
      Public Subnet: subnet-0faeeeb0000000000
      Private Subnet: subnet-011fe340000000000
      ```

      
      Warning: If one or both are blank, do not proceed and ask for assistance.
      

#### OIDC Configuration

To create the OIDC configuration to be used for your cluster in this workshop, run the following command. We are opting for the automatic creation mode and Red Hat managed, as this is simpler for the workshop purposes. We are going to store the generated OIDC ID to an environment variable for later use. Notice that the following command uses the ROSA CLI to create your cluster’s unique OIDC configuration.

      export OIDC_ID=$(rosa create oidc-config --mode auto --managed --yes -o json | jq -r '.id'); echo $OIDC_ID;

      echo "export OIDC_ID=$OIDC_ID" >>$HOME/.bashrc

Sample Output
```tpl
23o3doeo86adgqhci4jl000000000000
```

## Create the Cluster 

As this is the first time you are deploying ROSA in this account and have not yet created the account roles, create the account-wide roles with policies, and Operator roles with policies. Since ROSA makes use of AWS Security Token Service (STS), this step creates the AWS IAM roles and policies that are needed for ROSA to interact within your account. See [Account-wide IAM role and policy reference](https://docs.openshift.com/rosa/rosa_architecture/rosa-sts-about-iam-resources.html#rosa-sts-account-wide-roles-and-policies_rosa-sts-about-iam-resources) for more details if you are interested.

1. Run the following command to create the account-wide roles

          rosa create account-roles --mode auto --yes

2. Run the following command to create the cluster

          rosa create cluster --cluster-name rosa-${GUID} \
            --subnet-ids ${PUBLIC_SUBNET_ID},${PRIVATE_SUBNET_ID} \
            --hosted-cp \
            --version 4.15.34 \
            --oidc-config-id $OIDC_ID \
            --sts --mode auto --yes

   In about 10 minutes the control plane and API will be up, and about 5-10 minutes after, the worker nodes will be up and the cluster will be completely usable. This cluster will have a control plane across three AWS availability zones in your selected region, in a Red Hat AWS account and will also create 2 worker nodes in your AWS account.


## Check installation status

1. You can run the following command to check the detailed status of the cluster

          rosa describe cluster --cluster rosa-${GUID}

   or, you can also watch the logs as it progresses

          rosa logs install --cluster rosa-${GUID} --watch

2. Once the state changes to “ready” your cluster is now installed. It may take a few more minutes for the worker nodes to come online. In total this should take about 15 minutes.

You can continue this lab - there is a step in the next section where you will need to wait for the cluster operators to finish rolling out - but there is no need to wait at this point.