# REVIEWS CLUSTER 

the Reviews microservices of the [Bookinfo application](https://istio.io/latest/docs/examples/bookinfo/) are deployed in EC2 cluster. The services will work in conjuction of other services that are deployed in AWS Graviton cluster. 

## Deploy AWS Cluster

Requires Tetrate CX Demo script
```
source functions.sh 
export OWNER_NAME=petr
export DEPLOYMENT_TYPE=reviews
export DEPLOYMENT_NAME=arm-demo
export CLUSTER_NAME=arm-demo-reviews
export REGION=ca-central-1
createAWSCluster $CLUSTER_NAME $REGION "m5.xlarge" 2 $DEPLOYMENT_TYPE DEPLOYMENT_NAME
```

### Deploy Tetrate version of Istio
After the cluster is created

```
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve --region $REGION

aws ecr get-login-password \
    --region us-east-1 | helm registry login \
    --username AWS \
    --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com

tmproot=$PWD
cd /tmp

mkdir awsmp-chart 
cd awsmp-chart

helm pull oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/tetrate-io/tid --version 1.14.3

tar xf $(pwd)/* && find $(pwd) -maxdepth 1 -type f -delete

kubectl create namespace istio-system
            
eksctl create iamserviceaccount \
    --name tid-deployment \
    --namespace istio-system \
    --cluster $CLUSTER_NAME \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSMarketplaceMeteringFullAccess \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSMarketplaceMeteringRegisterUsage \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AWSLicenseManagerConsumptionPolicy \
    --approve \
    --override-existing-serviceaccounts

export HELM_EXPERIMENTAL_OCI=1
helm install 1.14.3-tetrate-v0 \
    --namespace istio-system ./* \
    --set Helmkeyname2=tid-deployment \
    --set global.hub=containers.istio.tetratelabs.com \
    --set global.tag=1.14.3-tetrate-v0 

cd $tmproot
rm -rf /tmp/awsmp-chart
```

## Install gateway in the cluster

```
kubectl create namespace istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm install istio-ingress istio/gateway -n istio-ingress --wait
```

## Install customized version of Reviews

```
kubectl create ns bookinfo 
kubectl label namespace bookinfo istio-injection=enabled
kubectl apply -f reviews-all.yaml
```

## Get address from the service and update CNAME for AWS (or A) record accordingly

```
REVIEWS_ADDR=$(kubectl -n istio-ingress  get service istio-ingress -o=jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
echo $REVIEWS_ADDR
```

in this case `reviews-arm-demo.cx.tetrate.info` will be set to point to the value of $REVIEWS_ADDR
```
source functions.sh 
export HOSTEDZONEID=<enter yours> # such as Z23ABC4XYZL05B
updateRoute53 reviews-arm-demo.cx.tetrate.info $REVIEWS_ADDR CNAME
```