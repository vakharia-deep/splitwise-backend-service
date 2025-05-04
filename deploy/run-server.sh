#!/bin/bash -e

cd /opt/app

echo "starting migrations"
bin/splitwise eval 'Splitwise.Release.migrate()'
echo "migrations finished"

echo "Starting server"
bin/splitwise start 