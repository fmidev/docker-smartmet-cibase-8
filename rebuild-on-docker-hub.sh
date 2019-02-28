#!/bin/sh -e

tmpfile=`mktemp`
trap "rm -f $tmpfile" EXIT

curl -H "Content-Type: application/json" --data '{"build": true}' -X POST https://registry.hub.docker.com/u/fmidev/smartmet-cibase/trigger/eae5f518-2c1e-4d5b-9b18-b8abc52c8acd/ >"$tmpfile"

if command -v json_reformat >/dev/null ; then
 	json_reformat < "$tmpfile"
else 
	cat "$tmpfile"
fi

# Check status
if fgrep -q '"state": "Success"' "$tmpfile" ; then
	echo 'Rebuild on docker hub initiated succesfully'
	echo "NOTE: Rebuild may take several minutes before new version is downloadable"
else
	echo 'Rebuild start on docker hub failed!'
	false
fi
 