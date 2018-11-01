#!/bin/sh 

set -ex
# Force rebuild on docker hub
curl -H "Content-Type: application/json" --data '{"build": true}' -X POST https://registry.hub.docker.com/u/fmidev/smartmet-cibase/trigger/eae5f518-2c1e-4d5b-9b18-b8abc52c8acd/ 
echo
