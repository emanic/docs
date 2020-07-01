---
title: For Aporeto-protected applications
type: single
url: "/next/setup/idp/app/"
weight: 30
menu:
  next:
    parent: "idp"
    identifier: "oidc-app"
canonical: https://docs.aporeto.com/saas/setup/idp/app/

---

## Before you begin

Before beginning the configuration, ensure the following.

- A Segment defender is installed on the host
- Segment recognizes the web application as a processing unit. (Check the **Platform** pane of the Segment Console web interface.)
- The web application accepts TCP connections.
- Review the tags of the processing unit representing the web application and locate one that identifies it uniquely.

Familiarize yourself with the following sequence, particularly the bolded URLs.
Hover over the numbers for additional details.

{{< svg file="oidc-auth-app.svg" >}}

In the examples below, we imagine a user with the email `bjoliet@email.com` trying to access a web application hosted at `example.com` that is represented by a processing unit called `hello-server`.


## Adding Segment to the identity provider

While OIDC is a standard, each identity provider provides a different web interface.
This section guides you through the setup at a high level.

NOTE: Many identity providers orient their offerings towards developers. 
Good news! 
With Segment, you won't need to write any code to integrate with the identity provider.

- **Web application**: Identity providers often support a variety of application types.
  If prompted, select web application.

- **Callback URL**: Sometimes referred to as a login redirect URI.
  Append `aporeto/oidc/callback` to the fully qualified domain name of your web application.
  For example, if users reach the application at `https://www.example.com`, the callback URL would be `https://www.example.com/aporeto/oidc/callback`

  - A domain name is required.
    If your web application does not have one, append `.xip.io` or `.nip.io` to its public IP address.
    Example: `https://35.193.206.162.xip.io`
  - Prefix the domain name with `https` even if the application does not currently use TLS.
    The Segment defender will manage the encryption.
  - If you want to expose the application on a port other than 443, specify the desired port.
    Example: `https://www.example.com:1443/aporeto/oidc/callback`

- **Client ID and client secret**: The identity provider supplies a client ID and a client secret value.
  These values allow Segment to communicate with the identity provider.
  You'll need them in subsequent procedures.

- **Scopes**: Though Segment sends the desired scopes in its request, some identity providers may ask you to identify the scopes during the configuration.
  If so, supply the scopes to the identity providers.

## Confirming the identity provider's discovery endpoint

The OIDC specification does not require a [discovery endpoint](https://openid.net/specs/openid-connect-discovery-1_0.html#IssuerDiscovery) but Segment does.
Most identity providers offer one.
Confirm that your identity provider supports it as follows.

1. Obtain the identity provider's URL. Your identity provider should make this value easy to obtain, but we provide some tips below.

    | Provider | Example | Discussion |
    | :------- | :------ | :--------- |
    | Auth0 | `https://dev-bzp6k6-2.auth0.com/` | -- |
    | Azure Active Directory | `https://sts.windows.net/cd629cb5-2826-4126-82fd-3f2df5f5bc7b/` | Append your [tenant ID](https://techcommunity.microsoft.com/t5/Office-365/How-do-you-find-the-tenant-ID/td-p/89018) to `https://sts.windows.net/` |
    | Google | `https://accounts.google.com` | All clients use the same path. |
    | Okta | `https://dev-289699.okta.com/oauth2/default` | The base URL is the same as the path in your browser when you access your account, without the `-admin` string. For example, if I access my Okta account at `https://dev-289699-admin.okta.com`, my base URL is `https://dev-289699.okta.com`. Append `/oauth2` to the base URL. Then append the ID of your authorization server. If you have an Okta developer account, the ID is probably `/default` |

1. Set an environment variable containing the identity provider's URL. An example follows. Replace `<identity-provider-url>` with the identity provider's URL before issuing the command.

    ```console
    export IDP_URL=<identity-provider-url>
    ```

1. Confirm that your identity provider supports the discovery endpoint by issuing the following command.

    ``` console
    curl $IDP_URL/.well-known/openid-configuration
    ```

    > TIP: If you don't have curl installed, try replacing `curl` with `wget`.

    It should return the JSON details of the OIDC configuration.



## Navigating to the namespace of the processing unit

1. Open the Segment Console web interface and toggle recursive mode **off**: ![recursive-off](/img/screenshots/recursive-off2.png)

1. Navigate to the namespace of the processing unit that represents the web server.
   Take a few moments to review its metadata.
   Determine the tag that you'd like to use to identify it later on.


## Allowing the processing unit to initiate connections with the identity provider

If you have not enabled host protection or if your network policies already allow the defender to initiate connections with the identity provider, skip to the [next section](#defining-the-http-resource).
Otherwise, complete the following steps.

1. Expand **Network Authorization**, select **External Networks**, and click the **Create** button.

1. Type the name of your identity provider in the **Name** field.
   You may also want to add a description and optionally propagate the external network to all children namespaces.

1. Click **Next**.

1. In the **Networks** tab, type the domain of your identity provider. If you completed the steps in [Confirming the identity provider's discovery endpoint](#confirming-the-identity-provider-s-discovery-endpoint), you can retrieve this value via `echo $IDP_URL`

1. Type `tcp` in the **Protocols** field, `443` in **Ports**, and click **Next**.

1. Type `ext:name=idp` in the **Tags** field and click **Create**.

1. Select **Network Policies** and click the **Create** button.

1. Type an informative name in the **Name** field, for example `allow-pu-to-connect-to-idp`.

1. Select **Outgoing traffic** from the **Network policy mode** list box.

1. Select **Propagate to child namespaces** and click **Next**.

1. Type or paste the tag that identifies the processing unit of the web application in **Source**, click **Next**, and click **Create**.

1. SSH into the processing unit and execute the commands from the previous section.

    ```console
    export IDP_URL=<identity-provider-url>
    curl $IDP_URL/.well-known/openid-configuration
    ```

1. Open the **Platform** pane of the Segment Console web interface and confirm that the traffic is allowed.
   An example view follows.

![connections-to-idp-allowed](/img/screenshots/oidc-app-idp-allowed.png)


## Defining the HTTP resource

1. Expand the **Service Authorization** section, open the **HTTP resource specs** pane, and click the **Create** button.

1. In the **General** tab, provide a name for the API exposed by the application.
   Example: `hello-server-resource`

1. Click **Next**.

1. In the **Endpoints** tab, click the **Add HTTP Resource** button.

1. Type the name of the resource that authorized users should be allowed to access. Examples:

    - `/*`: all resources
    - `/admin`: access to the `admin` resource

1. Deselect the buttons of any HTTP methods that you don't want to allow on the resource.

1. Select **Restricted Access** and specify the claims that must appear in the user's ID token using Segment's tag syntax.
   Some examples follow.

    | Identity provider | Scope requested | Example claim value | Segment tag |
    | :------------------------------- | :-------------- | :------------------ | :------------------------ |
    | all | `email` | `bjoliet@email.com` | `email=bjoliet@email.com` |
    | [Google](https://developers.google.com/identity/protocols/OpenIDConnect#hd-param) | `hd` | `example.com` | `hd=example.com` |

    > TIP: You can include multiple tags connected by AND or OR to form a logical expression.

1. Click **Next**.

1. In the **Tags** tab, provide a tag for this HTTP Resource definition. For example, `res:name=hello-server`

1. Click the **Create** button.

## Defining the service

1. Open the **HTTP Services** pane under **Service Authorization** and click the **Create** button.

1. In the **General** tab:

    - Provide a name for the app. Example: `hello-server-service`
    - Click **Next**.

1. In the **Access** tab:

    - **FQDN**: provide the DNS name of the application (required). Example: `example.com`. If the application does not have a domain name, append `.xip.io` or `.nip.io` to its public IP address. Example: `https://35.193.206.162.xip.io`

    - **Trusted CA**: select if you have a certificate signed by a trusted certificate authority (CA). Then provide the certificate to be used for TLS. Include any intermediate CAs in the certificate. Because the Segment defender may need to terminate TLS, it also needs the private key of the certificate. Both files must be in PEM format.

1. In the **Destination** tab:

    - **Processing unit selector**: add `$identity=processingunit` and press ENTER.
       Add `$type=Host` and press ENTER.
       Then type a tag that identifies the processing unit that represents the web application.

    - **Listening port**: the port that the actual application listens on, such as for connections from other services.
       For example, if the application is a container, the port that is open on the container.
       If the application is fronted by a load balancer, the port that the load balancer uses to connect to the application.
       Cannot be the same as the **Public Application Port**.

    - **Public Port**: the port that the Segment defender should listen on on behalf of the application. Typically 443. 
      It cannot be the same as the **Listening Port**.

    > WARNING: In Kubernetes/OpenShift deployments, ensure that the Kubernetes service in front of the container exposes the port specified in **Public Port**.
    > You can use the following command to view the service YAML: `kubectl edit svc/<your-service-name>`.
    > The value of `port` should be identical to the value in the **Public Application Port**.
    > If not, modify it to match and save your changes to update the Kubernetes service definition.


1. In the **Authorizations** tab:

    - **HTTP Resource Selector**: type the tag that you set in [Defining the HTTP resource](#defining-the-http-resource). 
      Example: `res:name=hello-server`

    - **Authorization type**: select **OpenID Connect**.

    - **OIDC Provider URL**: the URL of the identity provider. The Segment defender must be able to append `/.well-known/openid-configuration` to this URL and receive the JSON details of the OIDC configuration. If you completed the steps in [Confirming the identity provider's discovery endpoint](#confirming-the-identity-provider-s-discovery-endpoint), you can retrieve this value via `echo $IDP_URL`

    - **OAuth2 Client ID** and **OAuth2 Client Secret**: the client ID and client secret given to Segment by the identity provider.

    - **OIDC Callback URL**: the fully qualified domain name of the target application. Example: `https://www.example.com`. If you want to use a port other than 443, include the port. Example: `https://www.example.com:1443` Note that your external network must have the alternate port open, as well.

    - **Additional OIDC Scopes**: Type `openid` and press ENTER. Type the names of the additional scopes, pressing ENTER after each one. For example, if the identity provider supports refresh tokens and you would like to enable this feature, also include the `offline_access` scope. 

    > NOTE: Request only scopes that return claims as strings, arrays, or booleans. Segment ignores claims in other formats.

    - **Advanced** you can configure Segment to pass claims from the ID token to the target application via the HTTP header (optional).

1. In the **Tags** tab, type a tag that identifies this service. For example, `service:name=hello-server`.

1. Click the **Create** button.

## Logging in as a user to verify

1. Open a new browser tab or private window.

1. Type the path to the application. In the example above, we used `https://www.example.com`.

1. The OIDC provider should pop up a browser window or tab requesting your login credentials.

1. After authenticating to the OIDC provider, you should see the welcome page of the application.

1. Return to the **Platform** pane of the Segment Console web interface.

1. Click to view the details of the successful flow from the external network to the application, including the ID token, as shown below.

     ![Successful OIDC flow](/img/screenshots/oidc-app-success-3.11.gif)


