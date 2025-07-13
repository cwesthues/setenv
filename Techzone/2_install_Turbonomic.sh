#!/bin/sh

############################################################

if test "${API_URL}" = ""
then
   echo
   echo "Get this from \"Reservation Details: API URL\""
   echo -n "API_URL: "
   read API_URL
   export API_URL
fi

if test "${BASTION_PASSWD}" = ""
then
   echo
   echo "Get this from \"Reservation Details: Bastion Password\""
   echo -n "BASTION_PASSWD: "
   read BASTION_PASSWD
   export BASTION_PASSWD
fi

if test "${SSH_CONNECTION}" = ""
then
   echo
   echo "Get this from \"Reservation Details: Bastion SSH connection\""
   echo -n "SSH_CONNECTION: "
   read SSH_CONNECTION
   export SSH_CONNECTION
fi

if test "${CLUSTER_ADMIN_PWD}" = ""
then
   echo
   echo "Get this from \"Reservation Details: Cluster Admin Password\""
   echo -n "CLUSTER_ADMIN_PWD: "
   read CLUSTER_ADMIN_PWD
   export CLUSTER_ADMIN_PWD
fi

if test "${TOKEN}" = ""
then
   echo
   echo "Get token from:"
   echo "Logon to \"Reservation Details:Desktop url\""
   echo "with kubeadmin/$CLUSTER_ADMIN_PWD"
   echo "Top-Right kube: Copy login command -> Display Token -> Your API token is"
   echo -n "TOKEN: "
   read TOKEN
   export TOKEN
fi

if test "${IBM_ENTITLEMENT_KEY}" = ""
then
   echo
   echo "Get key from: https://myibm.ibm.com/products-services/containerlibrary"
   echo -n "IBM_ENTITLEMENT_KEY: "
   read IBM_ENTITLEMENT_KEY
   export IBM_ENTITLEMENT_KEY
fi

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
# https://www.ibm.com/docs/en/tarm/8.15.5?topic=clusters-turbonomic-installation-red-hat-openshift-cluster

############################################################

TMPDIR="/tmp/turbonomic"
CHARTS_CR="/tmp/charts_v1alpha1_xl_cr.yaml"
COMPONENTS="\
   actionscript actionstream-kafka appdynamics appinsights aws azure datadog \
   dynatrace gcp horizon hpe3par hyperflex hyperv ibmstorage-flashsystem \
   instana jvm kubeturbo mssql mysql netapp newrelic nutanix oneview oracle \
   powervm prometheus prometheus-mysql-exporter prometurbo pure scaleio \
   servicenow snmp tomcat ucs udt vcenter vmax vmm weblogic websphere \
   wmi xen"
TURBONOMIC_ADMIN="administrator"
TURBONOMIC_PASSWD="passw0rd"

cat > /root/license.lic <<EOF
<?xml version="1.0"?>
<!-- Turbonomic license file; license created: 2022-07-20 -->
<license>
      <first-name>IBM</first-name>
      <last-name>Customer</last-name>
      <email>ibmcustomer@ibm.com</email>
      <id>0010b00002KwSu0AAF</id>
      <vm-total>999999999</vm-total>
      <edition>Premier</edition>
      <expiration-date>2122-12-31</expiration-date>
      <lock-code>2e49bfbeb00bba7e653efc7a7296cc3d</lock-code>
      <feature FeatureName="historical_data" />
      <feature FeatureName="custom_reports" />
      <feature FeatureName="planner" />
      <feature FeatureName="optimizer" />
      <feature FeatureName="multiple_vc" />
      <feature FeatureName="scoped_user_view" />
      <feature FeatureName="customized_views" />
      <feature FeatureName="group_editor" />
      <feature FeatureName="vmturbo_api" />
      <feature FeatureName="automated_actions" />
      <feature FeatureName="active_directory" />
      <feature FeatureName="full_policy" />
      <feature FeatureName="action_script" />
      <feature FeatureName="applications" />
      <feature FeatureName="app_control" />
      <feature FeatureName="loadbalancer" />
      <feature FeatureName="deploy" />
      <feature FeatureName="aggregation" />
      <feature FeatureName="fabric" />
      <feature FeatureName="storage" />
      <feature FeatureName="cloud_targets" />
      <feature FeatureName="cluster_flattening" />
      <feature FeatureName="network_control" />
      <feature FeatureName="container_control" />
      <feature FeatureName="public_cloud" />
      <feature FeatureName="vdi_control" />
      <feature FeatureName="scaling" />
      <feature FeatureName="custom_policies" />
      <feature FeatureName="SLA" />
      <feature FeatureName="cloud_cost" />
</license>
EOF

############################################################

# Find out latest 5 versions
LATEST_FIVE=`curl -L https://www.ibm.com/docs/en/tarm/8.15.1?topic=documentation-all-turbonomic-versions 2>/dev/null | fgrep "Opens " | awk 'BEGIN{FS=">"}{for(i=1;i<=NF;i++){printf("%s\n",$i)}}' | egrep -v "noopener" | sort -n | uniq | awk 'BEGIN{FS="<"}{print $1}' | egrep ^8 | egrep '(8.14|8.15|8.16|8.17)' | sort -n | tail -5 | awk '{printf("%s ",$1)}'`
DEFAULT=`echo ${LATEST_FIVE} | awk '{print $NF}'`
ALL="${LATEST_FIVE}"
SED_ALL=`echo ${ALL} | sed s/" "/"|"/g`
while test "${TURBOVERSION}" = ""
do
   echo
   echo "   (Offering latest 5)"
   echo -n "   Version? [${SED_ALL}] (<Enter> for ${DEFAULT})? "
   read ANS
   if test "${ANS}" = ""
   then
      ANS="${DEFAULT}"
   fi
   TURBOVERSION=${ANS}
done
echo "You selected ${TURBOVERSION}"
case ${TURBOVERSION} in
   8.16.5) OPVER="42.84";;
   8.16.4) OPVER="42.82";;
   8.16.3) OPVER="42.81";;
   8.16.2) OPVER="42.80";;
   8.16.1) OPVER="42.79";;
   8.16.0) OPVER="42.78";;
   8.15.6) OPVER="42.78";;
   8.15.5) OPVER="42.77";;
   8.15.4) OPVER="42.76";;
   8.15.3) OPVER="42.75";;
   8.15.2) OPVER="42.74";;
   8.15.1) OPVER="42.72";;
   8.15.0) OPVER="42.71";;
   8.14.6) OPVER="42.71";;
   8.14.5) OPVER="42.70";;
   8.14.4) OPVER="42.69";;
   8.14.3) OPVER="42.68";;
esac
if test "${OPVER}" = ""
then
   echo ${ESC} "${RED}Could not find out Operator version,${OFF}"
   echo ${ESC} "${RED}high likely a new Turbonomic version...${OFF}"
   echo ${ESC} "Look up:"
   echo ${ESC} "https://www.ibm.com/docs/en/tarm/${TURBOVERSION}?topic=notes-configuration-requirements"
   echo -n "OPVER: "
   read OPVER
fi

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

RET=`which gnome-terminal 2>/dev/null`
if test "${RET}" != ""
then
   gnome-terminal --zoom=0.7 --geometry 140x60 -e "bash -c \"/root/watchdog.sh ; exec bash\"" 1>/dev/null 2>/dev/null &
fi

RET=`which xfce4-terminal 2>/dev/null`
if test "${RET}" != ""
then
   xfce4-terminal --font="Monospace Regular 8" --geometry 140x60 -e "bash -c \"/root/watchdog.sh ; exec bash\"" 1>/dev/null 2>/dev/null &
fi
############################################################

cat > /tmp/run_as_itzuser.sh <<EOF1
#!/bin/sh

############################################################

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

############################################################

cd
oc login --insecure-skip-tls-verify=true --token=${TOKEN} --server=${API_URL}

export API_HOST="\$(echo ${API_URL} | sed 's/https:\/\///g' | sed 's/:6443//g')"

mkdir -p ${TMPDIR}

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Create Namespace${OFF}"
echo ${ESC} "${BLUE}================${OFF}"

cd ${TMPDIR}
RET=""
while test "\${RET}" = ""
do
   oc create namespace turbonomic 1>/dev/null 2>/dev/null
   RET=\`oc get ns 2>/dev/null | fgrep turbonomic\`
done

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Create OperatorGroup\${OFF}"
echo ${ESC} "\${BLUE}====================\${OFF}"

cd ${TMPDIR}
cat > operatorgroup.yaml << EOF2
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: turbonomic-operator-group
  namespace: turbonomic
spec:
  targetNamespaces:
    - turbonomic
EOF2
RET=""
while test "\${RET}" = ""
do
   oc apply -f operatorgroup.yaml 1>/dev/null 2>/dev/null
   RET=\`oc get og -n turbonomic 2>/dev/null | fgrep turbonomic-operator-group\`
done

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Create Entitlement pull secret\${OFF}"
echo ${ESC} "\${BLUE}==============================\${OFF}"

cd ${TMPDIR}
RET=""
while test "\${RET}" = ""
do
   oc create secret docker-registry ibm-entitlement-key \
      --docker-username=cp\
      --docker-password=${IBM_ENTITLEMENT_KEY} \
      --docker-server=cp.icr.io \
      --namespace=turbonomic 1>/dev/null 2>/dev/null
   RET=\`oc get secret -n turbonomic 2>/dev/null | fgrep ibm-entitlement-key\`
done

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Create catalog source\${OFF}"
echo ${ESC} "\${BLUE}=====================\${OFF}"

cd ${TMPDIR}
cat > catalogsource.yaml << EOF2
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m     
EOF2
RET=""
while test "\${RET}" = ""
do
   oc apply -f catalogsource.yaml 1>/dev/null 2>/dev/null
   RET=\`oc get catalogsource -n openshift-marketplace 2>/dev/null | egrep ibm-operator-catalog\`
done

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Update catalog\${OFF} (~1min.)"
echo ${ESC} "\${BLUE}==============\${OFF}"

cd ${TMPDIR}
IMGDIGEST=""
while test "\${IMGDIGEST}" = ""
do
   IMGDIGEST=\`oc get pods -n openshift-marketplace -l=olm.catalogSource=ibm-operator-catalog --no-headers -o=jsonpath="{.items[0].status.containerStatuses[0].imageID}" 2>/dev/null\`
   echo -n "."
   sleep 15
done

RET=""
while test "\${RET}" = ""
do
   RET=\`oc patch catalogsource ibm-operator-catalog -n openshift-marketplace --type=json -p "[{ "op": "test", "path": "/spec/image", "value": "\"icr.io/cpopen/ibm-operator-catalog:latest\"" }, { "op": "replace", "path": "/spec/image", "value": "\"\${IMGDIGEST}\"" }]" 2>/dev/null | fgrep "ibm-operator-catalog patched"\`
   echo -n "."
   sleep 15
done
echo

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Install operator\${OFF}"
echo ${ESC} "\${BLUE}================\${OFF}"

cd ${TMPDIR}
cat > install_operator.yaml << EOF2
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: t8c-certified
  namespace: turbonomic
spec:
  channel: stable
  installPlanApproval: Automatic
  name: t8c-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF2
RET=""
while test "\${RET}" = ""
do
   oc apply -f install_operator.yaml 1>/dev/null 2>/dev/null
   RET=\`oc get operators -n turbonomic 2>/dev/null | egrep turbonomic\`
done

oc adm policy add-scc-to-group anyuid system:serviceaccounts:turbonomic 1>/dev/null 2>/dev/null

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Install Turbonomic\${OFF} (~8min.)"
echo ${ESC} "\${BLUE}==================\${OFF}"

cat > ${CHARTS_CR} <<EOF2
---
apiVersion: charts.helm.k8s.io/v1
kind: Xl
metadata:
  name: xl-release
spec:
  global:
    repository: icr.io/cpopen/turbonomic
    tag: ${TURBOVERSION}
  nginx:
    nginxIsPrimaryIngress: false
    httpsRedirect: false
  nginxingress:
    enabled: true
  openshiftingress:
    enabled: true
  grafana:
    # Grafana is disabled by default. To enable it, uncomment:
    enabled: false
    adminPassword: admin
    grafana.ini:
      database:
        # Store data in sqlite3 (no persistence across restarts) by default.
        # To persist, uncomment:
        type: postgres
        password: grafana
EOF2

for COMP in ${COMPONENTS}
do
   echo "  \${COMP}:" >> ${CHARTS_CR}
   echo "    enabled: false" >> ${CHARTS_CR}
done

echo ${ESC} "\${BLUE}Create charts_v1alpha1_xl_cr\${OFF}"
oc apply -f ${CHARTS_CR} -n turbonomic 1>/dev/null 2>/dev/null
sleep 30

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Wait for all turbonomic pods are running and ready\${OFF}"
echo ${ESC} "\${BLUE}==================================================\${OFF}"

while true
do
   RET=\`kubectl get pods -n turbonomic 2>/dev/null | egrep -v '(NAME|t8c-operator)'\`
   if test "\${RET}" != ""
   then
      break
   fi
   echo -n "."
   # Retry until one turbo pod is up...
   oc apply -f ${CHARTS_CR} -n turbonomic 1>/dev/null 2>/dev/null
   sleep 10
done

while true
do
   RET=\`kubectl get pods -n turbonomic 2>/dev/null | egrep -v '(NAME|t8c-operator)' | awk '{split(\$2,X,"/");if(\$3=="Running"){if(X[1]==X[2]){printf("OK\n")}else{printf("ERR\n")}}else{printf("ERR\n")}}' | egrep -v OK\`
   if test "\${RET}" = ""
   then
      break
   fi
   echo -n "."
   sleep 10
done
echo
EOF1
chmod 755 /tmp/run_as_itzuser.sh

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Copying run_as_itzuser.sh to bastion${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"

PORT=`echo ${SSH_CONNECTION} | awk '{print $4}'`
HOST=`echo ${SSH_CONNECTION} | awk '{print $2}'`
sshpass -p ${BASTION_PASSWD} scp -o StrictHostKeyChecking=no -P ${PORT} /tmp/run_as_itzuser.sh ${HOST}:/tmp 1>/dev/null 2>/dev/null
sshpass -p ${BASTION_PASSWD} ssh -o StrictHostKeyChecking=no -p ${PORT} ${HOST} "sudo chmod 755 /tmp/run_as_itzuser.sh"

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Running run_as_itzuser.sh to bastion${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"

sshpass -p ${BASTION_PASSWD} ssh -p ${PORT} ${HOST} /tmp/run_as_itzuser.sh

URL=`oc get routes -n turbonomic --no-headers=true | awk '{print $2}'`

############################################################

if test -d /root/Desktop
then
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Creating desktop icon${OFF}"
   echo ${ESC} "${BLUE}=====================${OFF}"

   DESKTOP_LINK="/root/Desktop/Turbonomic.desktop"
   cat << EOF > ${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox https://${URL}
Name=Turbonomic
Icon=firefox
EOF

   gio set ${DESKTOP_LINK} "metadata::trusted" true
   gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
   chmod 755 "${DESKTOP_LINK}"
   echo
fi

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Setting Turbonomic GUI password${OFF}"
echo ${ESC} "${BLUE}===============================${OFF}"
echo
echo ${ESC} "User ${GREEN}${TURBONOMIC_ADMIN}${OFF} password ${GREEN}${TURBONOMIC_PASSWD}${OFF} (first login)"

curl -k "https://${URL}/api/v3/initAdmin" -X POST --data-raw "username=${TURBONOMIC_ADMIN}&password=${TURBONOMIC_PASSWD}" 1>/dev/null 2>/dev/null

curl -k "https://${URL}/api/v3/initAdmin" -X POST --data-raw "username=${TURBONOMIC_ADMIN}&password=${TURBONOMIC_PASSWD}" 1>/dev/null 2>/dev/null

TURBONOMIC_LICENSE=""
if test -f ${LOC}/SW/license.lic
then
   TURBONOMIC_LICENSE="${LOC}/SW/license.lic"
else
   if test -f /root/license.lic
   then
      TURBONOMIC_LICENSE="/root/license.lic"
   fi
fi
if test "${TURBONOMIC_LICENSE}" != ""
then
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Adding Turbonomic license${OFF}"
   echo ${ESC} "${BLUE}=========================${OFF}"
   echo
   curl -s -k  -c /tmp/cookies -H 'accept: application/json' -d 'username='${TURBONOMIC_ADMIN}'&password='${TURBONOMIC_PASSWD}'' 'https://'${URL}'/api/v3/login?hateoas=true' 1>/dev/null 2>/dev/null
   curl -X POST 'https://'${URL}'/api/v3/licenses?dryRun=false' -s -k -b /tmp/cookies -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -H 'Accept-Encoding: gzip' -H 'Content-Disposition: form-data; name="file"; filename="turbo-license.xml"' -H 'Content-Type: text/xml' -F 'file=@'${TURBONOMIC_LICENSE}'' 1>/dev/null 2>/dev/null
   curl -X PUT 'https://'${URL}'/api/v3/admin/telemetry' -s -k -b /tmp/cookies -H  "accept: application/json" -H  "Content-Type: application/json" -d "{  \"telemetryTermsViewed\": true,  \"telemetryEnabled\": false}" 1>/dev/null 2>/dev/null
else
   echo ${ESC} "${RED}Sorry, no license found, please add manually!${OFF}"
   echo "Open Turbonomic GUI and follow hints."
fi

############################################################

echo
echo "Logon to https://${URL}"
echo "with ${TURBONOMIC_ADMIN}/${TURBONOMIC_PASSWD}"
echo
