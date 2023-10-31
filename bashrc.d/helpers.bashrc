#!/usr/bin/env bash

function myclusters() {
  ocm get /api/clusters_mgmt/v1/clusters --parameter search="name like '${OCM_USER}%' and managed = 'true'" \
    | jq -r '.items[].name'
}

alias vi=vim

