## Content Store
refs: https://community.ibm.com/community/user/hybriddatamanagement/blogs/pradeep-natarajan/2019/05/13/testdevsystem-with-docker

http://www.informix-dba.com/2010/07/creating-dbspaces-databases-tables-and.html

This process will create a container to host the Content Store database. In this case I utilized the developer edition of Informix, an otherwise supported content database platform.

First, create a volume in your docker environment to persist our data. There are several ways to do this but the most common is a named volume.

> docker volume create ifxdata

Download the base Informix container.

> docker pull ibmcom/informix-developer-database

Run the base container to initialize Informix. Note the volume is mounted to be used for persisted storage. Also notice that we only need the TCP port exposed for our purposes.

> docker run -it --name ifx --privileged -v ifxdata:/opt/ibm/data -p 9088:9088 -p 9089:9089 -e LICENSE=accept ibmcom/informix-developer-database

After a few minutes you will have to exit the shell with ctl-c twice which will stop the container. Check that it is stopped and if necessary start it back up in order to make some persistent changes.

> docker ps

> docker start ifx

Customize the container to create a dedicated database for the Content Store.

> docker exec -it ifx bash

> vi /opt/ibm/scripts/informix_inf.env
- add export DB_LOCALE=en_us.utf8
- add export CLIENT_LOCALE=en_us.utf8
> exit and restart the container

> [informix@ifx ~]$ sudo chown informix:informix /opt/ibm/data

> [informix@ifx ~]$ touch /opt/ibm/data/csdb.01

> [informix@ifx ~]$ chmod 660 /opt/ibm/data/csdb.01

> [informix@ifx ~]$ onspaces -c -d csdb -k 4 -p /opt/ibm/data/csdb.01 -o 0 -s 4194304

> [informix@ifx ~]$ ontape -s -L 0 -d

> [informix@ifx ~]$ onstat -d

> [informix@ifx ~]$ dbaccess - -

> create database cs in csdb with log mode ANSI;

Stop the Informix server.

> onmode -ky

Create the custom container image.

> [informix@ifx ~]$ exit
> docker commit ifx cognosdb:v1

Stop the base container image

> docker stop ifx

Run the custom container the first time

> docker run --name cognosdb -v ifxdata:/opt/ibm/data -p 9088:9088 -p 9089:9089 -e LICENSE=accept cognosdb:v1

Once again you will have to ctl-c to exit the container output but it will leave the container running. Afterwards just use docker stop / start.

> docker stop cognosdb

> docker start cognosdb

There seems to be a bug when creating the customer container that removes the DRDA alias from the onconfig. Add the DRDA alias back to the default /opt/ibm/informix/etc/onconfig after creating the custom container.

1. docker exec -it cognosdb bash
2. vi /opt/ibm/informix/etc/onconfig
3. Locate the DBSERVERALIASES line
4. Add informix_dr as an alias to match the entry in sqlhosts