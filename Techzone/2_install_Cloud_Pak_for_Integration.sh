#!/bin/sh

############################################################

# Get this from "Reservation Details: API URL"
export API_URL="https://api.67fbb98bdaa393c54ff91742.ocp.techzone.ibm.com:6443"

# Get token from:
# Logon to "Reservation Details:Desktop url"
# with kubeadmin/$CLUSTER_ADMIN_PWD
# Top-Right kube: Copy login command -> Display Token -> Your API token is
TOKEN="sha256~mm9TeMdPtmJCav-IdK7FcKJfTJJ70HR9nQhtGvzWfIU"

# Get key from: https://myibm.ibm.com/products-services/containerlibrary
export IBM_ENTITLEMENT_KEY="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJQk0gTWFya2V0cGxhY2UiLCJpYXQiOjE3NDE2MTM1NzIsImp0aSI6IjFiOGI2Mjg5MzE4MDRhYjlhYjU5MzIyNGNlMGM3Y2NhIn0.9Xf_84Il57qk40c4g67URtA1XN14UOreTFlibAvhZ_I"

############################################################

. /etc/os-release

case ${ID_LIKE} in
*rhel*|*fedora*)
   ESC="-e"
;;
esac

ARCH=`arch`

############################################################

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

############################################################

# Based upon:
# https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.1.1?topic=installing
# https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.1.1?topic=images-adding-catalog-sources-openshift-cluster
# https://github.com/ibm-messaging/mq-gitops-samples/tree/main/queue-manager-basic-deployment

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Create watchdog.sh script${OFF}"
echo ${ESC} "${BLUE}==========================${OFF}"

oc login --insecure-skip-tls-verify=true --token=${TOKEN} --server=${API_URL}

cat > /root/watchdog.sh <<EOF
#!/bin/sh

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

echo ${ESC} "\033]11;#FFFFDD\007"

TIMEOUT="5"
OUTDIR="/tmp/out_\$\$"

rm -rf \${OUTDIR}
mkdir -p \${OUTDIR}

while true
do
   LINES=\`tput lines\`
   COLS=\`tput cols\`
   MLINE=\`expr \${LINES} - 2\`
   clear
   echo ${ESC} "\${BLUE}kubectl top nodes:\${OFF}"
   kubectl top nodes
   sleep \${TIMEOUT}
   for ITEM in nodes pods deployments services pv pvc
   do
      kubectl get \${ITEM} --all-namespaces | egrep -v openshift 2>/dev/null | egrep -v '(Completed|None)' | cut -c1-\${COLS} > \${OUTDIR}/out.txt
      LINES=\`wc -l \${OUTDIR}/out.txt 2>/dev/null\`
      LC=\`wc -l \${OUTDIR}/out.txt 2>/dev/null | awk '{print \$1}'\`
      TOTAL=\`expr \${LC} - 1\`
      cd \${OUTDIR}
      rm -rf x0*
      split -d -l \${MLINE} out.txt 2>/dev/null
      MAX=\`ls x0* 2>/dev/null | wc -l\`
      for file in \`ls x0* 2>/dev/null\`
      do
         clear
         NUM=\`echo \${file} 2>/dev/null | sed s/"x0"//g\`
         ACT=\`expr \${NUM} + 1\`
         echo ${ESC} "\${BLUE}kubectl get \${ITEM} --all-namespaces | egrep -v openshift:\${OFF} (Page \${ACT}/\${MAX}) (\${TOTAL} total)"
         for LINE in \`cat \${file} 2>/dev/null | sed s/" "/"#"/g\`
         do
            ORIG=\`echo \${LINE} | sed s/"#"/" "/g\`
            if test "\`echo \${ORIG} | awk '{split(\$3,X,"/");if((\$4=="Running")||(\$3~/^[0-9]/)){if(X[1]==X[2]){printf("OK\n")}else{printf("ERR\n")}}else{if((\$3=="Bound")||(\$5=="Bound")||(\$2=="Ready")){printf("OK\n")}else{printf("ERR\n")}}}' | egrep -v OK\`" != ""
            then
               echo ${ESC} "\${ORIG}"
            else
               echo ${ESC} "\${GREEN}\${ORIG}\${OFF}"
            fi
         done
         sleep \${TIMEOUT}
      done
   done
done
EOF
chmod 755 /root/watchdog.sh

gnome-terminal --zoom=0.7 --geometry 140x60 -e "bash -c \"/root/watchdog.sh ; exec bash\"" 1>/dev/null 2>/dev/null &

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Install git${OFF}"
echo ${ESC} "${BLUE}===========${OFF}"

yum -y install git

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}OpenShift Login${OFF}"
echo ${ESC} "${BLUE}===============${OFF}"

cd
oc login --insecure-skip-tls-verify=true --token=${TOKEN} --server=${API_URL}

############################################################

oc new-project integration
oc project integration

cat > operator-group.yaml <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ibm-integration-operatorgroup
  labels:
    backup.integration.ibm.com/component: operatorgroup        
spec:
  targetNamespaces:
  - integration
EOF
oc apply -f operator-group.yaml

echo ${ESC} ""
echo ${ESC} "${BLUE}Add catalog sources${OFF}"
echo ${ESC} "${BLUE}===================${OFF}"

# IBM Cloud Pak for Integration
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-integration-platform-navigator/8.0.4/OLM/catalog-sources.yaml
# IBM Automation foundation assets
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-integration-asset-repository/1.8.3/OLM/catalog-sources-linux-amd64.yaml
# IBM API Connect
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-apiconnect/6.0.0/OLM/catalog-sources.yaml
# IBM MQ
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-mq/3.5.1/OLM/catalog-sources.yaml
# IBM Event Streams
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-eventstreams/3.6.1/OLM/catalog-sources.yaml
# IBM Event Endpoint Management
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-eventendpointmanagement/11.5.0/OLM/catalog-sources.yaml
# IBM Event Processing
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-eventprocessing/1.3.1/OLM/catalog-sources.yaml
# IBM Operator for Apache Flink
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-eventautomation-flink/1.3.1/OLM/catalog-sources.yaml
# IBM DataPower Gateway
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-datapower-operator/1.13.1/OLM/catalog-sources.yaml
# IBM Aspera HSTS
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-aspera-hsts-operator/1.5.17/OLM/catalog-sources.yaml
# IBM Operator for Redis
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cloud-databases-redis/1.6.11/OLM/catalog-sources.yaml
# IBM Cloud Pak foundational services
oc apply --filename https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-common-services/4.6.11/OLM/catalog-sources.yaml

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Show catalog sources${OFF}"
echo ${ESC} "${BLUE}====================${OFF}"

oc get catalogsource -n openshift-marketplace

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Add IBM Cloud Pak for Integration operator${OFF}"
echo ${ESC} "${BLUE}==========================================${OFF}"

# https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.1.1?topic=reference-operator-instance-versions-this-release
export CHANNEL="v8.0"

# oc get catalogsource -n openshift-marketplace
export SOURCE="ibm-integration-platform-navigator-catalog"

cat > subscription.yaml <<EOF2
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-integration-platform-navigator
  labels:
    backup.integration.ibm.com/component: subscription        
spec:
  channel: ${CHANNEL}
  name: ibm-integration-platform-navigator
  source: ${SOURCE}
  sourceNamespace: openshift-marketplace
EOF2

oc apply -f subscription.yaml

echo "Wait for operator ibm-integration-platform-navigator"
RET=""
while test "${RET}" = ""
do
   RET=`oc get csv 2>/dev/null| egrep ibm-integration-platform-navigator | egrep Succeeded`
   sleep 5
   echo -n "."
done
echo

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Add IBM Cloud Pak for MQ operator${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"

# https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.1.1?topic=reference-operator-instance-versions-this-release
export CHANNEL="v3.5"

# https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.1.1?topic=operators-installing-by-using-cli#operators-available
export NAME="ibm-mq"

# oc get catalogsource -n openshift-marketplace
export SOURCE="ibmmq-operator-catalogsource"
cat > subscription.yaml <<EOF2
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${NAME}
spec:
  channel: ${CHANNEL}
  name: ${NAME}
  source: ${SOURCE}
  sourceNamespace: openshift-marketplace
EOF2
oc apply -f subscription.yaml

echo "Wait for operator ${NAME}"
RET=""
while test "${RET}" = ""
do
   RET=`oc get csv 2>/dev/null| egrep ${NAME} | egrep Succeeded`
   sleep 5 
   echo -n "."
done
echo

############################################################

oc create secret docker-registry ibm-entitlement-key \
    --docker-username=cp \
    --docker-password=${IBM_ENTITLEMENT_KEY} \
    --docker-server=cp.icr.io \
    --namespace=integration

cat > platform-ui-instance.yaml <<EOF
apiVersion: integration.ibm.com/v1beta1
kind: PlatformNavigator
metadata:
  name: integration-quickstart
  namespace: integration
  labels:
    backup.integration.ibm.com/component: platformnavigator        
spec:
  license:
    accept: true
    license: L-QYVA-B365MB
  replicas: 1
  version: 16.1.1
EOF

oc apply -f platform-ui-instance.yaml

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Create namespace for cert-manager${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"

oc new-project cert-manager-operator

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Create OperatorGroup for cert-manager${OFF}"
echo ${ESC} "${BLUE}=====================================${OFF}"

cat > certmanagerOperatorGroup.yaml <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
    name: openshift-cert-manager-operator
    namespace: cert-manager-operator
spec:
    targetNamespaces:
    - "cert-manager-operator"
EOF
oc apply -f certmanagerOperatorGroup.yaml 

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Create Subscription for cert-manager${OFF}"
echo ${ESC} "${BLUE}====================================${OFF}"

cat > certmanagerSubscription.yaml <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
    name: openshift-cert-manager-operator
    namespace: cert-manager-operator
spec:
    channel: stable-v1
    name: openshift-cert-manager-operator
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    installPlanApproval: Automatic
    startingCSV: cert-manager-operator.v1.14.1
EOF
oc apply -f certmanagerSubscription.yaml

#######################################################

echo "Wait for operator cert-manager"
RET=""
while test "${RET}" = ""
do
   RET=`oc get csv --all-namespaces 2>/dev/null | egrep cert-manager-operator | egrep Succeeded`
   sleep 5
   echo -n "."
done
echo

#cwecwe

echo "Wait for endpoint cert-manager-webhook"
RET=""
while test "${RET}" = ""
do
   RET=`oc get endpoints cert-manager-webhook -n cert-manager 2>/dev/null`
   sleep 1 
   echo -n "."
done
echo









############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Create ClusterIssuer${OFF}"
echo ${ESC} "${BLUE}====================${OFF}"

cat > cluster_issuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
oc apply -f cluster_issuer.yaml 1>/dev/null 2>/dev/null

############################################################

oc create secret generic qmdemo-passwords --from-literal=dev-admin-password=admin --from-literal=dev-app-password=admin -n integration

cat > qmdemo-mqsc-config-map.yaml <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: qmdemo-dev-config
  namespace: integration
  annotations:
    argocd.argoproj.io/sync-wave: "0"
data:
  dev-config.mqsc: |
    * © Copyright IBM Corporation 2017, 2019
    *
    *
    * Licensed under the Apache License, Version 2.0 (the "License");
    * you may not use this file except in compliance with the License.
    * You may obtain a copy of the License at
    *
    * http://www.apache.org/licenses/LICENSE-2.0
    *
    * Unless required by applicable law or agreed to in writing, software
    * distributed under the License is distributed on an "AS IS" BASIS,
    * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    * See the License for the specific language governing permissions and
    * limitations under the License.


    * Developer channel without TLS for demonstration purposes 
    DEFINE CHANNEL('DEV.APP.SVRCONN.0TLS') CHLTYPE(SVRCONN) TRPTYPE(TCP) MCAUSER('app') SSLCIPH('') SSLCAUTH(OPTIONAL) REPLACE

    * Developer channel authentication rules
    SET CHLAUTH('DEV.APP.SVRCONN.0TLS') TYPE(ADDRESSMAP) ADDRESS('*') USERSRC(CHANNEL) CHCKCLNT(REQUIRED) DESCR('Allows connection via APP channel') ACTION(REPLACE)
EOF

oc apply -f qmdemo-mqsc-config-map.yaml 

cat > qmdemo-cert.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: qmdemo-self-signed
  namespace: integration
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  commonName: qmdemo
  dnsNames:
  - qmdemo.ibm.com
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  secretName: qmdemo-cert
  subject:
    organizations:
    - IBM
EOF

echo "Wait for avail. certificate"
RET=""
while test "${RET}" = ""
do
   oc apply -f cluster_issuer.yaml 1>/dev/null 2>/dev/null
   oc apply -f qmdemo-cert.yaml 1>/dev/null 2>/dev/null
   #oc apply -f platform-ui-instance.yaml 1>/dev/null 2>/dev/null
   RET=`oc get certificates -n integration 2>/dev/null | egrep qmdemo-self-signed | egrep True`
   echo -n "."
   sleep 1
done
echo

cat > qmdemo-qm.yaml <<EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qmdemo
  annotations:
    com.ibm.mq/write-defaults-spec: 'false'
    argocd.argoproj.io/sync-wave: "1"
  namespace: integration
spec:
  license:
    accept: true
    license: L-CLXQ-ADXTK3
    use: Development
  web:
    console:
      authentication:
        provider: manual
      authorization:
        provider: manual
    enabled: true
  pki:
    keys:
      - name: certificate
        secret:
          items:
            - tls.key
            - tls.crt
          secretName: qmdemo-cert
    trust:
      - name: ca
        secret:
          items:
            - ca.crt
          secretName: qmdemo-cert
  template:
    pod:
      containers:
        - env:
            - name: MQ_CONNAUTH_USE_HTP
              value: 'true'
            - name: MQ_DEV
              value: 'true'
            - name: MQ_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: qmdemo-passwords
                  key: dev-app-password
            - name: MQ_APP_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: qmdemo-passwords
                  key: dev-app-password
          name: qmgr
  queueManager:
    mqsc:
      - configMap:
          items:
            - dev-config.mqsc
          name: qmdemo-dev-config
    storage:
      queueManager:
        type: ephemeral
    name: QMDEMO
  version: 9.4.0.0-r1
EOF
oc apply -f qmdemo-qm.yaml

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Setup producer${OFF}"
echo ${ESC} "${BLUE}==============${OFF}"

oc new-app registry.redhat.io/redhat-openjdk-18/openjdk18-openshift~https://github.com/ibm-messaging/mq-gitops-samples#main --context-dir=/queue-manager-basic-deployment/code/qmdemo-producer --env='JAVA_APP_JAR=producer-1.0-SNAPSHOT-jar-with-dependencies.jar' --env="MQ_APP_PASSWORD=admin" --name=mq-producer -n integration

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Setup consumer${OFF}"
echo ${ESC} "${BLUE}==============${OFF}"

oc new-app registry.redhat.io/redhat-openjdk-18/openjdk18-openshift~https://github.com/ibm-messaging/mq-gitops-samples#main --context-dir=/queue-manager-basic-deployment/code/qmdemo-consumer --env='JAVA_APP_JAR=consumer-1.0-SNAPSHOT-jar-with-dependencies.jar' --env="MQ_APP_PASSWORD=admin" --name=mq-consumer -n integration

############################################################

echo "Wait for URL to be ready"
URL=""
while test "${URL}" = ""
do
   URL=`oc get routes -n integration 2>/dev/null | egrep ibm-mq-web-integration | awk '{print $2}'`
   sleep 1
   echo -n "."
done
RET=""
while test "${RET}" = ""
do
   RET=`curl -LO https://${URL}/ibmmq 2>&1 | egrep legitimacy`
   sleep 1
   echo -n "."
done
echo

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Creating desktop icon${OFF}"
echo ${ESC} "${BLUE}=====================${OFF}"

DESKTOP_LINK="/root/Desktop/MQ.desktop"
cat << EOF > ${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox https://${URL}/ibmmq
Name=MQ
Icon=firefox
EOF

gio set ${DESKTOP_LINK} "metadata::trusted" true
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
chmod 755 "${DESKTOP_LINK}"
echo

############################################################

echo
echo "Browse to https://${URL}/ibmmq and login with admin/admin"
echo
