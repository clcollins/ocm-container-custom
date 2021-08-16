#!/usr/bin/env bash

usage() {
    echo "Usage: $0 CLUSTER"
    exit 1
}

[[ $# -eq 1 ]] || usage
cluster=$1

tmpd=$(mktemp -d)
trap "rm -fr $tmpd" EXIT

aws-get-creds.sh $cluster > $tmpd/exports
source $tmpd/exports

aws-validate-cluster.sh -r $AWS_DEFAULT_REGION -n $cluster

