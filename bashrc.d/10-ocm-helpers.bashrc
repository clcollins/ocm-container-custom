function ocm_get_hypershift() {
        ocm get clusters --parameter search="product.id = 'rosa' AND \
            state='ready' AND \
            aws.sts.role_arn != '' AND \
            hypershift.enabled='true'"     --parameter size=-1 \
        | jq -r '["ID","VERSION","NAME"], (.items[] | [.id, .openshift_version, .name]) | @tsv'
}

function ocm_get_hypershift_raw() {
        ocm get clusters --parameter search="product.id = 'rosa' AND \
            state='ready' AND \
            aws.sts.role_arn != '' AND \
            hypershift.enabled='true'"  --parameter size=-1
}

