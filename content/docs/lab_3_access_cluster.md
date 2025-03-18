---
linktitle: Lab 3 - Access ROSA HCP Cluster
title: Access ROSA HCP Cluster
weight: 3
---

## Create a Local Admin User for Cluster Access 
You can use built-in authentication to access your cluster immediately. This is done through the creation of a local privileged user.

ROSA makes this easy by providing a command to create a user, called `cluster-admin`, which has powerful cluster administration capabilities.

For production deployments, however, the recommended approach is to use an external identity provider to access the cluster. We will take you through an example of that in a later lab.


1. Run this command to create the local admin user

        rosa create admin --cluster rosa-${GUID}

   Sample Output
   ```tpl
   I: Admin account has been added to cluster 'rosa-4fgbq'.
   I: Please securely store this generated password. If you lose this password you can delete and recreate the cluster admin user.
   I: To login, run the following command:

   oc login https://api.rosa-4fgbq.qrdf.p1.openshiftapps.com:6443 --username cluster-admin --password [clusteradminpassword]

   I: It may take up to 5 minutes for the account to become active.
   ```
   Save the login command somewhere. Also take note of the password for your cluster-admin user.

   Make sure to use the entire password when copying and pasting the command!      

2. Save an environment variable for your admin password (copy the password from above making sure to copy the entire password):

   Note this box will not automatically copy the command for you. You need to write the command yourself using the password from your environment.

        export ADMIN_PASSWORD=[clusteradminpassword]

   Save the admin password in your `.bashrc`

        echo "export ADMIN_PASSWORD=$ADMIN_PASSWORD" >>$HOME/.bashrc

3. Copy the login command returned to you in the previous step and paste that into your terminal. This should log you into the cluster via the CLI so you can start using the cluster (answer `y` when prompted if you want to accept the certificate).

        oc login https://api.rosa-4fgbq.qrdf.p1.openshiftapps.com:6443 --username cluster-admin --password [clusteradminpassword]

   Sample Output
   ```tpl
   The server uses a certificate signed by an unknown authority.
   You can bypass the certificate check, but any data you send to the server could be intercepted by others.
   Use insecure connections? (y/n): y

   WARNING: Using insecure TLS client config. Setting this option is not supported!

   Login successful.

   You have access to 100 projects, the list has been suppressed. You can list all projects with 'oc projects'

   Using project "default".
   Welcome! See 'oc help' to get started.
   ```

   If you get an error that the Login failed (401 Unauthorized) wait a few seconds and then try again. It takes a few minutes for the cluster authentication operator to update itself after creating the cluster-admin user.


4. To check that you are logged in as the admin user you can run `oc whoami`

        oc whoami

   Sample Output
   ```tpl
   cluster-admin
   ```
5. You can also confirm by running the following command. Only a cluster-admin user can run this without errors.

        oc get pod -n openshift-ingress

   Sample Output
   ```tpl
   NAME                              READY   STATUS    RESTARTS   AGE
   router-default-7994f6fd58-8cl45   1/1     Running   0          102s
   router-default-7994f6fd58-z6gpm   1/1     Running   0          102s
   ```

6. You can now access the cluster with this local admin user. Though, for production use, it is highly recommended to set up an external identity provider.

## Login to the OpenShift Web Console 

Next, let’s log in to the OpenShift Web Console. To do so, follow the below steps:

1. First, we’ll need to grab your cluster’s web console URL. To do so, run the following command:

        oc whoami --show-console

    Sample Output
    ```tpl
    https://console-openshift-console.apps.rosa-z8ssd.ls3a.p1.openshiftapps.com/
    ```

2. Next, open the printed URL in a web browser

3. Click on the `cluster-admin` identity provider.

4. Enter the username (`cluster-admin`) and password from the previous section (use `echo $ADMIN_PASSWORD` to remind yourself what the password is in case you forgot).

Congratulations! You’re now logged into the cluster and ready to move on to the workshop content.
