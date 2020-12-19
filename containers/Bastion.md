# Bastion Setup
The following was done to set up the Bastion, aka. build, server.

sudo systemctl stop docker
sudo rsync -axPS /var/lib/docker/ /mnt/x/y/docker_data #copy all existing data to new location
sudo vi /lib/systemd/system/docker.service # or your favorite text editor
in file docker.service find one line like this:

ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

add --data-root /mnt/x/y/docker_data to it(on one line):

ExecStart=/usr/bin/dockerd --data-root /mnt/x/y/docker_data -H fd:// --containerd=/run/containerd/containerd.sock

save and quit, then

sudo systemctl daemon-reload
sudo systemctl start docker

Add the NFS utilities to support creating NFS shared volumes.

yum install nfs-utils rpcbind
systemctl enable nfs-server
systemctl enable rpcbind
cat /etc/exports
/opt/ibm/cognos_data 10.128.0.0/20(rw,sync,no_root_squash)
systemctl start nfs
exportfs -v