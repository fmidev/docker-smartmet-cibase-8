#!/bin/bash

function insudo {
    user=`whoami`
    if [ "$user" = "root" ] ; then
		"$@"
		return $?
    fi
    if [ ! -x /usr/bin/sudo ] ; then
		echo "Sudo not installed and installation not possible as regular user"
		exit 1
    fi
    /usr/bin/sudo "$@"
    return $?
}

function usage { 
	echo "usage: `basename $0` step [step] ..." >&2
	echo "where steps are executed in order given and might be one of:" >&2
	echo "  fmiprep  Install FMI repositories and related tools" >&2
	echo "           Not needed on every build if done alredy on docker image build" >&2
	echo "  deps     Prepare for building such as installation of dependencies" >&2
	echo "  build    Run make but does not produce RPM" >&2
	echo "           In CI you generally want rpm instead" >&2
	echo "  rpm      Build rpm and move over to directory defined by DISTDIR" >&2
	echo "  testprep Prepare for testing i.e. install dependencies" >&2
	echo "           Also links library files to test to work dir" >&2
	echo "  test     Run make test" >&2
	exit 1
}

# Number of jobs to use in make
jobs=`fgrep processor /proc/cpuinfo | wc -l`

# Help
if [ "$#" -lt "1" ] ; then usage ; fi

# Search for the root of build tree but stop when in system root
depthlimit=20
while [ ! -d .git -a "$depthlimit" -gt "0"  ] ; do
	cd ..
	depthlimit=`expr $depthlimit - 1`
done
if [ ! -d .git ] ; then
	echo "This is not a git source tree"
	exit 1
fi
echo "Source tree base is in `pwd`"
echo "Git origin is `git remote get-url origin`"


# Try to find/create suitable directory for build time distribution files
if [ -z "$DISTDIR" ] ; then
    test ! -d "/dist" || DISTDIR="/dist"
    test ! -d "/root/dist" || DISTDIR="/root/dist"
    test ! -d "$HOME/dist" || DISTDIR="$HOME/dist"
    test -n "$DISTDIR" || DISTDIR="/dist" # The default
fi
test -d "$DISTDIR/." || mkdir -p "$DISTDIR"
export DISTDIR

set -ex
echo DISTDIR: $DISTDIR
# Make sure we are using proxy, if that is needed
test -z "$http_proxy" || (
    grep -q "^proxy=" /etc/yum.conf || \
       echo proxy=$http_proxy | \
           insudo tee -a /etc/yum.conf
)

for step in $* ; do
    case $step in
	update)
	    insudo yum install -y deltarpm
	    # Update on filesystem package fails on CircleCI containers and on some else as well
	    # Enable workaround
	    insudo sed -i -e '$a%_netsharedpath /sys:/proc' /etc/rpm/macros.dist 
	    insudo yum update -y
	    ;;
	fmiprep)
	    # This will speedup future steps and there seems to be
	    # wrong URLs in these in some cases
	    insudo rm -f /etc/yum.repos.d/CentOS-Vault.repo /etc/yum.repos.d/CentOS-Sources.repo
	    # Install various packages if needed
		command -v yum-builddep 2>/dev/null || insudo yum install -y yum-utils
		command -v git 2>/dev/null || insudo yum install -y git
		command -v ccache 2>/dev/null || insudo yum install -y ccache
		test -e /etc/yum.repos.d/epel.repo 2>/dev/null || insudo yum install -y http://www.nic.funet.fi/pub/mirrors/fedora.redhat.com/pub/epel/epel-release-latest-7.noarch.rpm
		test -e /etc/yum.repos.d/smartmet-open.repo || insudo yum install -y https://download.fmi.fi/smartmet-open/rhel/7/x86_64/smartmet-open-release-17.9.28-1.el7.fmi.noarch.rpm
		test -e /etc/yum.repos.d/fmiforge.repo || insudo yum install -y https://download.fmi.fi/fmiforge/rhel/7/x86_64/fmiforge-release-17.9.28-1.el7.fmi.noarch.rpm
		test -e /etc/yum.repos.d/pgdg-95-redhat.repo || insudo yum install -y https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-redhat95-9.5-3.noarch.rpm
	    # Enable shared C Cache if enabled by surrounding environment(i.e. localbuild)
	    test ! -d "/ccache/." || (
	    	echo cache_dir=/ccache > /etc/ccache.conf
	    	echo umask=006 >> /etc/ccache.conf
	    	for i in c++ g++ gcc cc ; do
	    		test -e /usr/local/bin/$i || insudo ln -s /usr/bin/ccache /usr/local/bin/$i
	    	done
	    )
	    ccache -s
	    ;;
	cache)
	    insudo yum clean all
	    insudo rm -rf /var/cache/yum
	    insudo yum makecache
	    ;;
	deps)
	    insudo yum-builddep -y *.spec
	    ;;
	testprep)
           rpm -qlp $DISTDIR/*.rpm | grep '[.]so$' | \
               xargs --no-run-if-empty -I LIB -P "$jobs" -n 1 ln -svf LIB .
	    sed -e 's/^BuildRequires:/#BuildRequires:/' -e 's/^#TestRequires:/BuildRequires:/' < *.spec > /tmp/test.spec
	    insudo yum-builddep -y /tmp/test.spec
	    ;;
	test)
	    make -j "$jobs" test
	    ;;
	rpm)
	    make -j "$jobs" rpm
	    mkdir -p $HOME/dist
	    for d in /root/rpmbuild $HOME/rpmbuild ; do
	    	test ! -d "$d" || find "$d" -name \*.rpm -exec mv -v {} $DISTDIR \; 
	    done
	    set +x
	    echo "Distribution files are in $DISTDIR:"
	    ls -l $DISTDIR
	    ;;
	*)
	    echo "Unknown build step $step"
	    ;;
    esac
done
