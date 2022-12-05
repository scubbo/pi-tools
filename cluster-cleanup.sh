#!/bin/bash

# Clean up pods stuck in Terminating state
# https://stackoverflow.com/a/38178833/1040915
# (Do this before the next for-loop to avoid calling delete twice for the same pod)
echo "Cleaning up stuck-terminating pods"
kubectl get pods -A | grep 'Terminating' | awk '{print $1" "$2}' | xargs -I {} sh -c "kubectl delete pod --grace-period=0 --force -n {}"

for STATE in "Error" "ContainerStatusUnknown" "ImagePullBackOff" "Init:ImagePullBackOff" "Completed" "Evicted"
do
  echo "Cleaning up pods in $STATE state"
  kubectl get pods -A | grep $STATE | awk '{print $1" "$2}' | xargs -I {} sh -c "kubectl delete pod -n {}"
done
