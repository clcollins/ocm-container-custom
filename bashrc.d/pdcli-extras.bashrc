# pdack acknowledges an incident by id
function pdack() {
  local incident=$1
  pd incident:ack -i $1
}

