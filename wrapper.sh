#!/bin/bash

targetuid=`id -u`

# Execute various prepartion steps when running something inside the container
if [ "$targetuid" != "0" -a "$targetuid" != "rpmbuild" ] ; then
	# Create a user for this user and make home available
	gosu 0 useradd -m -u $targetuid -s /bin/bash u$targetuid
	HOME=/home/u$targetuid
	export HOME
fi

"$@"

# Make sure certain file permissions are ok on host system
if [  "$targetuid" != "0" ] ; then sudo chown -R $targetuid /var/cache/yum /ccache ; fi
