#!/bin/sh

############################################################

# Get this from "Reservation Details: API URL"
export PVS_API_URL="https://api.67ee321aba3bbce52230cb8c.ocp.techzone.ibm.com:6443"

# Get this from "Reservation Details: Bastion Password"
BASTION_PASSWD="Oe28LaLY"

# Get this from "Reservation Details: Bastion SSH connection"
SSH_CONNECTION="ssh itzuser@api.67ee321aba3bbce52230cb8c.ocp.techzone.ibm.com -p 40222"

# Get this from "Reservation Details: Cluster Admin Password"
export PVS_CLUSTER_ADMIN_PWD="LU9VR-gkqWS-xJFxL-pDtGj"

# Get token from:
# Logon to "Reservation Details:Desktop url"
# with kubeadmin/$PVS_CLUSTER_ADMIN_PWD
# Top-Right kube: Copy login command -> Display Token -> Your API token is
TOKEN="sha256~ZxPTENgTOyFY28chVxKRzeyY8tjWUKvbCP4RSOGzH7U"

# Get key from: https://myibm.ibm.com/products-services/containerlibrary
export PVS_IBM_ENTITLEMENT_KEY="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJQk0gTWFya2V0cGxhY2UiLCJpYXQiOjE3NDE2MTM1NzIsImp0aSI6IjFiOGI2Mjg5MzE4MDRhYjlhYjU5MzIyNGNlMGM3Y2NhIn0.9Xf_84Il57qk40c4g67URtA1XN14UOreTFlibAvhZ_I"

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
# https://developer.ibm.com/tutorials/install-cpd-4-on-ocp-48-on-powervs/

CPD_VER="14.0.3"
CP4D_PASSWORD="Lilafranzi1%"
ALL_CP4D_COMPONENTS="\
   analyticsengine bigsql canvasbase ccs cognos_analytics cpd_platform cpfs \
   dashboard datagate datagate_instance data_governor datalineage dataproduct \
   datarefinery datastage_ent datastage_ent_plus db2aaservice db2oltp db2u \
   db2wh dmc dods dp dpra dv edb_cp4d factsheet fdb_k8s hee ibm-cert-manager \
   ibm_events_operator ibm-licensing ibm_neo4j ibm_redis_cp ibm_swhcc \
   ikc_premium ikc_standard informix informix_cp4d mantaflow match360 mongodb \
   mongodb_cp4d opencontent_elasticsearch opencontent_etcd opencontent_fdb \
   opencontent_opensearch opencontent_rabbitmq opencontent_redis openpages \
   openpages_instance openscale planning_analytics postgresql productmaster \
   productmaster_instance replication rstudio scheduler spss streamsets \
   syntheticdata udp voice_gateway watson_assistant watson_discovery \
   watson_gateway watson_speech watsonx_ai watsonx_ai_ifm watsonx_bi_assistant \
   watsonx_data watsonx_governance watsonx_orchestrate wca wca_ansible \
   wca_base wca_z wca_z_ce wkc wml wml_accelerator ws ws_pipelines \
   ws_runtimes wxd_query_optimizer zen"
CP4D_COMPONENTS="ws,wml"

############################################################

echo  ${ESC} ""
echo ${ESC} "${BLUE}Create watchdog.sh script${OFF}"
echo ${ESC} "${BLUE}==========================${OFF}"

oc login --insecure-skip-tls-verify=true --token=${TOKEN} --server=${PVS_API_URL}

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

cat > /tmp/run_as_root.sh <<EOF
#!/bin/sh

yum -y install podman
cd /tmp
curl -LO https://github.com/IBM/cpd-cli/releases/download/v${CPD_VER}/cpd-cli-linux-EE-${CPD_VER}.tgz 1>/dev/null 2>/dev/null
tar xvzf cpd-cli-linux-EE-${CPD_VER}.tgz 1>/dev/null 2>/dev/null
rm -rf cpd-cli-linux-EE-${CPD_VER}.tgz
cp -r cpd-cli-linux-EE-${CPD_VER}*/* /usr/bin
chmod -R 755 /usr/bin/cpd-cli /usr/bin/plugins
useradd cp4d
echo ${CP4D_PASSWORD} | passwd --stdin cp4d
mkdir -p /home/cp4d/.kube
cp /home/itzuser/kubeconfig /home/cp4d/.kube/config
chown -R cp4d:cp4d /home/cp4d/.kube
echo "16000" > /proc/sys/user/max_user_namespaces
loginctl enable-linger cp4d
EOF
chmod 755 /tmp/run_as_root.sh

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Copying run_as_root.sh to bastion${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"

PORT=`echo ${SSH_CONNECTION} | awk '{print $4}'`
HOST=`echo ${SSH_CONNECTION} | awk '{print $2}'`
sshpass -p ${BASTION_PASSWD} scp -P ${PORT} /tmp/run_as_root.sh ${HOST}:/tmp 1>/dev/null 2>/dev/null

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Executing run_as_root.sh on bastion as root${OFF}"
echo ${ESC} "${BLUE}===========================================${OFF}"

sshpass -p ${BASTION_PASSWD} ssh -p ${PORT} ${HOST} "sudo /tmp/run_as_root.sh"

############################################################

cat > /tmp/run_as_cp4d.sh <<EOF1
#!/bin/sh

############################################################

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

############################################################


cd
oc login --insecure-skip-tls-verify=true --token=${TOKEN} --server=${PVS_API_URL}

export PVS_API_HOST="\$(echo ${PVS_API_URL} | sed 's/https:\/\///g' | sed 's/:6443//g')"

cat > cpd_vars.sh <<EOF2
#===========================================================
# Cloud Pak for Data installation variables
#===========================================================

# ----------------------------------------------------------
# Cluster
# ----------------------------------------------------------
export OCP_URL="\$PVS_API_HOST:6443"
export OPENSHIFT_TYPE="self-managed"
export OCP_USERNAME="kubeadmin"
export OCP_PASSWORD="\$PVS_CLUSTER_ADMIN_PWD"
export OCP_TOKEN="\$(oc whoami -t)"

# ----------------------------------------------------------
# Projects
# ----------------------------------------------------------
export PROJECT_CERT_MANAGER="ibm-cert-manager"
export PROJECT_LICENSE_SERVICE="ibm-licensing"
export PROJECT_SCHEDULING_SERVICE="cpd-scheduler"
export PROJECT_CPD_INST_OPERATORS="cpd-operators"
export PROJECT_CPD_INST_OPERANDS="cpd-instance"

# ----------------------------------------------------------
# Storage
# ----------------------------------------------------------
#export STG_CLASS_BLOCK=nfs-storage-provisioner
#export STG_CLASS_FILE=nfs-storage-provisioner
export STG_CLASS_BLOCK=managed-nfs-storage
export STG_CLASS_FILE=managed-nfs-storage

# ----------------------------------------------------------
# IBM Entitled Registry
# ----------------------------------------------------------
export IBM_ENTITLEMENT_KEY=$PVS_IBM_ENTITLEMENT_KEY

# ----------------------------------------------------------
# Cloud Pak for Data version
# ----------------------------------------------------------
export VERSION=5.0.2

# ----------------------------------------------------------
# Components
# ----------------------------------------------------------
export CP4D_COMPONENTS="${CP4D_COMPONENTS}"
EOF2

source ./cpd_vars.sh

# To get all available components:
# cpd-cli manage list-components --release=\${VERSION}
# exit

cpd-cli manage login-to-ocp --token=\${OCP_TOKEN} --server=\${OCP_URL}

cpd-cli manage add-icr-cred-to-global-pull-secret --entitled_registry_key=\${IBM_ENTITLEMENT_KEY}

oc new-project \${PROJECT_CERT_MANAGER}
oc new-project \${PROJECT_LICENSE_SERVICE}
oc new-project \${PROJECT_SCHEDULING_SERVICE}
oc new-project \${PROJECT_CPD_INST_OPERATORS}
oc new-project \${PROJECT_CPD_INST_OPERANDS}

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Install shared cluster components\${OFF}"
echo ${ESC} "\${BLUE}=================================\${OFF}"

cpd-cli manage apply-cluster-components \
--release=\${VERSION} \
--license_acceptance=true \
--cert_manager_ns=\${PROJECT_CERT_MANAGER} \
--licensing_ns=\${PROJECT_LICENSE_SERVICE}

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Authorize the instance topology\${OFF}"
echo ${ESC} "\${BLUE}===============================\${OFF}"

cpd-cli manage authorize-instance-topology \
--cpd_operator_ns=\${PROJECT_CPD_INST_OPERATORS} \
--cpd_instance_ns=\${PROJECT_CPD_INST_OPERANDS}

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Set up the instance topology\${OFF}"
echo ${ESC} "\${BLUE}============================\${OFF}"

cpd-cli manage setup-instance-topology \
--release=\${VERSION} \
--cpd_operator_ns=\${PROJECT_CPD_INST_OPERATORS} \
--cpd_instance_ns=\${PROJECT_CPD_INST_OPERANDS} \
--block_storage_class=\${STG_CLASS_BLOCK} \
--license_acceptance=true

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Install operators for Cloud Pak for Data and chosen services\${OFF}"
echo ${ESC} "\${BLUE}============================================================\${OFF}"

cpd-cli manage apply-olm --release=\${VERSION} \
--cpd_operator_ns=\${PROJECT_CPD_INST_OPERATORS} \
--components=cpd_platform,\${CP4D_COMPONENTS}

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Installing Cloud Pak for Data platform services\${OFF}"
echo ${ESC} "\${BLUE}===============================================\${OFF}"

cpd-cli manage apply-cr \
--release=\${VERSION} \
--cpd_instance_ns=\${PROJECT_CPD_INST_OPERANDS} \
--components=cpd_platform \
--block_storage_class=\${STG_CLASS_BLOCK} \
--file_storage_class=\${STG_CLASS_FILE} \
--license_acceptance=true \
-v

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Install Watson Studio and Watson Machine Learning\${OFF}"
echo ${ESC} "\${BLUE}=================================================\${OFF}"

cpd-cli manage apply-cr \
--release=\${VERSION} \
--cpd_instance_ns=\${PROJECT_CPD_INST_OPERANDS} \
--components=\${CP4D_COMPONENTS} \
--block_storage_class=\${STG_CLASS_BLOCK} \
--file_storage_class=\${STG_CLASS_FILE} \
--license_acceptance=true \
-v

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Get access data\${OFF}"
echo ${ESC} "\${BLUE}===============\${OFF}"

CPADMIN_PASSWD=\`oc -n \${PROJECT_CPD_INST_OPERANDS} get secret ibm-iam-bindinfo-platform-auth-idp-credentials -o 'jsonpath={.data.admin_password}'| base64 --decode ;echo\`

URL=\`oc get routes -A | grep ibm-nginx-svc | awk '{print "https://" \$3}'\`

echo
echo "Logon with cpadmin / \${CPADMIN_PASSWD}"
echo "to \${URL}"
EOF1
chmod 755 /tmp/run_as_cp4d.sh

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Copying run_as_cp4d.sh to bastion${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"

PORT=`echo ${SSH_CONNECTION} | awk '{print $4}'`
HOST=`echo ${SSH_CONNECTION} | awk '{print $2}'`
sshpass -p ${BASTION_PASSWD} scp -P ${PORT} /tmp/run_as_cp4d.sh ${HOST}:/tmp 1>/dev/null 2>/dev/null
sshpass -p ${BASTION_PASSWD} ssh -p ${PORT} ${HOST} "sudo chmod 755 /tmp/run_as_cp4d.sh"

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Running run_as_cp4d.sh to bastion${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"

PORT=`echo ${SSH_CONNECTION} | awk '{print $4}'`
HOST=`echo ${SSH_CONNECTION} | awk '{print $2}' | sed s/"itzuser"/"cp4d"/g`

sshpass -p ${CP4D_PASSWORD} ssh -p ${PORT} ${HOST} /tmp/run_as_cp4d.sh


