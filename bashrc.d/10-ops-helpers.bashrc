func delete-insights-pod() {
  oc delete -n openshift-insights po -l app=insights-operator
}
