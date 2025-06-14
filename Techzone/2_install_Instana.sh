#!/bin/sh

############################################################

# Get this from "Reservation Details: For full desktop access, connect to:"
export VNC_URL=" https://vnc-infra02-hub01.osv.techzone.ibm.com/?reservation=67f1b536dbbf3678605ed78b&namespace=67f1b536dbbf3678605ed78b&token=007wpri8letnwf4"

# Get this from "Reservation Details: VM SSH connection (use private key)"
SSH_CONNECTION="ssh itzuser@169.44.147.111 -p 31471"

# Get this from "Reservation Details: VM Password"
export ITZUSER_PASSWD="Aaiv5BzSb-10-eZ"

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

SALESKEY="WB6cJcexTpiYMSnL9etr8w"
AGENTKEY="qUMhYJxjSv6uZh2SyqTEnw"

############################################################

# Find out latest 5 versions
echo ${ESC} ""
echo ${ESC} "${BLUE}Determine Instana version to use${OFF} (~1min.)"
echo ${ESC} "${BLUE}================================${OFF}"

cat >/etc/yum.repos.d/Instana-Product.repo <<EOF
[instana-product]
name=Instana-Product
baseurl=https://_:${AGENTKEY}@artifact-public.instana.io/artifactory/rel-rpm-public-virtual/
enabled=1
gpgcheck=0
gpgkey=https://_:${AGENTKEY}@artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-rpm-public-virtual
repo_gpgcheck=1
EOF

INSTANA_VERSION=""
LATEST_5=`yum -y --showduplicates list instana-console 2>/dev/null | tail -5 | sort -n | awk '{printf("%s ",$2)}'`
DEFAULT=`echo ${LATEST_5} | awk '{print $NF}'`

while test "${INSTANA_VERSION}" = ""
do
   echo
   echo "(Offering latest 5)"
   echo -n "Instana version? [${LATEST_5}] (<Enter> for ${DEFAULT})? "
   read ANS
   if test "${ANS}" = ""
   then
      ANS="${DEFAULT}"
   fi
   INSTANA_VERSION=${ANS}
done

############################################################

cat > /tmp/run_as_root.sh <<EOF1
#!/bin/sh

############################################################

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

############################################################

HOSTNAME=\`hostname -s\`

############################################################

localectl set-keymap de

############################################################

cat >/etc/yum.repos.d/Instana-Product.repo <<EOF2
[instana-product]
name=Instana-Product
baseurl=https://_:${AGENTKEY}@artifact-public.instana.io/artifactory/rel-rpm-public-virtual/
enabled=1
gpgcheck=0
gpgkey=https://_:${AGENTKEY}@artifact-public.instana.io/artifactory/api/security/keypair/public/repositories/rel-rpm-public-virtual
repo_gpgcheck=1
EOF2

############################################################

if test ! -d /instana_docker
then
   echo ${ESC} ""
   echo ${ESC} "\${BLUE}Adding 2nd disk for docker\${OFF}"
   echo ${ESC} "\${BLUE}==========================\${OFF}"
   vgcreate my_vg /dev/vdc 1>/dev/null 2>/dev/null
   lvcreate -l 100%FREE -n my_lv my_vg 1>/dev/null 2>/dev/null
   mkfs.xfs /dev/my_vg/my_lv 1>/dev/null 2>/dev/null
   mkdir -p /instana_docker 
   mount /dev/my_vg/my_lv /instana_docker 1>/dev/null 2>/dev/null
fi

############################################################

if test ! -f /etc/yum.repos.d/docker-ce.repo
then
   echo ${ESC} ""
   echo ${ESC} "\${BLUE}Installing Docker\${OFF}"
   echo ${ESC} "\${BLUE}=================\${OFF}"

   dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo 1>/dev/null 2>/dev/null
   rpm -e --nodeps podman-docker runc 1>/dev/null 2>/dev/null
   yum -y install docker-ce runc 1>/dev/null 2>/dev/null
   ln -s /instana_docker /var/lib/docker
fi

############################################################

RET=\`systemctl | egrep docker.service 2>/dev/null\`
if test "\${RET}" = ""
then
   echo ${ESC} ""
   echo ${ESC} "\${BLUE}Enabling and starting docker service\${OFF}"
   echo ${ESC} "\${BLUE}====================================\${OFF}"

   systemctl enable docker 1>/dev/null 2>/dev/null
   systemctl start docker 1>/dev/null 2>/dev/null
fi

############################################################

echo ${ESC} ""
echo ${ESC} "\${BLUE}Install Instana\${OFF} (~ 20 min.)"
echo ${ESC} "\${BLUE}===============\${OFF}"

mkdir -p /mnt/data /mnt/traces /mnt/metrics
openssl req -x509 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt -days 365 -nodes -subj "/CN=\${HOSTNAME}"

cd
yum install -y instana-console-${INSTANA_VERSION}

cat > /tmp/settings.hcl <<EOF2
type                    = "single"
profile                 = "normal"
tenant                  = "mytenant"
unit                    = "myidentifier"
agent_key               = "y"
download_key            = "${AGENTKEY}"
sales_key               = "${SALESKEY}"
host_name               = "\${HOSTNAME}"
token_secret            = "${TOKENSECRET}"
clickhouse_bind_address = ""

cert {
  crt = "/tmp/tls.crt"
  key = "/tmp/tls.key"
}

dir {
  metrics = "/mnt/metrics"
  traces  = "/mnt/traces"
  data    = "/mnt/data"
  logs    = "/var/log/instana"
}
seccomp_profile = "unconfined"

proxy {
  host     = ""
  port     = 0
  user     = ""
  password = ""
}

artifact_repository {
  repository_url = "https://artifact-public.instana.io/artifactory/shared/"
  user           = "_"
  password       = "${AGENTKEY}"
}

email {

  smtp {
    from      = ""
    host      = ""
    port      = 0
    user      = ""
    password  = ""
    use_ssl   = false
    start_tls = false
  }

  ses {
    from            = ""
    aws_access_key  = ""
    aws_access_id   = ""
    aws_return_path = ""
    aws_region      = ""
  }
}

o_auth {
  client_id     = ""
  client_secret = ""
}

docker_repository {
  base_url = "containers.instana.io"
  username = "_"
  password = "${AGENTKEY}"
}

feature "useInstanaSaasEumTrackingUrlEnabled" {
  enabled = true
}
feature "skipOnboardingDialog" {
  enabled = true
}
feature "fullTermsConfigEnabled" {
  enabled = true
}
feature "pcfEnabled" {
  enabled = true
}
feature "showUserSettingInternalTagsInUA" {
  enabled = true
}
feature "authenticationOidcEnabled" {
  enabled = true
}
feature "loggingEnabled" {
  enabled = false
}
feature "loggingEnabledOnTrace" {
  enabled = false
}
feature "beeinstanaInfraMetricsEnabled" {
  enabled = false
}
feature "highResolutionInfrastructureMetricsEnabled" {
  enabled = false
}
feature "infraMetricsWidgetEnabled" {
  enabled = false
}
feature "infraExplorePresentationEnabled" {
  enabled = false
}
feature "infraExploreDataEnabled" {
  enabled = false
}
feature "infrastructureExploreDataEnabled" {
  enabled = false
}
feature "agentMonitoringIssuesEnabled" {
  enabled = true
}
feature "newApCreationEnabled" {
  enabled = true
}
feature "applicationSmartAlertsEnabled" {
  enabled = true
}
feature "enableTroubleshootingMode" {
  enabled = true
}
feature "loggingInfratagsEnabled" {
  enabled = false
}

credential "adminApi" {
  user     = "InstanaAdminUser"
  password = "Password1%"
}
credential "serviceApi" {
  user     = "InstanaServiceUser"
  password = "Password1%"
}
credential "adminApi" {
  user     = "InstanaAdminUser"
  password = "Nhj56C6NXT"
}
credential "serviceApi" {
  user     = "InstanaServiceUser"
  password = "hc8yg2TEvD"
}
EOF2
instana init -y -f /tmp/settings.hcl | tee -a /tmp/instana_init.log

sleep 10
echo "Checking license"
instana license verify

cd /tmp
echo 
egrep '(Password|https|E-Mail)' instana_init.log | tee -a /root/account.txt
cat << EOF2

Rightbottom: Go to Instana!
Settings -> API Tokens -> Add API Token
Copy and append to /root/account.txt for future usage

EOF2

############################################################

echo -n "Wait for backend ready"
RET="x"
while test "\${RET}" != ""
do
   RET=\`timeout 5 curl https://localhost 2>&1 | egrep refused\`
   echo -n "."
   sleep 1
done
echo
echo
echo "Instana is up and running now!"
echo
EOF1
chmod 755 /tmp/run_as_root.sh

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Copying run_as_root.sh${OFF}"
echo ${ESC} "${BLUE}======================${OFF}"

PORT=`echo ${SSH_CONNECTION} | awk '{print $4}'`
HOST=`echo ${SSH_CONNECTION} | awk '{print $2}'`
sshpass -p "${ITZUSER_PASSWD}" scp -P ${PORT} /tmp/run_as_root.sh ${HOST}:/tmp 1>/dev/null 2>/dev/null

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Running run_as_root.sh${OFF}"
echo ${ESC} "${BLUE}======================${OFF}"

sshpass -p "${ITZUSER_PASSWD}" ssh -p ${PORT} ${HOST} sudo /tmp/run_as_root.sh


############################################################

echo "Visit ${VNC_URL} with itzuser / ${ITZUSER_PASSWD}"
echo "There, firefox://localhost"

