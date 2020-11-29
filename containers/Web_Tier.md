## Web Tier
Since Apache is open source and free, using an Apache container makes a lot of sense for my web tier.

First, pull the image

> docker pull httpd

For the next step I need copies of several configuration files in order to customize them. There is more than one way to obtain the copies but for now I am going to run a few temporary containers and fetch the existing configuration files from them.

> docker run --rm httpd:2.4 cat /usr/local/apache2/conf/httpd.conf > web/my-httpd.conf

Edit the my-httpd.conf and uncomment the following three lines:

1. LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
2. LoadModule ssl_module modules/mod_ssl.so
3. Include conf/extra/httpd-ssl.conf

Next, I need to obtain a valid key and certificate for the purpose of running a web site. For now I'm just going to generate a self signed pair and live with the browser warning.

> openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout web/server.key -out web/server.crt

Note: I will regenerate this key pair and enter my alias for the common name once it is known.

Create the Docker file that will be used to create the custom image and insert the following:

1. FROM httpd:2.4
2. COPY ./my-httpd.conf /usr/local/apache2/conf/httpd.conf
3. COPY ./server.key /usr/local/apache2/conf/server.key
4. COPY ./server.crt /usr/local/apache2/conf/server.crt

Then build the image and run it.

> docker build -t my-apache2 .

> docker run -dit --name webtier -p 443:443 my-apache2

Check the logs to be sure the container started properly

> docker logs webtier

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

