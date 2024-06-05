#!/bin/bash
set -e

export CLUSTER=mycluster
export HTTPPORT=8080
export GRAFANA_PASS=operator

# Remove existing cluster if it exists
if [[ ! -z $(k3d cluster list | grep "^${CLUSTER}") ]]; then
  echo
  echo "==== remove existing cluster"
  read -p "K3D cluster \"${CLUSTER}\" exists. Ok to delete it and restart? (y/n) " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo "bailing out..."
    exit 1
  fi
  k3d cluster delete ${CLUSTER}
fi  

# Create new cluster with 3 nodes
k3d cluster create --config k3d-config.yaml.template
export KUBECONFIG=$(k3d kubeconfig write ${CLUSTER})

# Label nodes dynamically
kubectl label node k3d-mycluster-agent-0 kubernetes.io/hostname=node1 --overwrite
kubectl label node k3d-mycluster-agent-1 kubernetes.io/hostname=node2 --overwrite
kubectl label node k3d-mycluster-agent-2 kubernetes.io/hostname=node3 --overwrite

echo
echo "==== running helm for ingress-nginx"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create namespace ingress-nginx || true
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx

echo
echo "==== waiting for ingress-nginx-controller deployment to be ready"
kubectl rollout status deployment.apps ingress-nginx-controller -n ingress-nginx --timeout=10m
kubectl rollout status daemonset.apps svclb-ingress-nginx-controller -n ingress-nginx --timeout=10m

# Install Prometheus stack
echo "==== install prometheus-community stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring || true
cat prom-values.yaml.template | envsubst | helm install --values - prom prometheus-community/kube-prometheus-stack -n monitoring
kubectl rollout status deployment.apps prom-grafana -n monitoring --timeout=10m
kubectl rollout status deployment.apps prom-kube-state-metrics -n monitoring --timeout=10m
kubectl rollout status deployment.apps prom-kube-prometheus-stack-operator -n monitoring --timeout=10m

# Loop to pull and tag six images of memory simulation from Docker repository
for i in {1..6}; do
  export APP="memory-simulation-$i"
  export VERSION="1.0.$i"
  
  echo "==== pull app image ${APP}:${VERSION}"
  docker pull chaimaraach/pod-memory-simulation:latest

  echo "==== import new image ${APP}:${VERSION} to k3d ${CLUSTER}"
  k3d image import chaimaraach/pod-memory-simulation:latest -c ${CLUSTER} --keep-tools 
done

# Create namespace once
kubectl create namespace memory-simulation || true

echo "==== deploy application (namespace, pods, service)"
for i in {1..6}; do
  export APP="memory-simulation-$i"
  export VERSION="1.0.$i"
  NODE_INDEX=$(( (i-1) % 3 + 1 ))
  export NODE_NAME="node${NODE_INDEX}"
  cat app.yaml.template | sed "s/\${i}/$i/g" | envsubst | kubectl apply -f -
done

cat static-info-dashboard.json.template | envsubst > /tmp/static-info-dashboard.json
kubectl create configmap static-metric-dashboard-configmap -n monitoring --from-file="/tmp/static-info-dashboard.json" --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap static-metric-dashboard-configmap grafana_dashboard=1 -n monitoring --overwrite
rm /tmp/static-info-dashboard.json

echo "==== wait for memory-simulation deployment to finish"
kubectl rollout status deployment.apps memory-simulation-deploy-1 -n memory-simulation --timeout=20m

# Port forwarding for Grafana
kubectl port-forward svc/prom-grafana $HTTPPORT:80 -n monitoring &

echo "==== Show Services:"
kubectl get svc -n memory-simulation

echo 
echo "==== Various entrypoints"
echo "export KUBECONFIG=${KUBECONFIG}"
echo "Lens: monitoring/prom-kube-prometheus-stack-prometheus:9090/prom"
echo "prometheus: http://localhost:${HTTPPORT}/prom"
echo "alertmanager: http://localhost:${HTTPPORT}/alert"
echo "grafana: http://localhost:${HTTPPORT}  (use admin/${GRAFANA_PASS} to login)"
