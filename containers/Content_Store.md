# Content Store
As it turns out the developer edition of Informix does not allow more than one database which is a requirement for Cognos to use Informix as a content store due to storing some columns as blobs. The next best option I found for a light weight database is actually Microsoft SQL Server. This process will create a container to host the Content Store database. In this case I utilized the developer edition of MSSQL 2019.

First, create a volume in your docker environment to persist our data. There are several ways to do this but the most common is a named volume. In order to work in a swarm cluster though it has to be a filesystem that can be accessed from any cluster node. In this case I use an NFS share to do that which does require that each node in the cluster be set up with the share.

> 


> docker volume create --driver local --opt type=nfs --opt o=nfsvers=4,addr=master-1,rw --opt device=:/opt/ibm/cognos_data cognos_data

Download the base MSSQL 2019 container.

> docker pull mcr.microsoft.com/mssql/server:2019-latest

Run the base container to initialize. Note the volume is mounted to be used for persisted storage. Also notice that I do not specify an edition so that it defaults to developer.

> docker run --name mssql2019 -v cognos_data:/var/opt/mssql -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=yourStrong(!)Password' -p 1433:1433 -d mcr.microsoft.com/mssql/server:2019-latest

You can follow the container logs to ensure proper startup.

> docker logs --follow mssql2019

Customize the container to create a dedicated database for the Content and Audit stores.

> docker exec -it mssql2019 bash

> mssql@14de7da50a13:/$ cd /opt/mssql-tools/bin

> mssql@65d4bd7582e0:/opt/mssql-tools/bin$ ./sqlcmd -S localhost -U sa -P yourStrong(!)Password -d master

> 1> create database content_store

> 2> create database audit_store

> 3> go

> 1> exit

> mssql@14de7da50a13:/opt/mssql-tools/bin$ exit

Now commit the modified container to image, stop the original container, remove it and start up the modified image

> docker commit mssql2019 cognosdb:v1

> docker stop mssql2019

> docker rm mssql2019