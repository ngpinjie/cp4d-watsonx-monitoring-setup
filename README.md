# cp4d-watsonx-monitoring-setup
Scripts and instructions to enable monitoring for watsonx.data in IBM Cloud Pak for Data.

Source: https://www.ibm.com/docs/en/watsonx/watsonxdata/1.1.x?topic=bpm-monitoring-watsonxdata-presto-jmx-metrics-grafana-in-red-hat-openshift-cluster

# CP4D Watsonx Monitoring Setup

This repository contains a shell script to enable default monitoring for watsonx.data in IBM Cloud Pak for Data (CP4D). The script automates steps to set up monitoring using Prometheus and Grafana on a Red Hat OpenShift cluster.

## Pre-requisites
1. Access to a CP4D cluster with watsonx.data set-up.
2. SSH credentials to access the bastion host.
3. CP4D environment variables configured in `cpd_vars.sh`.

## Steps Automated by the Script

### Step 1: Enable watsonx.data Default Monitoring in CP4D

### 1. SSH into the bastion host:
```
ssh admin@api.XXXXXXXXXXXXXXX.cloud.techzone.ibm.com -p 40222
```
   
### 2. Change directory to CP4D and set up environment variables:
```
cd ~/cp4d
source ./cpd_vars.sh
```

### 3. Log in to the Red Hat OpenShift cluster with cpd-cli:
```
cpd-cli manage login-to-ocp \
  --username=${OCP_USERNAME} \
  --password=${OCP_PASSWORD} \
  --server=${OCP_URL}
```

### 4. Enable watsonx.data default monitoring:
```
cpd-cli manage apply-service-monitor \
  --cpd_instance_ns=<name of cpd-instance> \
  --monitors=cp4d-watsonxdata-info \
  --monitor_schedule="*/10,*,*,*,*"
```

### 5. Log in to OpenShift and verify the new cronjob:
```
oc login --username=kubeadmin --password=XXXXX-XXXXX-XXXXX-XXXXX --server=https://api.XXXXXXXXXXXXXXXXX.cloud.techzone.ibm.com:6443
oc get cj | grep servicecollection-cronjob
```

## Step 2: Export CP4D Metrics to Prometheus

### 1. Source the environment variables:
```
source ./cpd_vars.sh
```

### 2. Enter the operands namespace:
```
oc project ${PROJECT_CPD_INST_OPERANDS}
```

### 3. Create the ServiceMonitor custom resource:
```
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
```

### 4. Ensure all required nodes are started successfully:
```
oc get pod -n openshift-monitoring
```

### 5. Verify in the OpenShift console that data is pushed into the Metrics page:
Log in to the Red Hat OpenShift console.
In the Metrics targets page, ensure the zenmetrics status is Up.
Go to Observe -> Metrics to view the JMX metrics.

## Step 3: Integrate Grafana with Prometheus
### 1. Log in to OpenShift and get root access:
```
oc login --username=kubeadmin --password=XXXXX-XXXXX-XXXXX-XXXXX --server=https://api.XXXXXXXXXXXXXXXXXXXX.cloud.techzone.ibm.com:6443
sudo -i
```

### 2. Create a namespace and install Grafana in the namespace:
```
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
```

### 3. Create Grafana resources:
```
oc create serviceaccount grafana -n openshift-user-workload-monitoring
oc create clusterrolebinding grafana-cluster-monitoring-view --clusterrole=cluster-monitoring-view --serviceaccount=openshift-user-workload-monitoring:grafana
oc create token grafana --duration=100000000s -n openshift-user-workload-monitoring
```

## Step 4: Configure the Grafana Data Source
### 1. Expose Grafana route:
```
oc expose svc/grafana-a-service -n openshift-user-workload-monitoring
oc get route -n openshift-user-workload-monitoring | grep grafana-a-service
```

### 2. Log in to Grafana (use the URL obtained from the previous step).
###  Change the admin password if necessary:
```
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
```

### 3. Create a new Prometheus data source in Grafana:
Go to Home -> Connections -> Data sources -> Add new data source -> Prometheus.
Set the Prometheus server URL (run the following command to get the URL):
```
oc get route -n openshift-monitoring | grep thanos
```
Enable OAuth and add the token for authentication:
```
oc create token grafana --duration=100000000s -n openshift-user-workload-monitoring
```

### Step 5: Create a Grafana Dashboard with Metrics from Prometheus
You're good to go! Click "create new dashboard" in Grafana and start visualizing your metrics.

## Usage
### Clone the repository:
```
git clone https://github.com/your_username/cp4d-watsonx-monitoring-setup.git
cd cp4d-watsonx-monitoring-setup
```

### Make the script executable:
```
chmod +x enable_watsonx_monitoring.sh
```

### Run the script:
```
./enable_watsonx_monitoring.sh
```

## Contributing
Feel free to open issues or submit pull requests with improvements and enhancements.
