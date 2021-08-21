pdliu() {
  user=$1

  if [[ -z $user ]]
  then
    exit 1
  fi

  echo "pd incident:list -e $user --columns=id,status,urgency,title,service"
  pd incident:list -e $user --columns=id,status,urgency,title,service
}
