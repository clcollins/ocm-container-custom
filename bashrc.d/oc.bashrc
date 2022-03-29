oc() {
    if [[ $@ == "whereami" ]]; then
        command oc get infrastructures cluster -o jsonpath='{.status.infrastructureName}{"\n"}'
    else
        command oc "$@"
    fi
}
