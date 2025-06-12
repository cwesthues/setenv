#!/bin/sh

if test -f /root/custom_config.txt
then
   . /root/custom_config.txt
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

. /etc/os-release

case ${ID_LIKE} in
*rhel*|*fedora*)
   ESC="-e"
;;
*debian*)
   ESC=""
;;
esac

############################################################

#https://github.ibm.com/technology-garage-dach/BAFA/tree/main
#https://www.redhat.com/en/blog/instructlab-tutorial-installing-and-fine-tuning-your-first-ai-model-part-2
#https://developer.ibm.com/tutorials/awb-contributing-knowledge-instructlab-granite/
#https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux/ai/trial

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Install figlet${OFF}"
echo ${ESC} "${BLUE}==============${OFF}"

case ${ID_LIKE} in
*rhel*|*fedora*)
   yum -y install figlet 1>/dev/null 2>/dev/null
;;
*debian*)
   apt -y install figlet 1>/dev/null 2>/dev/null
;;
esac

############################################################

figlet "Part  1 :"
cat <<EOF

MANUAL prereqs: Setup Techzone environment

https://techzone.ibm.com/search?searchbox="GPU"
# Delete all other filters
-> RHELAI 1.2 GPU

Request reservation:
https://techzone.ibm.com/my/reservations/create/66d0e3c2f2ce07001d511f52
Reserve now

Name: CWE RHELAI 1.2 GPU
Purpose: Pilot
Sales Opportunity number: 006Ka00000NZ5YSIA1    (BAFA)
Purpose description: tests
Preferred Geography: itz-vpc-01 - AMERICAS - us-south region - us-south-1 datacenter
VM Profile: 48 CPU, 240GB RAM, 2 x NVIDIA L40S 48 GB
"I agree..."
Submit...
(wait for ~10min.)

Get Public IP: xx.xx.xx.xx
Download SSH key

Update IP in custom_config.txt

Press <Enter> to continue>
EOF

read dummy

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Create ssh desktop link${OFF}"
echo ${ESC} "${BLUE}=======================${OFF}"

CAND="/mnt/hgfs/*/Users /media/*/Users"
LOC=""
for LOCX in ${CAND}
do
   if test -d ${LOCX}/ChristofWesthues
   then
      LOC="${LOCX}"
      break
   fi
done

KEY="${LOC}/ChristofWesthues/Downloads/pem_ibmcloudvsi_download.pem"

if test -f ${KEY}
then
   cp ${KEY} /root/.ssh/techzone.pem
   chmod 400 /root/.ssh/techzone.pem
fi

APP="techzone-ssh"
DESKTOP_LINK="/root/Desktop/${APP}.desktop"
cat << EOF > ${DESKTOP_LINK}
[Desktop Entry]
Type=Application
Terminal=true
Exec=ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP}
Name=${APP}
Icon=utilities-terminal
EOF
gio set ${DESKTOP_LINK} "metadata::trusted" true
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method 'org.gnome.Shell.Extensions.ReloadExtension' >/dev/null 2>&1
chmod 755 "${DESKTOP_LINK}"

############################################################

figlet "Part  2 :"
echo ${ESC} ""
echo ${ESC} "${BLUE}Activate RedHat ${GREEN}(~1 min.)${OFF}"
echo ${ESC} "${BLUE}===============${OFF}"

CMD="rhc connect --organization 13162754 --activation-key ilab-ibm-pilot"
START=`date +%s`
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}
END=`date +%s`
DUR=`expr ${END} - ${START}`
echo ${ESC} "${BLUE}Took ${DUR}s${OFF}"
echo ${ESC} ""

############################################################

figlet "Part  3 :"

echo ${ESC} ""
echo ${ESC} "${BLUE}podman login${OFF}"
echo ${ESC} "${BLUE}============${OFF}"

CMD="podman login -u=${RH_USER} -p=${RH_PASSWD} registry.redhat.io"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}cp /run/containers/0/auth.json /etc/ostree${OFF}"
echo ${ESC} "${BLUE}==========================================${OFF}"

CMD="cp /run/containers/0/auth.json /etc/ostree"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}bootc switch registry.redhat.io/rhelai1/bootc-nvidia-rhel9:1.3.1 ${GREEN}(~11 min.)${OFF}"
echo ${ESC} "${BLUE}================================================================${OFF}"

START=`date +%s`
CMD="bootc switch registry.redhat.io/rhelai1/bootc-nvidia-rhel9:1.3.1"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}
END=`date +%s`
DUR=`expr ${END} - ${START}`
echo ${ESC} "${BLUE}Took ${DUR}s${OFF}"
echo ${ESC} ""

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Reboot${OFF}"
echo ${ESC} "${BLUE}======${OFF}"

CMD="reboot -n"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}
sleep 5

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Wait for node to come back${OFF}"
echo ${ESC} "${BLUE}==========================${OFF}"

RET=""
while test "${RET}" = ""
do
   RET=`timeout 2 ssh -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo uname 2>/dev/null`
   echo -n "."
   sleep 2
done
echo

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Initializing ilab${OFF}"
echo ${ESC} "${BLUE}=================${OFF}"

CMD="ilab config init --non-interactive"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}

echo ${ESC} ""
echo ${ESC} "${BLUE}podman login${OFF}"
echo ${ESC} "${BLUE}============${OFF}"

CMD="podman login -u=${RH_USER} -p=${RH_PASSWD} registry.redhat.io"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}

############################################################

figlet "Part  4 :"
echo ${ESC} ""
echo ${ESC} "${BLUE}Downloading model granite-8b-starter-v1 ${GREEN}(~6 min.)${OFF}"
echo ${ESC} "${BLUE}=======================================${OFF}"

CMD="ilab model download --release latest --repository docker://registry.redhat.io/rhelai1/granite-8b-starter-v1"
START=`date +%s`
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}
END=`date +%s`
DUR=`expr ${END} - ${START}`
echo ${ESC} "${BLUE}Took ${DUR}s${OFF}"
echo ${ESC} ""

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Downloading model mixtral-8x7b-instruct-v0-1 ${GREEN}(~32 min.)${OFF}"
echo ${ESC} "${BLUE}============================================${OFF}"

CMD="ilab model download --release latest --repository docker://registry.redhat.io/rhelai1/mixtral-8x7b-instruct-v0-1"
START=`date +%s`
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}
END=`date +%s`
DUR=`expr ${END} - ${START}`
echo ${ESC} "${BLUE}Took ${DUR}s${OFF}"
echo ${ESC} ""

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Downloading model granite-8b-lab-v1 ${GREEN}(~6 min.)${OFF}"
echo ${ESC} "${BLUE}===================================${OFF}"

CMD="ilab model download --release latest --repository docker://registry.redhat.io/rhelai1/granite-8b-lab-v1"
START=`date +%s`
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}
END=`date +%s`
DUR=`expr ${END} - ${START}`
echo ${ESC} "${BLUE}Took ${DUR}s${OFF}"
echo ${ESC} ""

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Downloading model granite-3.1-8b-instruct-KW2 ${GREEN}(~19 min.)${OFF}"
echo ${ESC} "${BLUE}=============================================${OFF}"

CMD="ilab model download --repository rios1/granite-3.1-8b-instruct-KW2 --filename pytorch_model-Q4_K_M.gguf --hf-token ${HF_TOKEN}"
START=`date +%s`
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}
END=`date +%s`
DUR=`expr ${END} - ${START}`
echo ${ESC} "${BLUE}Took ${DUR}s${OFF}"
echo ${ESC} ""

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Executing 'ilab model list'${OFF}"
echo ${ESC} "${BLUE}===========================${OFF}"

CMD="ilab model list"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ${CMD}

############################################################

figlet "Part  5 :"

echo ${ESC} ""
echo ${ESC} "${BLUE}Generate random token${OFF}"
echo ${ESC} "${BLUE}=====================${OFF}"

TOKEN=`openssl rand -base64 32`
echo "Token is ${TOKEN}"

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Modifying ilab config${OFF}"
echo ${ESC} "${BLUE}=====================${OFF}"

MOD_TOKEN=`echo ${TOKEN} | sed s#"\\/"#"\\\\\/"#g`

cat > /tmp/change_config.sh <<EOF
#!/bin/sh
CONFIG="/root/.config/instructlab/config.yaml"
sed -i s/"  host_port: 127.0.0.1:8000"/"  host_port: 0.0.0.0:8080"/g \${CONFIG}
egrep  -v "\- '4'" \${CONFIG} > \${CONFIG}_NEW
mv \${CONFIG}_NEW \${CONFIG}
sed -i s/"- --tensor-parallel-size"/"- --tensor-parallel-size\n      - '1'\n      - --api-key\n      - ${MOD_TOKEN}"/g \${CONFIG}
EOF
chmod 755 /tmp/change_config.sh
scp -P ${PORT}  -i /root/.ssh/techzone.pem /tmp/change_config.sh ${USER}@${IP}:/tmp

CMD="/tmp/change_config.sh"
ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} "sudo \"${CMD}\""

############################################################

echo ${ESC} ""
echo ${ESC} "${BLUE}Serving model${OFF}"
echo ${ESC} "${BLUE}=============${OFF}"

gnome-terminal --title "Serve model" -e "bash -c \"echo -e \\\"\033]11;#DDFFFF\007\\\" ; ssh -t -p ${PORT} -i /root/.ssh/techzone.pem ${USER}@${IP} sudo ilab serve --backend vllm --gpus 1 --model-path /root/.cache/instructlab/models/rios1/granite-3.1-8b-instruct-KW2/ \"" 1>/dev/null 2>/dev/null &

echo ${ESC} ""
echo ${ESC} "${BLUE}Waiting for backend ready${OFF}"
echo ${ESC} "${BLUE}=========================${OFF}"

RET=""
while test "${RET}" = ""
do
RET=`curl http://${IP}:8080 2>/dev/null`
echo -n "."
sleep 1
done
echo
echo

############################################################

figlet "Part  6 :"

cat > /tmp/test_model.sh <<EOF
curl http://${IP}:8080/v1/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer ${TOKEN}' \
  -d '{
    "model": "/root/.cache/instructlab/models/rios1/granite-3.1-8b-instruct-KW2",
    "prompt": "Könnten Sie mir in einfachen Worten sagen, was der Text aussagt?",
    "max_tokens": 128,
    "temperature": 0.7,
    "stop": ["###"]
  }'
echo
echo
echo "<Enter> to close"
read dummy
EOF
chmod 755 /tmp/test_model.sh

echo
echo "Execute /tmp/test_model.sh"
echo

gnome-terminal --title "Test model" -e "bash -c \"echo -e \\\"\033]11;#DDDDDD\007\\\" ; /tmp/test_model.sh\"" 1/dev/null 2>/dev/null &

cat > /tmp/test_qna.sh <<EOF1
#!/bin/sh
while true
do
   echo -n "Your question: "
   read QUESTION
   echo
   echo "Answer:"
   cat > /tmp/curl_command.sh <<EOF2
curl http://${IP}:8080/v1/completions \\
   --header 'Content-Type: application/json' \\
   --header 'Authorization: Bearer ${TOKEN}' \\
   --data "{ \\
    \"model\": \"/root/.cache/instructlab/models/rios1/granite-3.1-8b-instruct-KW2\",\\
    \"prompt\": \"\${QUESTION}\",\\
    \"max_tokens\": 128,\\
    \"temperature\": 0.7,\\
    \"stop\": [\"###\"]\\
  }"
EOF2
   chmod 755 /tmp/curl_command.sh
   RESULT=\`/tmp/curl_command.sh 2>/dev/null\`

   echo \$RESULT | sed -e 's/\\\n/\\n/g' | egrep -v ^{
   echo
done
EOF1
chmod 755 /tmp/test_qna.sh

echo
echo "Execute /tmp/test_qna.sh"
echo

gnome-terminal --title "Test Q & A" -e "bash -c \"echo -e \\\"\033]11;#DDDDDD\007\\\" ; /tmp/test_qna.sh\"" 1/dev/null 2>/dev/null &
