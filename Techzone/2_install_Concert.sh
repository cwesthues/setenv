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
   echo "Top-Right kube: Copy login command -> Display Token -> Your API token i
s"
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

export DOCKER_EXE=docker
export CONCERT_REGISTRY=cp.icr.io/cp/concert
export CONCERT_REGISTRY_USER="cp"
export CONCERT_REGISTRY_PASSWORD="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJQk0gTWFya2V0cGxhY2UiLCJpYXQiOjE3NDE2MTM1NzIsImp0aSI6IjFiOGI2Mjg5MzE4MDRhYjlhYjU5MzIyNGNlMGM3Y2NhIn0.9Xf_84Il57qk40c4g67URtA1XN14UOreTFlibAvhZ_I"
export CONCERT_USER="admin"
export CONCERT_PASSWD="admin"
export CONCERT_NAMESPACE="default"
export CONCERT_STORAGECLASS="managed-nfs-storage"

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
# https://www.ibm.com/docs/en/concert?topic=environment-installing-concert-software-ocp-without-cpfs

############################################################

# Find out latest 5 versions
LATEST_FIVE=`curl -L https://github.com/IBM/Concert/releases 2>/dev/null | fgrep "IBM Concert v" | egrep sr-only |  awk '{print $5}' | awk 'BEGIN{FS="<"}{print $1}' | sort -n | tail -5 | awk '{printf("%s ",$1)}'`
DEFAULT=`echo ${LATEST_FIVE} | awk '{print $NF}'`

ALL="${LATEST_FIVE}"
SED_ALL=`echo ${ALL} | sed s/" "/"|"/g`
while test "${CONCERT_VERSION}" = ""
do
   echo
   echo "Select version you want to install:"
   echo "   (Offering latest 5)"
   echo -n "   Version? [${SED_ALL}] (<Enter> for ${DEFAULT})? "
   read ANS
   if test "${ANS}" = ""
   then
      ANS="${DEFAULT}"
   fi
   CONCERT_VERSION=${ANS}
done
echo "You selected ${CONCERT_VERSION}"

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

cat > /tmp/run_as_itzuser.sh <<EOF1
#!/bin/sh

############################################################

. /etc/os-release

case \${ID_LIKE} in
*rhel*|*fedora*)
   ESC="-e"
;;
esac

ARCH=\`arch\`

############################################################

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

############################################################

cd
oc login --insecure-skip-tls-verify=true --token=${TOKEN} --server=${API_URL}

export API_HOST="\$(echo ${API_URL} | sed 's/https:\/\///g' | sed 's/:6443//g')"

############################################################

echo \${ESC} ""
echo \${ESC} "\${BLUE}Downloading ibm-concert-k8s.tgz\${OFF}"
echo \${ESC} "\${BLUE}===============================\${OFF}"

wget https://github.com/IBM/Concert/releases/download/${CONCERT_VERSION}/ibm-concert-k8s.tgz
tar xfz ibm-concert-k8s.tgz

############################################################

echo \${ESC} ""
echo \${ESC} "\${BLUE}Installing Concert\${OFF} (~5 min.)"
echo \${ESC} "\${BLUE}==================\${OFF}"

cd ibm-concert-k8s
./install-concert-k8s  \
--license_acceptance=y \
--namespace=${CONCERT_NAMESPACE} \
--registry=${CONCERT_REGISTRY} \
--registry_user=${CONCERT_REGISTRY_USER} \
--registry_password=${CONCERT_REGISTRY_PASSWORD} \
--username=${CONCERT_USER} \
--password=${CONCERT_PASSWD} \
--storage_class=${CONCERT_STORAGECLASS} \
--scale_config=level_2

############################################################

echo \${ESC} ""
echo \${ESC} "\${BLUE}Set route\${OFF}"
echo \${ESC} "\${BLUE}=========\${OFF}"

./ocp-route.sh ${CONCERT_NAMESPACE}

############################################################

echo \${ESC} ""
echo \${ESC} "\${BLUE}Get URL and credentials\${OFF}"
echo \${ESC} "\${BLUE}=======================\${OFF}"

URL=\`oc --no-headers=true get route concert -n ${CONCERT_NAMESPACE} | awk '{print \$2}'\`
echo
echo "URL is \${URL}"
echo

echo
echo "Credentials:"
echo "============"
oc extract -n ${CONCERT_NAMESPACE} secret/app-cfg-secret --to=-
EOF1
chmod 755 /tmp/run_as_itzuser.sh

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Copying run_as_itzuser.sh to bastion${OFF}"
echo ${ESC} "${BLUE}====================================${OFF}"

PORT=`echo ${SSH_CONNECTION} | awk '{print $4}'`
HOST=`echo ${SSH_CONNECTION} | awk '{print $2}'`
sshpass -p ${BASTION_PASSWD} scp -o StrictHostKeyChecking=no -P ${PORT} /tmp/run_as_itzuser.sh ${HOST}:/tmp 1>/dev/null 2>/dev/null
sshpass -p ${BASTION_PASSWD} ssh -o StrictHostKeyChecking=no -p ${PORT} ${HOST} "sudo chmod 755 /tmp/run_as_itzuser.sh"

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Running run_as_itzuser.sh to bastion${OFF}"
echo ${ESC} "${BLUE}====================================${OFF}"

sshpass -p ${BASTION_PASSWD} ssh -o StrictHostKeyChecking=no -p ${PORT} ${HOST} /tmp/run_as_itzuser.sh
