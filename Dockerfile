FROM centos:latest

# A base fmi image with proper repositories in place
# Possible also version locks and priorities
# Not much useful in itself

# Keep yum cache around, useful for multiple runs of the same machine
# This greatly reduces download time
# In order to do this, mount /var/cache/yum to host machine directory
RUN sed -i -e 's/keepcache=0//' /etc/yum.conf && \
    echo keepcache=1 >> /etc/yum.conf

# Add EPEL repository and lock certain versions
RUN \
 yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
 yum -y install yum-plugin-versionlock

COPY versionlock.list /etc/yum/pluginconf.d/versionlock.list

# Install some more packages
RUN \
 yum -y install https://download.fmi.fi/smartmet-open/rhel/7/x86_64/smartmet-open-release-17.9.28-1.el7.fmi.noarch.rpm && \
 yum -y install https://download.fmi.fi/fmiforge/rhel/7/x86_64/fmiforge-release-17.9.28-1.el7.fmi.noarch.rpm && \
 yum -y install https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-redhat95-9.5-3.noarch.rpm && \
 yum -y install yum-utils && \
 yum -y install ccache && \
 yum -y install git && \
 yum -y install rpmlint

# Update everything
RUN yum -y update

# Prepare ccache usage (ccache is primarily useful with local CLI builds)
RUN mkdir -m 777 /ccache && \
    echo cache_dir=/ccache > /etc/ccache.conf && \
    echo umask=000 >> /etc/ccache.conf && \
    ln -s /usr/bin/ccache /usr/local/bin/c++ && \
    ln -s /usr/bin/ccache /usr/local/bin/g++ && \
    ln -s /usr/bin/ccache /usr/local/bin/gcc && \
    ln -s /usr/bin/ccache /usr/local/bin/cc

# Cleanup, leave YUM cache empty initially 
RUN \
 yum clean all && \
 rm -rf /var/cache/yum && \
 mkdir -p /var/cache/yum && \
 rm -f /root/anaconda-ks.cfg /anaconda-post.log
VOLUME /var/cache/yum

# Run shell
CMD ["/bin/bash"]
