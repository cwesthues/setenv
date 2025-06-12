#!/bin/sh

AWS_ACCOUNT_NAME=""
AWS_ACCOUNT_USERNAME=""
INSTRUQT_PARTICIPANT_ID=""
AWS_ACCOUNT_ID=""
AWS_ACCOUNT_PASSWORD=""

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

. /etc/os-release

case ${ID_LIKE} in
*rhel*|*fedora*)
   ESC="-e"
;;
esac

############################################################

RET=`which terraform 2>/dev/null`
if test "${RET}" = ""
then
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Install Terraform${OFF}"
   echo ${ESC} "${BLUE}=================${OFF}"

   yum install -y yum-utils 1>/dev/null 2>/dev/null
   yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo 1>/dev/null 2>/dev/null
   yum -y install terraform 1>/dev/null 2>/dev/null
fi

############################################################

if test "${AWS_ACCOUNT_NAME}" = ""
then
   echo "Go to TechZone 'My reservations'"
   echo "HCP Terraform Workflow -> Open this environment"
   echo "(Bottom) Open URL under 'One-time Play URL'"
   echo "Launch"
   echo "(wait for ~3min.)"
   echo "Start"
fi

############################################################

if test "${AWS_ACCOUNT_NAME}" = ""
then
   echo "Execute env | egrep '(^AWS_ACCOUNT_|^INSTRUQT_PARTICIPANT_ID)'"
   echo "Copy and edit THIS file $0 and change the header,"
   echo "then restart this script with $0"
   exit
fi

############################################################

if test ! -f /root/.terraform.d/credentials.tfrc.json
then
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Execute 'terraform login'${OFF}"
   echo ${ESC} "${BLUE}=========================${OFF}"
   echo ${ESC} "Enter 'yes'"
   echo ${ESC} "Login with cwesthues and L* in browser"
   echo ${ESC} "Generate token"
   echo ${ESC} "Copy token"
   echo 
   terraform login
fi

############################################################

DESKTOP_LINK="/root/Desktop/GitLab.desktop"
if test ! -f ${DESKTOP_LINK}
then
   echo -e ""
   echo -e "${BLUE}Creating desktop icons${OFF}"
   echo -e "${BLUE}======================${OFF}"
   cat << EOF > ${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox https://gitlab.${INSTRUQT_PARTICIPANT_ID}.instruqt.io
Name=GitLab
Icon=firefox
EOF

   gio set ${DESKTOP_LINK} "metadata::trusted" true
   gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
   chmod 755 "${DESKTOP_LINK}"
   DESKTOP_LINK="/root/Desktop/AWS.desktop"
   cat << EOF > ${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox https://eu-north-1.signin.aws.amazon.com
Name=AWS
Icon=firefox
EOF
   gio set ${DESKTOP_LINK} "metadata::trusted" true
   gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
   chmod 755 "${DESKTOP_LINK}"
   DESKTOP_LINK="/root/Desktop/HCP.desktop"
   cat << EOF > ${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox https://app.terraform.io
Name=HCP
Icon=firefox
EOF
   gio set ${DESKTOP_LINK} "metadata::trusted" true
   gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
   chmod 755 "${DESKTOP_LINK}"
   DESKTOP_LINK="/root/Desktop/Registry.desktop"
   cat << EOF > ${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=false
Exec=firefox https://registry.terraform.io/browse/providers
Name=Registry
Icon=firefox
EOF
   gio set ${DESKTOP_LINK} "metadata::trusted" true
   gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell  --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
   chmod 755 "${DESKTOP_LINK}"
fi

############################################################

echo ${ESC} "Logon to GitLab"
echo ${ESC} "URL: https://gitlab.${INSTRUQT_PARTICIPANT_ID}.instruqt.io"
echo ${ESC} "Username: root"
echo ${ESC} "Password: ${INSTRUQT_PARTICIPANT_ID}"
echo

############################################################

echo ${ESC} "Logon to AWS"
echo ${ESC} "URL: https://eu-north-1.signin.aws.amazon.com"
echo ${ESC} "Account ID: ${AWS_ACCOUNT_ID}"
echo ${ESC} "IAM username: ${AWS_ACCOUNT_USERNAME}"
echo ${ESC} "Password: ${AWS_ACCOUNT_PASSWORD}"
echo

############################################################

echo ${ESC} "Logon to HCP"
echo ${ESC} "URL: https://app.terraform.io"
echo ${ESC} "User: cwesthues"
echo ${ESC} "Password: L*"
echo

############################################################

echo ${ESC} "Logon to Registry"
echo ${ESC} "URL: https://registry.terraform.io/browse/providers"
echo

############################################################

echo ${ESC} "In GitLab"
echo ${ESC} "Projects -> Platform Group / terramino-app"
echo

############################################################

echo ${ESC} "In AWS"
echo ${ESC} "Change location to Ohio - us-east-2"
echo ${ESC} "Select EC2"
echo ${ESC} "Instances"
echo

############################################################
