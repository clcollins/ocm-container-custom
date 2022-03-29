alias login="ocm backplane tunnel --bastion --all -- --daemon"

obp(){
  if [ -z "$1" ]
  then
    echo "A namespace name is required"
  else
    ocm backplane project $1
  fi
}

obl(){
  if [ -z "$1" ]
  then
    echo "A cluster ID is required"
  else
    ocm backplane login $1
  fi
}

ologin(){
  if [ "$OCM_URL" == "" ];
  then
    OCM_URL="https://api.openshift.com"
  fi
  ocm login --token=$OFFLINE_ACCESS_TOKEN --url=$OCM_URL
}

