# Docker Setup
The following was done to set up each virtual machine.

Remove old versions of Docker:

```bash
$ yum remove docker docker-client docker-client-latest docker-common \
                  docker-latest docker-latest-logrotate docker-logrotate docker-engine
```

Installed Docker Community Edition:

```bash
$ yum install -y yum-utils

$ yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
$ yum install docker-ce docker-ce-cli containerd.io
$ systemctl start docker
$ docker pull us.gcr.io/stocks-289415/my-apache2
$ docker pull us.gcr.io/stocks-289415/cognosdb:v1
$ docker pull us.gcr.io/stocks-289415/content-manager:v11.1.7
$ docker pull us.gcr.io/stocks-289415/application-tier:v11.1.7
```

# NFS Setup on Master

Add the NFS utilities to support creating NFS shared volumes.

```bash
$ yum -y install nfs-utils rpcbind
$ systemctl enable nfs-server
$ systemctl enable rpcbind
$ mkdir -p /opt/ibm/cognos_data
$ cat /etc/exports
  /opt/ibm/cognos_data 10.128.0.0/20(rw,sync,no_root_squash)
$ systemctl start nfs
$ exportfs -v
```

# NFS Setup on Workers

Add the NFS utilities to support mounting NFS shares.

```bash
$ yum -y install nfs-utils rpcbind
$ mkdir -p /opt/ibm/cognos_data
$ cat /etc/fstab |grep cognos_data
  master:/opt/ibm/cognos_data /opt/ibm/cognos_data nfs defaults 0 0
$ mount /opt/ibm/cognos_data
```