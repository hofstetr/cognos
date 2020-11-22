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

Checks the logs to be sure the container started properly

> docker logs my-apache2