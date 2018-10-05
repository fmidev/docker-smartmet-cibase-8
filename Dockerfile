FROM centos:latest

# A base fmi image with proper repositories in place
# Possible also version locks and priorities
# Not much useful in itself

# Basic setup before running any yum commands
RUN echo ip_resolve=4 >> /etc/yum.conf

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
RUN yum -y install sudo
RUN mkdir -p /etc/sudoers.d && echo 'ALL ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/all
RUN curl -O /etc/yum.repos.d/libjpeg-turbo.repo https://libjpeg-turbo.org/pmwiki/uploads/Downloads/libjpeg-turbo.repo
RUN useradd rpmbuild

# Update everything
RUN yum -y update

# Keep yum cache around, useful for multiple runs of the same machine, if
# /var/cache/yum is mounted from host environment.
RUN sed -i -e 's/keepcache=0//' /etc/yum.conf && \
    echo keepcache=1 >> /etc/yum.conf
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

VOLUME /var/cache/yum
VOLUME /ccache

# Run final stuff as rpmbuild
USER rpmbuild

# Run shell
CMD ["/bin/bash"]
