#!/usr/bin/env bash

########################
# include the magic from https://github.com/paxtonhare/demo-magic
########################
. ~/demo-magic.sh


########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
# TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${GREEN}Arm DevSummit 2022 ${BLUE} Istio Service Mesh on Graviton – Live Masterclass ${CYAN} $> "

# text color
# DEMO_CMD_COLOR=$BLACK

# hide the evidence
clear

pei "source functions.sh"
pei "tmproot=\$PWD"
pei "export OWNER_NAME=petr"
pei "export DEPLOYMENT_TYPE=graviton"
pei "export DEPLOYMENT_NAME=arm-demo"
pei "export CLUSTER_NAME=demo-graviton"
pei "export REGION=ca-central-1"
pei "createAWSCluster \$CLUSTER_NAME \$REGION "m6g.large" 2 \$DEPLOYMENT_TYPE DEPLOYMENT_NAME"

wait
clear

cd /tmp
pei "export VERSION=1.14.3-tetrate"
pei "curl -O https://dl.getistio.io/public/raw/files/istio-\$VERSION-multiarch-v1-linux-arm64.tar.gz"
pei "tar -xvf istio-\$VERSION-multiarch-v1-linux-arm64.tar.gz"
pei "cd istio-\$VERSION-multiarch-v1"
pei "bin/istioctl install --set profile=demo --skip-confirmation"

wait
clear

pei "kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.14/samples/addons/prometheus.yaml" 
pei "helm repo add kiali https://kiali.org/helm-charts"
pei "helm repo update"
pei "helm install \\
  --namespace istio-system \\
  --set auth.strategy=\"anonymous\" \\
  --repo https://kiali.org/helm-charts \\
  kiali-server \\
  --generate-name"
wait 
clear
pei "cd \$tmproot"
pei "kubectl apply -f namespace.yaml"
pei "kubectl apply -n bookinfo -f bookinfo.yaml"
pei "kubectl apply -f bookinfo-ingress.yaml"

pei "BOOKINFO_ADDR=\$(kubectl -n istio-system  get service istio-ingressgateway -o=jsonpath=\"{.status.loadBalancer.ingress[0]['hostname','ip']}\")"
pei "echo \$BOOKINFO_ADDR"


pei "source functions.sh"
source ~/credentials.env
pei "updateRoute53 bookinfo-arm-demo.cx.tetrate.info \$BOOKINFO_ADDR CNAME"
pei "kubectl apply -f traffic-generator.yaml"
pei "kubectl port-forward svc/kiali 20001:20001 -n istio-system"
pe ""
