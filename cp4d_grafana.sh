#!/bin/bash

# Pre-requisites
# 1. You'll need access to a CP4D cluster with watsonx.data set-up.
# 2. You'll require the ssh credentials.
# 3. You have CP4D environment variables curated in cpd_vars.sh.

# Step 1: Enable watsonx.data default monitoring in Cloud Pak for Data

# SSH into bastion
ssh admin@api.XXXXXXXXXXXXXXX.cloud.techzone.ibm.com -p 40222 << 'EOF_SSH'
cd ~/cp4d
source ./cpd_vars.sh

# Step 1.1: Log in to Red Hat OpenShift cluster with cpd-cli.
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}

# Step 1.2: Enable watsonx.data default monitoring.
cpd-cli manage apply-service-monitor \
  --cpd_instance_ns=<name of cpd-instance> \
  --monitors=cp4d-watsonxdata-info \
  --monitor_schedule="*/10,*,*,*,*"

# Step 1.3: Login into OC and verify the new cronjob.
oc login --username=kubeadmin --password=XXXXX-XXXXX-XXXXX-XXXXX --server=https://api.XXXXXXXXXXXXXXXXX.cloud.techzone.ibm.com:6443
oc get cj | grep servicecollection-cronjob

# Step 2: Export Cloud Pak for Data metrics to Prometheus
source ./cpd_vars.sh

# Step 2.2: Enter PROJECT_CPD_INST_OPERANDS namespace
oc project ${PROJECT_CPD_INST_OPERANDS}

# Step 2.3: Create the ServiceMonitor custom resource
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: zenmetrics
  namespace: ${PROJECT_CPD_INST_OPERANDS}
spec:
  endpoints:
    - interval: 5m
      port: zenwatchdog-tls
      scheme: https
      tlsConfig:
        insecureSkipVerify: true
  selector:
    matchLabels:
      component: zen-watchdog
EOF

# Step 2.4: Ensure all required nodes are started successfully.
oc get pod -n openshift-monitoring

# Step 2.5: Verify in the OpenShift console that the data is pushed into the Metrics page.
# Instructions for manual verification.
# a. Log in to the Red Hat OpenShift console.
# b. In the Metrics targets page, ensure the zenmetrics status is Up.
# c. Go to Observe -> Metrics to view the JMX metrics.

# Step 3: Integrate Grafana with Prometheus

# Login into OC and get root access
oc login --username=kubeadmin --password=XXXXX-XXXXX-XXXXX-XXXXX --server=https://api.XXXXXXXXXXXXXXXXXXXX.cloud.techzone.ibm.com:6443
sudo -i

# Step 3.1: Create a namespace and install Grafana in the namespace
# Note: Installation should be performed via RedHat UI
# Important: Ensure password requirements are met in the YAML file for Grafana.

# Step 3.2: Create Grafana resources
cat <<EOF | oc apply -f -
kind: Grafana
apiVersion: grafana.integreatly.org/v1beta1
metadata:
  name: grafana-operator.v5.9.2
  namespace: openshift-user-workload-monitoring
spec:
  config:
    auth:
      disable_login_form: 'false'
  log:
    mode: console
  security:
    admin_password: XXXXXXXXXX
    admin_user: root
EOF

oc create serviceaccount grafana -n openshift-user-workload-monitoring
oc create clusterrolebinding grafana-cluster-monitoring-view --clusterrole=cluster-monitoring-view --serviceaccount=openshift-user-workload-monitoring:grafana
oc create token grafana --duration=100000000s -n openshift-user-workload-monitoring

# Step 4: Configure the Grafana data source

# Step 4.1: Expose Grafana route
oc expose svc/grafana-a-service -n openshift-user-workload-monitoring
oc get route -n openshift-user-workload-monitoring | grep grafana-a-service

# Step 4.2: Login in Grafana (obtained from previous step)
# Change password if needed
oc patch grafana grafana-a -n openshift-user-workload-monitoring --type=merge -p '{
  "spec": {
    "config": {
      "security": {
        "admin_user": "root",
        "admin_password": "XXXXXXXXXX"
      }
    }
  }
}'

# Step 4.3: Create a new Prometheus data source in Grafana
# Manual steps for Grafana UI:
# Home -> Connections -> Data sources -> Search for "Prometheus" -> Add new data source
# Input Prometheus server URL (run the following command to get the URL):
# oc get route -n openshift-monitoring | grep thanos

# Input: Authentication -> Authentication methods -> Select "Forward OAuth Identity"
# Input: Authentication -> HTTP Headers -> Add Header "Authorization" with value "Bearer <token>"

# Generate token using:
oc create token grafana --duration=100000000s -n openshift-user-workload-monitoring

EOF_SSH

echo "Setup complete. Verify configurations and access Grafana UI as described."
