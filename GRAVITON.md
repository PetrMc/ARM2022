# DEPLOYING GRAVITON CLUSTER

## Deploy AWS Cluster on Graviton

Requires Tetrate CX Demo script

```bash
source functions.sh 
tmproot=$PWD
export OWNER_NAME=petr
export DEPLOYMENT_TYPE=graviton
export DEPLOYMENT_NAME=arm-demo
export CLUSTER_NAME=arm-demo-graviton
export REGION=ca-central-1
createAWSCluster $CLUSTER_NAME $REGION "m6g.large" 2 $DEPLOYMENT_TYPE DEPLOYMENT_NAME
```

## Deploy Istio in the newly created Graviton cluster

```bash
cd /tmp
export VERSION="1.14.3-tetrate"
curl -O https://dl.getistio.io/public/raw/files/istio-$VERSION-multiarch-v1-linux-arm64.tar.gz
tar -xvf istio-$VERSION-multiarch-v1-linux-arm64.tar.gz
cd istio-$VERSION-multiarch-v1
bin/istioctl install --set profile=demo --skip-confirmation
```

## Install Kiali

prerequisite is Prometheus - use the following to install:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.14/samples/addons/prometheus.yaml
```

then deploy Kiali per:

```bash
helm repo add kiali https://kiali.org/helm-charts
helm repo update
helm install \
  --namespace istio-system \
  --set auth.strategy="anonymous" \
  --repo https://kiali.org/helm-charts \
  kiali-server \
  kiali-server
```

## Deploy bookinfo application (all without Reviews)

```bash
cd $tmproot
kubectl apply -f bookinfo-graviton.yaml 
```

## Get address from the services and update CNAME for AWS (or A) records accordingly

```bash
BOOKINFO_ADDR=$(kubectl -n istio-system  get service istio-ingressgateway -o=jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
echo $BOOKINFO_ADDR
```

in this case `ratings-arm-demo.cx.tetrate.info` and `bookinfo-arm-demo.cx.tetrate.info` will be set to point to the value of $BOOKINFO_ADDR

```bash
source functions.sh 
export HOSTEDZONEID=<enter yours> # such as Z23ABC4XYZL05B
updateRoute53 bookinfo-arm-demo.cx.tetrate.info $BOOKINFO_ADDR CNAME
updateRoute53 ratings-arm-demo.cx.tetrate.info $BOOKINFO_ADDR CNAME
```

## Finally deploy Traffic Generator

```bash
kubectl apply -f traffic-generator.yaml 
```

## Access Kiali

```bash
kubectl port-forward svc/kiali 20001:20001 -n istio-system
```

point your browser to [localhost:20001](http://localhost:20001)

## Access Bookinfo Application

```bash
http://bookinfo-arm-demo.cx.tetrate.info/productpage
```
