sfdcme(){
    if [ -z $1 ]
    then
      echo "Case number is required"
    else
      echo "https://access.redhat.com/support/cases/#/case/${1}"
    fi
}
