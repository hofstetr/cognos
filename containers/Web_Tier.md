## Web Tier
Since Apache is open source and free, using an Apache container makes a lot of sense for my web tier. There are several ways to setup a web server for use with Cognos Analytics but the best is to utilize the optional gateway installation along with several customizations to the Apache configuration. Doing so offloads a lot of the static content processing from the application tier.

## Installation
I prefer to perform the installation on a bastion host rather than inside the container at startup. This reduces the container startup time. Normal startup time for IBM Cognos Analytics can range from 5 minutes on up to 15 minutes depending on a number of factors including: content store initialization, number of authentication sources to connect to and latency with all the dependencies. Adding to that an installation step could add another several precious minutes. Doing so also allows for the pre-configuration of common settings that would not change across containers.

1. 

## Pre-Configuration
Several configuration changes can be applied prior to building the image in order to simplify the actual container startup. Settings like authentication source and content store connections will not change each time the data tier service is created in a swarm. In this example, I plan to use Google Identity Platform as an authentication source via OpenID Connect integration.

1. Change the host in Content Manager URIs to the name of the data tier service (ie. content-manager)
2. Change the configuration group to match
3. Change the configuration group contact host to the name of the data tier service (ie. content-manager)
4. Save and Export the configuration to cogstartup.xml.tmpl and exit (Note: it will complain about not being able to connect to content-manager at this time so just save as plain text)
5. Remove the following files to maintain as small a footprint as possible for the image and to help avoid confusion in the event that template processing fails:
    1. temp/*
    2. data/*
    3. logs/*
    4. configuration/certs/CAM*
    5. configuration/cogstartup.xml

## Build Image
First, pull the image

```bash
$ docker pull httpd
```

For the next step I need copies of several configuration files in order to customize them. There is more than one way to obtain the copies but for now I am going to run a few temporary containers and fetch the existing configuration files from them.

```bash
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/httpd.conf > my-httpd.conf
$ docker run --rm httpd:2.4 cat /usr/local/apache2/conf/extra/httpd-ssl.conf > httpd-ssl.conf
```

Edit the my-httpd.conf and uncomment the following modules along with the SSL configuration:

```text
LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
LoadModule ssl_module modules/mod_ssl.so
LoadModule rewrite_module modules/mod_rewrite.so
LoadModule expires_module modules/mod_expires.so
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
LoadModule deflate_module modules/mod_deflate.so
LoadModule slotmem_shm_module modules/mod_slotmem_shm.so
LoadModule slotmem_plain_module modules/mod_slotmem_plain.so
LoadModule lbmethod_byrequests_module modules/mod_lbmethod_byrequests.so
Include conf/extra/httpd-ssl.conf
```
Next, I need to obtain a valid key and certificate for the purpose of running a web site. For now I'm just going to generate a self signed pair and live with the browser warning.

```bash
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout web/server.key -out web/server.crt
```

Note: I will regenerate this key pair and enter my alias for the common name once it is known.

Now, add the Cognos Analytics configuration items from the provided template to the end of httpd-sso.conf just before the closing virtual host.

```text
<IfModule mod_expires.c>
        <FilesMatch "\.(jpe?g|png|gif|js|css|json|html|woff2?|template)$">
                ExpiresActive On
                ExpiresDefault "access plus 1 day"
        </FilesMatch>
</IfModule>

<Directory /opt/ibm/cognos/analytics/web>
        <IfModule mod_deflate>
                AddOutputFilterByType DEFLATE text/html application/json text/css application/javascript
        </IfModule>
        Options Indexes MultiViews
        AllowOverride None
        Require all granted
</Directory>

<Proxy balancer://mycluster>
        BalancerMember http://application-tier:9300 route=1
</Proxy>

Alias /ibmcognos /opt/ibm/cognos/analytics/web/webcontent
RewriteEngine On
# Send default URL to service
RewriteRule ^/ibmcognos/bi/($|[^/.]+(\.jsp)(.*)?) balancer://mycluster/bi/$1$3 [P]
RewriteRule ^/ibmcognos/bi/(login(.*)?) balancer://mycluster/bi/$1 [P]

# Rewrite Event Studio static references
RewriteCond %{HTTP_REFERER} v1/disp [NC,OR]
RewriteCond %{HTTP_REFERER} (ags|cr1|prompting|ccl|common|skins|ps|cps4)/(.*)\.css [NC]
RewriteRule ^/ibmcognos/bi/(ags|cr1|prompting|ccl|common|skins|ps|cps4)/(.*) /ibmcognos/$1/$2 [PT,L]

# Rewrite Saved-Output and Viewer static references
RewriteRule ^/ibmcognos/bi/rv/(.*)$ /ibmcognos/rv/$1 [PT,L]

# Define cognos location
<Location /ibmcognos>
        RequestHeader set X-BI-PATH /ibmcognos/bi/v1
</Location>

# Route CA REST service requests through proxy with load balancing
<Location /ibmcognos/bi/v1>
        ProxyPass balancer://mycluster/bi/v1
</Location>
```

Create the Docker file that will be used to create the custom image and insert the following:

```dockerfile
FROM httpd:2.4
COPY ./my-httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./httpd-ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf
COPY ./server.key /usr/local/apache2/conf/server.key
COPY ./server.crt /usr/local/apache2/conf/server.crt
USER root
RUN mkdir -p /opt/ibm/cognos/analytics/web
COPY /web /opt/ibm/cognos/analytics/web
```

Then build the image and run it.

```bash
$ docker build -t my-apache2 .
$ docker run -dit --name webtier -p 443:443 my-apache2
```

Check the logs to be sure the container started properly

```bash
$ docker logs webtier
```

## Push the image
To work best within a swarm cluster, and to reduce maintenance, the images should be pushed to a registry rather than exported and copied to each virtual machine in the cluster. There are serveral options for storing images varying from: running your own registry container, an enterprise registry or a cloud registry. This step will push the image into a private Google container registry in the cloud.

The Google container registry utilizes a storage bucket within the project to store images. The bucket itself is automatically created.

The first step to be able to push an image to any registry is to authenticate. In this case, all virtual machines in the Google cloud preinstall the gcloud executable to do this. Google recommends using a service account along with a key file that can be obtained from the Google cloud console. When creating the service account grant the Storage Admin and Container Registry Service Agent roles.

1. Visit APIs and Services > Credentials
2. Click on the service account to generate the key file for
3. Then select to ADD KEY > Create a new key

The key file will be saved locally. Copy it to the virtual machine to be used for the next step.

```bash
$ gcloud auth activate-service-account container-registry@stocks-289415.iam.gserviceaccount.com --key-file cloud-registry.json
$ gcloud auth configure-docker
```

Now retag the image and push it to the registry:

```bash
$ docker tag my-apache2 us.gcr.io/stocks-289415/my-apache2
$ docker push us.gcr.io/stocks-289415/my-apache2
```

## Domain Registration
In order to access from the internet a domain registration will be required. I just used [Google Domains](https://domains.google.com). There is an annual charge for registering your domain.

## Create Network Endpoint Group
This is just a group of VM instances that will have the same service running. In this case there is currently just one. Once docker swarm is implemented though this could contain the entire swarm. 

1. Log into your Google Cloud account
2. Switch to the desired project
3. Click on three bars at the top left to expand the Navigation menu
4. Under Compute Engine, select Network Endpoint Groups
5. Click on create a new endpoint group
6. Provide a unique name such as project-name-neg
7. Leave the type as zonal
8. Select VPC networks in this project
9. The Network, Subnet and Zone should provide suitable default values unless the project has been customized. In which case, select appropriate values making sure that the subnet is correct for the internal address of the VMs that will be added.
10. Set the default port to 443 for HTTPS traffic
11. Click Create

Next step is to add VMs to the group. For now I will add just one. In the future I could easily expand this to more servers by adding them to the group.

1. Click on the newly created Network Endpoint Group
2. In the middle, click on Add endpoints in this group
3. Select the VM instance to add (Note: only instances in the same subnet will appear here)
4. Click Add network endpoints
5. Supply the IP address for the VM instance (Note: you can expand the Check primary IP addresses & alias IP range in 'nic0' link if you don't remember it)
6. Leave the port type at default and the port 443
7. Click create

If the previously created Apache container is running then the health status on this page should show healthy.

## Configure Load Balancer
I used a load balancer within Google Cloud and configured that to generate a certificate for the domain that I registered.

1. Log into your Google Cloud account
2. Switch to the desired project
3. Click on three bars at the top left to expand the Navigation menu
4. Under Network services, select Load balancing
5. Click Create load balancer at the top
6. Click Start configuration underneath HTTP(S) Load Balancing
7. Select From Internet to my VMs and click Continue
8. Provide a unique name such as my-project-lb
9. Click Backend configuration
10. On the right, select Backend services > Create a backend service
11. Provide a unique name such as my-project-https-service
12. For Backend type select Zonal network endpoint group
13. Change the Protocol and Named port to https
14. Select the Network endpoint group created previously
15. Scroll down to Health check and select Create a health check
16. Provide a unique name such as https-health-check
17. Change Protocol to HTTPS
18. Change the Port specification to fixed so that 443 appears
19. Click Save and continue
20. Followed by Create to finish the Backend configuration
21. Select Frontend configuration
22. Provide a unique name such as my-project-front
23. Change Protocol to HTTPS
24. Change Network service tier to Standard
25. Under Certificate select Create a new certificate
26. Provide a unique name such as my-project-https-cert
27. Change the Create mode to Google managed
28. Supply the domain that was registered previously
29. Click Create
30. Click Done to finish the Frontend configuration
31. Click Create then to finish the Load balancer

Make note of the IP address assigned to the Load balancer or visit the Load balancer configuration later to retrieve it.

## Cloud DNS
Tying it all together with a Cloud DNS zone so that our internet domain forwards to the Cloud DNS which in turn forwards to the Load balancer and ultimately to our Apache container running on VM instances.

1. On the Navigation menu, expand Network services and click on Cloud DNS
2. Click Create zone
3. Provide a unique name such as my-project-dns-zone
4. Provide the DNS name which should be the right portion of the domain registered (i.e. I registered www.hofstetr.cloud so I supplied hofstetr.cloud here)
5. Click Create
6. Next add two records to the DNS: an A record and a canonical name
    a. Click Add record set
    b. Let DNS name default to the DNS
    c. Ensure Resource record type is A
    d. Supply the IP address for the Load balancer
    e. Click Create
    f. Click Add record set again
    g. This time supply the registered domain for the DNS name (ie. www.hofstetr.cloud)
    h. Change the resource type to CNAME
    i. Set the canonical name to forward to the A record (ie. hofstetr.cloud.)
    j. Click Create

The last step is to configure the domain registrar to use the Cloud DNS name servers. Make a note of the name servers for the DNS zone which in my case are: ns-cloud-d1.googledomains.com, ns-cloud-d2.googledomains.com, ns-cloud-d3.googledomains.com and ns-cloud-d4.googledomains.com.

1. Log in to [Google Domains](https://domains.google.com)
2. Click on the domain that needs updating
3. On the left, click on DNS
4. Switch it to Use custom name servers
5. Supply all the name servers from the Cloud DNS zone

