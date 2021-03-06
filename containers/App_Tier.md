# Application Tier
Additional data tier instances within a cluster standby to handle when the active one fails. The data tier running in a Docker Swarm cluster does not need scaling to handle fail over as long as a health check is defined for the image. The swarm master(s) will monitor the state of the container and restart it if ever found to be unhealthy. This makes it unnecessary to scale the data tier to more than a single container in order to accomplish fail over. This fact alleviates some complexity when configuring a distributed service architecture which would include having to update the configuration in each container to add additional hostnames and restarting.

## Installation
I prefer to perform the installation on a bastion host rather than inside the container at startup. This reduces the container startup time. Normal startup time for IBM Cognos Analytics can range from 5 minutes on up to 15 minutes depending on a number of factors including: content store initialization, number of authentication sources to connect to and latency with all the dependencies. Adding to that an installation step could add another several precious minutes. Doing so also allows for the pre-configuration of common settings that would not change across containers.

1. 

## Pre-Configuration
Several configuration changes can be applied prior to building the image in order to simplify the actual container startup. Settings like authentication source and content store connections will not change each time the data tier service is created in a swarm. In this example, I plan to use Google Identity Platform as an authentication source via OpenID Connect integration.

1. Change the host in Content Manager URIs to the name of the data tier service (ie. content-manager)
2. Change the configuration group to match
3. Change the configuration group contact host to the name of the data tier service (ie. content-manager)
4. Optionally configure an audit database for audit_store
5. Add a Mobile Store confgiuration of type SQL Server with the same configuration of the Content Store
5. Optionally configure a mail server connection
6. Add a Notification Store configuration of type SQL Server with the same configuration of the Content Store
7. Save and Export the configuration to cogstartup.xml.tmpl and exit (Note: it will complain about not being able to connect to content-manager at this time so just save as plain text)
8. Remove the following files to maintain as small a footprint as possible for the image and to help avoid confusion in the event that template processing fails:
    1. temp/*
    2. data/*
    3. logs/*
    4. configuration/certs/CAM*
    5. configuration/cogstartup.xml
9. Copy any required JDBC drivers to the drivers folder.

## Entrypoint Script
An entrypoint script will be needed to perform the remaining dynamic configuration and start the data tier services. I plan to use [confd](https://github.com/kelseyhightower/confd), a popular lightweight configuration management tool that is capable of integrating with many backends, such as: env, etcd, consul, vault, etc, to source configuration values. It is also capable of watching for changes in values and taking appropriate actions including restarting services. Only a couple of values are necessary which can be obtained from the env at startup. The contents of the script are relatively simple:

```text
export IPADDRESS=`ifconfig eth0 | grep 'inet' | awk '{print $2}'`
test $IPADDRESS
confd -onetime -backend env
cd /opt/ibm/cognos/analytics/app/bin64/
./cogconfig.sh -s
sleep infinity
```
First, it captures the container's IP address into an env variable then executes confd to substitute env values into the configuration template. Last, it starts the data tier services and sleeps infinitely, which is standard when there isn't a process to start in the foreground.

## Configuration Templates
Two template files are required for confd to be able to dynamically update the configuration when the entrypoint script runs: the actual Cognos configuration that has been edited and a file that tells confd what values to replace in the configuration and where to save the updated configuration when that is done.

First, update the Cognos configuration template, cogstartup.xml.tmpl, that was exported from the Configuration UI.

1. Replace all occurances of the bastion server name with a placeholder that tells confd to replace with the dynamic hostname such as bastion.google.com -> {{ getenv "HOSTNAME" }} for example:

```xml
    <crn:parameter name="sanDNSName">
        <crn:value xsi:type="xsd:string">{{ getenv "HOSTNAME" }}</crn:value>
    </crn:parameter>
```

2. Replace the one occurance of the IP address with a placeholder as well such as 127.0.0.1 -> {{ getenv "IPADDRESS" }} for example:

```xml
    <crn:parameter name="sanIPAddress">
        <crn:value xsi:type="xsd:string">{{ getenv "IPADDRESS" }}</crn:value>
    </crn:parameter>
```

Create the second file, cogstartup.xml.toml, as follows which simply informs confd to substitute the two keys with values into the template and save the resulting file at /opt/ibm/cognos/analytics/cm/configuration/cogstartup.xml

```text
[template]
src = "cogstartup.xml.tmpl"
dest = "/opt/ibm/cognos/analytics/app/configuration/cogstartup.xml"
keys = [
    "HOSTNAME",
    "IPADDRESS",
]
```

## Build Image
Using the following Dockerfile, I built the data tier container mostly from scratch starting with a CentOS base. First, all libraries are updated and then the required additional libraries are installed. Then the installed software is copied into place in the container. After that confd is installed and the templates added. The entry point script is copied and set as the startup command for the container. The last line defines the all important health check for the container. After waiting 5 minutes for the data tier to start up, remember I mentioned earlier it could take at least this long, a simple curl command checks if the servlet page contains the word "Running". Docker will know to perform this check every 30 seconds and, if it fails, will restart the container. This is why we don't need a standby instance when running with containers.

```dockerfile
FROM centos:7
RUN yum -y update && \
    yum install -y glibc glibc.i686 \
                libstdc++ libstdc++.i686 \
                libX11 libX11.i686 \
                libXext libXext.i686 \
                openmotif openmotif.i686 \
                wget net-tools bind-utils && \
    yum clean all
USER root
RUN mkdir -p /opt/ibm/cognos/analytics/app
COPY /app /opt/ibm/cognos/analytics/app
ADD https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 /usr/local/bin/confd
RUN chmod +x /usr/local/bin/confd && \
    mkdir -p /etc/confd/{conf.d,templates}
ADD cogstartup.xml.toml /etc/confd/conf.d
ADD cogstartup.xml.tmpl /etc/confd/templates
COPY /docker-entrypoint.sh /opt/ibm/cognos
RUN chmod +x /opt/ibm/cognos/docker-entrypoint.sh
CMD /opt/ibm/cognos/docker-entrypoint.sh
HEALTHCHECK --start-period=5m --interval=30s --timeout=5s CMD curl -f http://localhost:9300/bi/ | grep "Cognos Analytics" || exit 1
```
Place the Dockerfile, templates, entry point script and installation into a common location. Then build the image with:

```bash
$ docker build --tag=application-tier:v11.1.7 .
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
$ docker tag application-tier:v11.1.7 us.gcr.io/stocks-289415/application-tier:v11.1.7
$ docker push us.gcr.io/stocks-289415/application-tier:v11.1.7
```


