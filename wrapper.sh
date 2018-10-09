#!/bin/bash

targetuid=`id -u`
targetgid=`id -g`

# Execute various prepartion steps when running something inside the container
if [ "$targetuid" != "0" -a "$targetuid" != "rpmbuild" ] ; then
	# Create a user for this user and make home available
	gosu 0 groupadd -o -g 20 g$targetgid
	gosu 0 useradd -o -m -u $targetuid -g $targetgid -s /bin/bash u$targetuid
	HOME=/home/u$targetuid
	export HOME
fi

"$@"

# Make sure certain file permissions are ok on host system
if [  "$targetuid" != "0" ] ; then sudo chown -R $targetuid.$targetgid /var/cache/yum /ccache ; fi
