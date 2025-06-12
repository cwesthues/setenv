#!/bin/sh

PACKAGE="CE"

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

echo ${ESC} ""
echo ${ESC} "${BLUE}Locating SW repository outside VM${OFF}"
echo ${ESC} "${BLUE}=================================${OFF}"
CAND="/mnt/hgfs/*/work /mnt/hgfs/*/My/CD /media/*/work /media/*/My/CD /root /mnt/hgfs/home/work /media/sf_Users/*/work"
LOC=""
for LOCX in ${CAND}
do
   if test -d ${LOCX}/${PACKAGE}
   then
      LOC="${LOCX}/${PACKAGE}"
      break
   fi
done

if test "${LOC}" != ""
then
   echo "SW repository found under ${LOC}"
fi

############################################################

RET1=`systemctl status chronyd 2>/dev/null`
if test "${RET1}" != ""
then
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Wait for chronyd${OFF}${TIME}"
   echo ${ESC} "${BLUE}=======================${OFF}"

   RET2=""
   while test "${RET2}" = ""
   do
      echo -n "."
      RET2=`systemctl status chronyd | fgrep "Selected source"`
      sleep 1
   done
   echo
   sleep 1
fi

############################################################

if test -d /root/Desktop
then
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Creating desktop icon${OFF}"
   echo ${ESC} "${BLUE}=====================${OFF}"

   DESKTOP_LINK="/root/Desktop/TechZone.desktop"
   cat << EOF > ${DESKTOP_LINK}
   [Desktop Entry]
   Type=Application
   Terminal=false
   Exec=firefox https://techzone.ibm.com
   Name=TechZone
   Icon=firefox
EOF

   gio set ${DESKTOP_LINK} "metadata::trusted" true
   gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
   chmod 755 "${DESKTOP_LINK}"
fi

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Getting oc${OFF}"
echo ${ESC} "${BLUE}==========${OFF}"

RET=`which oc 2>/dev/null`
if test "${RET}" = ""
then
   ARCH=`arch`
   cd /usr/bin
   curl -OL https://mirror.openshift.com/pub/openshift-v4/${ARCH}/clients/ocp/latest/openshift-client-linux.tar.gz 1>/dev/null 2>/dev/null
   tar xzf openshift-client-linux.tar.gz
   rm -rf openshift-client-linux.tar.gz
fi

############################################################

case ${ARCH} in
x86_64)
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Getting k9s${OFF}"
   echo ${ESC} "${BLUE}===========${OFF}"

   cd /usr/bin
   URL="https://github.com"`curl -s https://github.com/derailed/k9s/releases | egrep Linux_x86_64 | head -1 | awk 'BEGIN{FS="\""}{print $2}'`
   curl -LO ${URL} 1>/dev/null 2>/dev/null
   tar xzf k9s_Linux_x86_64.tar.gz 1>/dev/null 2>/dev/null
   rm -rf k9s_Linux_x86_64.tar.gz
;;
esac

############################################################

cat <<EOF

Which environment you you want to use?
   1) Cloud Pak for Data on OpenShift
   2) Concert on OpenShift
   3) Turbonomic on OpenShift
   4) Instana on standalone VM
   5) Cloud Pak for Integration and MQ
   6) Terraform L3 Training
EOF

read ENVIRONMENT

cat  <<EOF

Browse to https://techzone.ibm.com and login
Search environents and collections
EOF

case ${ENVIRONMENT} in
1|2|3|5)
cat <<EOF
TechZone Certified Base Images, Explore this collection
VMWare on IBM Cloud Environments
OpenShift Cluster (VMware on IBM Cloud) - UPI - Public
IBM Cloud Environment/Reserve it
Reserve now
Purpose: Test
Purpose description: ...
Preferred Geography: itzvmware - EUROPE - ...
OpenShift Version: 4.16
Min. sizes:
EOF
;;
4)
cat <<EOF
TechZone Certified Base Images, Explore this collection
Base VMs
RHEL VM - IBM Cloud OCPv
Reserve a environment
Purpose: Test
Purpose description: ...
Preferred Geography: itz-osv-01 - AMERICAS - us south ...
Min. sizes:
EOF
;;
6)
cat <<EOF
Search for HCP Terraform Workflow
Reserve a environment
Purpose: Test
Purpose description: ...
Preferred Geography: hashicorp - AMERICAS - us-south region - us-south-1 datacenter
EOF
;;
esac

case ${ENVIRONMENT} in
1)
   cat <<EOF
   Worker Node Count: 3
   Worker Node Flavor: 8 vCPU x 32 GB ...

Coontinue with
EOF
;;
2)
   cat <<EOF
   Worker Node Count: 3
   Worker Node Flavor: 8 vCPU x 32 GB ...
EOF
;;
3|5)
   cat <<EOF
   Worker Node Count: 3
   Worker Node Flavor: 4 vCPU x 16 GB ...
EOF
;;
4)
   cat <<EOF
   CPU cores: 16
   Memory: 64 GB
   Secondary disk size: 100 GB
EOF
esac

case ${ENVIRONMENT} in
1|2|3|5)
   cat <<EOF
Submit
(wait for ~ 1h)
EOF
;;
4)
   cat <<EOF
Submit
(wait for ~ 10min.)
EOF
;;
6)
   cat <<EOF
Submit
(wait for ~ 5min.)
EOF
;;
esac

case ${ENVIRONMENT} in
1)
   cat <<EOF
Continue with ./2_install_Cloud_Pak_for_Data.sh
EOF
;;
2)
   cat <<EOF
Continue with ./2_install_Concert.sh
EOF
;;
3)
   cat <<EOF
Continue with ./2_install_Turbonomic.sh
EOF
;;
4)
   cat <<EOF
Continue with ./2_install_Instana.sh
EOF
;;
5)
   cat <<EOF
Continue with ./2_install_Cloud_Pak_for_Integration.sh
EOF
;;
6)
   cat <<EOF
Continue with ./2_install_Terraform_L3_Training.sh
EOF
;;
esac

case ${ENVIRONMENT} in
1|2|3|4|5)
   cat <<EOF
Edit this file upfront and add/change details about credentials etc.
EOF
;;
esac
