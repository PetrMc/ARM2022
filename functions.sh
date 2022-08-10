#!/bin/bash

function getSvcAddr() {
  svc=$1
  ns=$2
  ADDR=""
  ADDR=$(kubectl -n "$ns" get service "$svc" -o=jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}" 2>/dev/null)
  echo "${ADDR}"
}

function updateRoute53() {
  OPERATION="UPSERT"
  RECORD_TTL=300
  FQDN=$1
  RECORD_VALUE=$2
  RECORD_TYPE="A"
  if [ -n "$3" ]; then
    RECORD_TYPE=$3
  fi
  echo $FQDN, $RECORD_VALUE

  eval "echo \"$(cat route53_record.tmpl)\"" >/tmp/"${FQDN}"-dns.json
  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTEDZONEID" --change-batch file:///tmp/"${FQDN}"-dns.json
  check="false"
  counter=24
  wait_time=20
  while [ "$check" = "false" ] && [ $counter -gt 0 ]; do
    RECORD="$(aws route53 list-resource-record-sets --hosted-zone-id "$HOSTEDZONEID" --query ResourceRecordSets[?Name=="'""${FQDN}"".'"] | jq .[])"
    RECORD_ACTUAL_VALUE=$(echo "$RECORD" | jq .ResourceRecords[].Value)
    if [[ ${RECORD_ACTUAL_VALUE} == *${RECORD_VALUE}* ]]; then check="true"; fi
    if [[ "$check" != "true" ]]; then
      counter=$((counter - 1))
      echo "waiting for AWS Route53" $counter >&2
      echo 
      sleep $wait_time
    fi
  done
}
function deleteRoute53record() {
  FQDN=$1
  RECORD=$(aws route53 list-resource-record-sets --hosted-zone-id "$HOSTEDZONEID" --query ResourceRecordSets[?Name=="'""${FQDN}"".'"] | jq .[])
  if [ -z "$RECORD" ]; then
    echo "Record for ${1} is not returned - can't delete" >&2
  else
    RECORD_TYPE=$(echo "$RECORD" | jq -r .Type)
    RECORD_TTL=$(echo "$RECORD" | jq .TTL)
    RECORD_VALUE=$(echo "$RECORD" | jq -r .ResourceRecords[].Value)
    OPERATION="DELETE"
    eval "echo \"$(cat "$ROOT"/templates/route53_record.json)\"" >/tmp/"${FQDN}"-delete-dns.json
    aws route53 change-resource-record-sets --hosted-zone-id "$HOSTEDZONEID" --change-batch file:///tmp/"${FQDN}"-delete-dns.json
  fi
}

function createAWSCluster() {
   CLUSTER=$1
   REGION=$2
   NODE_TYPE=$3
   NUMBER_NODES=$4
   TYPE_LABEL=$5
   SITE_LABEL=$6
   required_dashes=2
   owner_tag="${OWNER_NAME}@tetrate.io"
   number_dashes=$(echo ${REGION} | grep -o '-' | wc -l)
   if [ $number_dashes -ne $required_dashes ]; then
     echo "Region name needs correction in variables file - number of \"-\" doesn't match the AWS cloud specs" >&2
     exit 1
   fi
   eksctl create cluster --region $REGION \
           --name $CLUSTER  \
           --nodes $NUMBER_NODES \
           --node-type $NODE_TYPE \
           --node-labels="Owner=cxteam,Environment=${DEPLOYMENT_TYPE},Contact=${OWNER_NAME},type=${TYPE_LABEL},site=${SITE_LABEL},demo_env=${DEPLOYMENT_NAME}" \
           --tags "Tetrate:Owner=${owner_tag}" \
           --version=1.22 >&2

   eksctl create iamidentitymapping --cluster $CLUSTER \
	   --arn arn:aws:iam::192760260411:role/OpsAdmin \
	   --group system:masters --username OpsAdmin --region $REGION
}
