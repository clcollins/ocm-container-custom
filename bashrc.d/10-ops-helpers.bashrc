delete-insights-pod() {
  oc delete -n openshift-insights po -l app=insights-operator
}

delete-machine-for-node() {
  if [[ -z $1 ]]
  then
    echo "delete-machine-for-node \$NODE"
    return
  fi

  oc get node $1 -o json | jq -r '.metadata.annotations["machine.openshift.io/machine"]' | \
  sed 's|openshift-machine-api/||' | \
  xargs --no-run-if-empty oc delete machine -n openshift-machine-api --wait=false
}

post-seccomp-servicelog() {
  local SERVICE_LOG="https://raw.githubusercontent.com/openshift/managed-notifications/master/osd/OCPBUGS-16655-remediation-please-upgrade.json"

  if [[ -z $CLUSTER_UUID ]]
  then
    echo "post-seccomp-servicelog requires teh $CLUSTER_UUID env var to be set"
    return
  fi

  osdctl servicelog post -t $SERVICE_LOG $1
}

