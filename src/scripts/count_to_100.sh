#!/bin/sh
# Prints numbers 1 through 100 (used by the Kubernetes CronJob).

i=1
while [ "$i" -le 100 ]; do
  echo "$i"
  i=$((i + 1))
done

echo "done counting to 100"
