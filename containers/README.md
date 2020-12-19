# Cognos in Containers
This will contain my work to implement Cognos Analytics in containers running in a swarm environment. Doing so will make it possible to easily scale Cognos Analtyics where needed. Following along with best practices each component will be run within separate containers.

## Step 1 [Content Store](Content_Store.md)
IBM Cognos Analytics requires a minimum of one database to store metadata. It is strongly encouraged to also provide a database to store audit information. Certain components can be configured to utilize dedicated databases rather than the metadata one but for now the plan is to keep it simple. Only a handful of database platforms are supported. Check [supported environments](https://www.ibm.com/support/pages/ibm-cognos-analytics-premises-111x-supported-software-environments) to ensure the use of a supported content database platform.

## Step 2 [Data Tier](Data_Tier.md)
More commonly known as the Content Manager, the Data Tier consists of services that handle authentication, authorization and management of all content stored in or retrieved from the Content Store. This set of services can be clustered but will operate as an active-passive cluster. When operating within container management it shouldn't be necessary to cluster because the manager should be capable of detecting health of the container and restarting as necessary.

## Step 3 [Application Tier](App_Tier.md)

## Step 4 [Web Tier](Web_Tier.md)
In certain situations we would not need a web tier but since I am using Google Cloud compute services SSL is required. I could enable non-SSL but that is very risky. It would ultimately be easier to implement an Apache container for this purpose.


Install following pre-requisite packages:
yum install -y xauth libXtst libXtst.i686 glibc glibc.i686 libstdc++ libstdc++.i686 nspr nspr.i686 nss nss.i686 motif motif.i686

Note: xauth and libXtst are necessary for X11 functionality.

## Step X [Docker Swarm](Docker_Swarm.md)
Tying all the containers together to run within container management, in this case a Swarm cluster. The use of a common overlay network is what allows service name resolution between containers even across compute instances.

1. docker swarm init --advertise-addr $(hostname -i)
2. Join worker nodes
3. Create the overlay network
[root@master-1 ~]# docker network create --driver overlay cognet
4. Create Content Store service
    a. [root@master-1 ~]# docker service create --name cognos-db --network cognet  --mount type=volume,dst=/var/opt/mssql,volume-driver=local,volume-opt=type=nfs,\"volume-opt=o=nfsvers=4,addr=master-1\",volume-opt=device=:/opt/ibm/cognos_data cognosdb:v1
    b. [root@master-1 ~]# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
u4q1nho6zg0d        cognos-db           replicated          1/1                 cognosdb:v1

5. Create the data tier service (Note: due to the healthcheck this will take 5 minutes)
    a. [root@master-1 ~]# docker service create --name content-manager --network cognet content-manager:v11.1.7
    b. [root@master-1 ~]# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                     PORTS
u4q1nho6zg0d        cognos-db           replicated          1/1                 cognosdb:v1
w7b9505vjngf        content-manager     replicated          1/1                 content-manager:v11.1.7

6. Check what node is running the container with:
    a. [root@master-1 ~]# docker service ps content-manager
ID                  NAME                IMAGE                     NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
vp4jzhfkpqdn        content-manager.1   content-manager:v11.1.7   master-1            Running             Running about a minute ago

7. Create the app tier service (Note: due to the healthcheck this will take 5 minutes)
    a. [root@master-1 ~]# docker service create --name application-tier --network cognet application-tier:v11.1.7
    b. [root@master-1 ~]# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                      PORTS
y3xag00nx3lk        application-tier    replicated          1/1                 application-tier:v11.1.7
9gtej1kluvj6        cognos-db           replicated          1/1                 cognosdb:v1
o7vrx1r8yc7j        content-manager     replicated          1/1                 content-manager:v11.1.7

8. Check what node is running the container with:
    a. [root@master-1 ~]# docker service ps application-tier
ID                  NAME                 IMAGE                      NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
wz3m1tf9b497        application-tier.1   application-tier:v11.1.7   master-1            Running             Running about a minute ago

9. Scale the application tier service (This is really cool!)
    a. [root@master-1 ~]# docker service scale application-tier=2
    b. [root@master-1 ~]# docker service ps application-tier
ID                  NAME                 IMAGE                      NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
wz3m1tf9b497        application-tier.1   application-tier:v11.1.7   master-1            Running             Running 3 minutes ago
8dp309oowwnx        application-tier.2   application-tier:v11.1.7   master-1            Running             Running 12 seconds ago