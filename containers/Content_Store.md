# Content Store
As it turns out the developer edition of Informix does not allow more than one database which is a requirement for Cognos to use Informix as a content store due to storing some columns as blobs. The next best option I found for a light weight database is actually Microsoft SQL Server. This process will create a container to host the Content Store database. In this case I utilized the developer edition of MSSQL 2019.

First, create a volume in your docker environment to persist our data. There are several ways to do this but the most common is a named volume. In order to work in a swarm cluster though it has to be a filesystem that can be accessed from any cluster node. In this case I use an NFS share to do that which does require that each node in the cluster be set up with the share.

> 

```bash
$ docker volume create --driver local --opt type=nfs --opt o=nfsvers=4,addr=master-1,rw --opt device=:/opt/ibm/cognos_data cognos_data
```

Download the base MSSQL 2019 container.

```bash
$ docker pull mcr.microsoft.com/mssql/server:2019-latest
```

Run the base container to initialize. Note the volume is mounted to be used for persisted storage. Also notice that I do not specify an edition so that it defaults to developer.

```bash
$ docker run --name mssql2019 -v cognos_data:/var/opt/mssql -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=yourStrong(!)Password' -p 1433:1433 -d mcr.microsoft.com/mssql/server:2019-latest
```

You can follow the container logs to ensure proper startup.

```bash
$ docker logs --follow mssql2019
```

Customize the container to create a dedicated database for the Content and Audit stores.

```bash
$ docker exec -it mssql2019 bash
mssql@14de7da50a13:/$ cd /opt/mssql-tools/bin
mssql@65d4bd7582e0:/opt/mssql-tools/bin$ ./sqlcmd -S localhost -U sa -P yourStrong(!)Password -d master
1> create database content_store
2> create database audit_store
3> go
1> exit
mssql@14de7da50a13:/opt/mssql-tools/bin$ exit
```

Now commit the modified container to image, stop the original container and remove it.

```bash
$ docker commit mssql2019 cognosdb:v1
$ docker stop mssql2019
$ docker rm mssql2019
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
$ docker tag cognosdb:v1 us.gcr.io/stocks-289415/cognosdb:v1
$ docker push us.gcr.io/stocks-289415/cognosdb:v1
```