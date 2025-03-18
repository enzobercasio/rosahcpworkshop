---
linktitle: Lab 1 - Explore the environment
title: Explore the environment
weight: 1
---

## The Workshop Environment You Are Using
Your environment has already been set up and with the tools you need to work with ROSA and AWS.

Your workshop environment consists of several components which have been pre-configured and are ready to use. This includes an Amazon Web Services (AWS) account, and many other supporting resources.

ROSA is enabled on the AWS account used for this lab - and the ROSA CLI as well as AWS CLI tools are installed and configured on your bastion VM.

### Validate installed tools

You will be using the `rosa`, `aws` and `oc` command line tools throughout this lab.

1. Verify that the `rosa` command line tool is installed (note that your version may be a more recent version than the output shown below):

        rosa version
          
   Sample Output 
   ```tpl
   1.2.37
   Your ROSA CLI is up to date.
   ```

2. Verify that the `aws` command line tool is installed:

        aws --version

    Sample Output
    ```tpl
    aws-cli/2.15.39 Python/3.11.8 Linux/5.14.0-362.18.1.el9_3.x86_64 exe/x86_64.rhel.9 prompt/off
    ```

3. Verify that the `aws` command line tool is configured correctly:

        aws sts get-caller-identity

    Sample Output
    ```tpl
    {
        "UserId": "AIDA52VPS74UJLY4GUW7L",
        "Account": "950629760808",
        "Arn": "arn:aws:iam::950629760808:user/wkulhane@redhat.com-nhnv4"
    }
    ```
4. Verify that the `oc` CLI is installed correctly

        rosa verify openshift-client

    Sample Output
    ```tpl
    I: Verifying whether OpenShift command-line tool is available...
    I: Current OpenShift Client Version: 4.15.9
    ```

5. Rosa Login

        rosa login

   Sample Output

        I: Logged in as 'rhpds-cloud' on 'https://api.openshift.com'


   
   Note: Normally you would need to get a token from the [Red Hat Console](https://console.redhat.com/openshift/token/rosa) and log into ROSA using that token.
   

In this environment your token has been preconfigured for you.

6. Run `rosa whoami` to verify your credentials:

        rosa whoami

   Sample Output 
   ```tpl
   AWS ARN:                      arn:aws:iam::950629760808:user/wkulhane@redhat.com-nhnv4
   AWS Account ID:               950629760808
   AWS Default Region:           us-east-2
   OCM API:                      https://api.openshift.com
   OCM Account Email:            rhpds-admins+cloud@redhat.com
   OCM Account ID:               1z8a-------------------HD9l
   OCM Account Name:             RHPDS Cloud
   OCM Account Username:         rhpds-cloud
   OCM Organization External ID: 1234567890
   OCM Organization ID:          1z8-------------------0ZL
   OCM Organization Name:        Red Hat, Inc.
   ```
### Review Quota

1. You must ensure your AWS account has enough resources available to run ROSA. Use the following command to review available AWS quota:

        rosa verify quota

   Sample Output
   ```tpl
   I: Validating AWS quota...
   I: AWS quota ok. If cluster installation fails, validate actual AWS resource usage against https://docs.openshift.com/
   rosa/rosa_getting_started/rosa-required-aws-service-quotas.html
   ```
  See the [documentation](https://docs.openshift.com/rosa/rosa_planning/rosa-sts-required-aws-service-quotas.html) for more details regarding quotas.

  You have now successfully reviewed your account and environment and are ready to work with ROSA and AWS.