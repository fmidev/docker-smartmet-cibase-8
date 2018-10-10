FROM centos:latest

# A base fmi image with proper repositories in place

# Basic setup before running any yum commands
RUN echo ip_resolve=4 >> /etc/yum.conf
RUN curl -O /etc/yum.repos.d/libjpeg-turbo.repo https://libjpeg-turbo.org/pmwiki/uploads/Downloads/libjpeg-turbo.repo

# Lock some library versions to prevent updates breaking smartmet-server
COPY versionlock.list /etc/yum/pluginconf.d/versionlock.list

# These repos are unnecessary and apparently cause update problems in certain versions
RUN rm /etc/yum.repos.d/CentOS-Vault.repo /etc/yum.repos.d/CentOS-Sources.repo

# Install some packeges
# Everything is done in separate yum command because yum has a (mis)feature where the return value
# is 0 for multiple packages if one of them succeeds. But we need for all of them to succeed.
RUN \
 yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
 yum -y install deltarpm && \
 yum -y install yum-plugin-versionlock && \
 yum -y install https://download.fmi.fi/smartmet-open/rhel/7/x86_64/smartmet-open-release-17.9.28-1.el7.fmi.noarch.rpm && \
 yum -y install https://download.fmi.fi/fmiforge/rhel/7/x86_64/fmiforge-release-17.9.28-1.el7.fmi.noarch.rpm && \
 yum -y install https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-redhat95-9.5-3.noarch.rpm && \
 yum -y install yum-utils && \
 yum -y install ccache && \
 yum -y install git && \
 yum -y install rpmlint && \
 yum -y install sudo && \
 yum -y update && \
 yum clean all && \
 rm -rf /var/cache/yum
 
# Configure sudo
RUN mkdir -p /etc/sudoers.d && echo 'ALL ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/all && \
	useradd rpmbuild

# Install gosu
ENV GOSU_VERSION 1.10
RUN set -ex; \
	\
	yum -y install epel-release; \
	yum -y install wget dpkg; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /tmp/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
#	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 ; \
#	gpg --batch --verify /tmp/gosu.asc /usr/bin/gosu; \
	rm -fr "$GNUPGHOME" /tmp/gosu.asc; \
	chmod +xs /usr/bin/gosu; \
# verify that the binary works
	gosu nobody true; \
	yum -y remove wget dpkg ; \
	yum clean all && \
 	rm -rf /var/cache/yum
    
# Cleanup, leave YUM cache empty initially 
RUN \
 yum clean all && \
 rm -rf /var/cache/yum && \
 mkdir -p /var/cache/yum && \
 rm -f /root/anaconda-ks.cfg /anaconda-post.log

# Prepare ccache usage. Build timeouts are greatly reduced, if
# /ccache is mounted from host environment
RUN mkdir -m 777 /ccache && \
    echo cache_dir=/ccache > /etc/ccache.conf && \
    echo umask=000 >> /etc/ccache.conf && \
    ln -s /usr/bin/ccache /usr/local/bin/c++ && \
    ln -s /usr/bin/ccache /usr/local/bin/g++ && \
    ln -s /usr/bin/ccache /usr/local/bin/gcc && \
    ln -s /usr/bin/ccache /usr/local/bin/cc

# Prepare CI build scripts
COPY ci-build.sh /usr/local/bin/ci-build.sh
RUN ln -s ci-build.sh /usr/local/bin/ci-build

# Wrapper for uid manipulation and other stuff
COPY wrapper.sh /usr/local/bin/wrapper.sh

# Keep yum cache around, useful for multiple runs of the same machine, if
# /var/cache/yum is mounted from host environment.
# This step must be done in the end so that yum is not going to be used anymore on docker build
RUN sed -i -e 's/keepcache=0//' /etc/yum.conf && \
    echo keepcache=1 >> /etc/yum.conf

# Run final stuff as rpmbuild
USER rpmbuild

# Always run certain autodetection steps
# Sadly, CircleCI Local CLI apparently overrides entrypoint
ENTRYPOINT [ "/usr/local/bin/wrapper.sh" ]

# Run shell
CMD ["/bin/bash"]

VOLUME /var/cache/yum
VOLUME /ccache
