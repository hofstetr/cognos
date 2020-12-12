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
