#!/bin/sh -e

tmpfile=`mktemp`
trap "rm -f $tmpfile" EXIT

rebuilding="yes"

while [ "$rebuilding" ] ; do
    curl -H "Content-Type: application/json" --data '{"build": true}' -X POST "https://cloud.docker.com/api/build/v1/source/ea31c6b5-8ca1-4d0f-bd03-49eedd44c7f7/trigger/356f5bd2-1b0d-4fbf-a502-f706b6e7910d/call/" >"$tmpfile"
    rebuilding=`fgrep '"state": "Building"' < $tmpfile`
    if [ "$rebuilding" ] ; then
        echo "Still building previous version, waiting to retrigger build"
        sleep 60
    fi
done

json_reformat < "$tmpfile" || cat "$tmpfile"

# Check status
if fgrep -q '"state": "Success"' "$tmpfile" ; then
	echo 'Rebuild on docker hub initiated succesfully'
	echo "NOTE: Rebuild may take several minutes before new version is downloadable"
else
	echo 'Rebuild start on docker hub failed!'
	false
fi
 