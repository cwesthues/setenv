#!/bin/sh

PACKAGE="CE"
PREFIX="test1"    # only lowercase allowed!
IBMCLOUD_REGIONS="au-syd ca-tor eu-de us-south"
if test "${IBMCLOUD_DEFAULT_REGION}" = ""
then
   IBMCLOUD_DEFAULT_REGION="eu-de"
fi
DOC_DIR="../Weihenstephan"

############################################################

. /etc/os-release

case ${ID_LIKE} in
*rhel*|*fedora*)
   ESC="-e"
;;
esac

ARCH=`arch`
rm -rf /var/log/DONE
touch /var/log/DONE

############################################################

RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
OFF='\e[0;0m'

############################################################

if test "${IBMCLOUD_RESOURCE_GROUP}" = ""
then
   echo
   echo -n "IBMCLOUD_RESOURCE_GROUP: "
   read IBMCLOUD_RESOURCE_GROUP
   export IBMCLOUD_RESOURCE_GROUP
fi

if test "${IBMCLOUD_API_KEY}" = ""
then
   echo
   echo -n "IBMCLOUD_API_KEY: "
   read IBMCLOUD_API_KEY
   export IBMCLOUD_API_KEY
fi

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

if test -f /root/custom_config.txt
then
   . /root/custom_config.txt
fi

############################################################

install_SW_APIS () {
   RET=`which terraform 2>/dev/null`
   if test "${RET}" = ""
   then
      echo ${ESC} ""
      echo ${ESC} "${BLUE}Installing Terraform${OFF}"
      echo ${ESC} "${BLUE}====================${OFF}"

      case ${ID_LIKE} in
      *rhel*|*fedora*)
         yum install -y yum-utils 1>/dev/null 2>/dev/null
         yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo 1>/dev/null 2>/dev/null
         yum -y install terraform 1>/dev/null 2>/dev/null
      ;;
      *debian*)
         case ${ARCH} in
            x86_64) CPU="amd64";;
            aarch64) CPU="arm64";;
         esac
         apt update 1>/dev/null 2>/dev/null
         apt -y install curl gnupg2 jq 1>/dev/null 2>/dev/null
         curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - 1>/dev/null 2>/dev/null
         echo "deb [arch=${CPU}] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/hashicorp.list
         apt update 1>/dev/null 2>/dev/null
         apt -y install terraform 1>/dev/null 2>/dev/null
      ;;
      esac
   fi

   RET=`which ibmcloud 2>/dev/null`
   if test "${RET}" = ""
   then
      echo ${ESC} ""
      echo ${ESC} "${BLUE}Installing IBM CLI${OFF}"
      echo ${ESC} "${BLUE}==================${OFF}"

      cd /tmp
      case ${ARCH} in
         x86_64) CPU="amd64";;
         aarch64) CPU="arm64";;
      esac
      LATEST=`curl -L https://github.com/IBM-Cloud/ibm-cloud-cli-release/releases 2>/dev/null | egrep ${CPU}.tar.gz | sort -n | tail -1 | awk 'BEGIN{FS="\""}{print $2}'`
      curl -Lo IBM_Cloud_CLI.tar.gz "${LATEST}" 1>/dev/null 2>/dev/null
      tar -xf IBM_Cloud_CLI.tar.gz
      /tmp/Bluemix_CLI/install -q
#      for PLUGIN in catalogs-management schematics vpc-infrastructure secrets-manager monitoring cloud-dns-services code-engine
# watson dvaas
      for PLUGIN in cloud-object-storage
      do
         RET=`ls ${LOC}/SW/${PLUGIN}* 2>/dev/null`
         if test "${RET}" = ""
         then
            ibmcloud plugin install ${PLUGIN} -f 1>/dev/null 2>/dev/null
         else
            # ibmcloud plugin download ${PLUGIN} -d ${LOC}/SW
            ibmcloud plugin install ${RET} -f 1>/dev/null 2>/dev/null
         fi
      done
   fi
   RET=`which pip 2>/dev/null`
   if test "${RET}" = ""
   then
      echo ${ESC} ""
      echo ${ESC} "${BLUE}Installing pip${OFF}"
      echo ${ESC} "${BLUE}==============${OFF}"
      case ${ID_LIKE} in
      *rhel*|*fedora*)
         yum -y install pip 1>/dev/null 2>/dev/null
      ;;
      *debian*)
         apt -y install pip 1>/dev/null 2>/dev/null
      ;;
      esac
   fi
   RET=`which git 2>/dev/null`
   if test "${RET}" = ""
   then
      echo ${ESC} ""
      echo ${ESC} "${BLUE}Installing git${OFF}"
      echo ${ESC} "${BLUE}==============${OFF}"
      case ${ID_LIKE} in
      *rhel*|*fedora*)
         yum -y install git 1>/dev/null 2>/dev/null
      ;;
      *debian*)
         apt -y install git 1>/dev/null 2>/dev/null
      ;;
      esac   
   fi
}

############################################################

ibmcloud_login () {
   RET=`ibmcloud account list 2>/dev/null`
   if test "${RET}" = ""
   then
      echo ${ESC} ""
      echo ${ESC} "${BLUE}Login @ IBM-Cloud${OFF}"
      echo ${ESC} "${BLUE}=================${OFF}"
      ibmcloud login -r ${REGION} -q 2>/dev/null | egrep '(Account:|User:)'
      RET=`ibmcloud resource groups | egrep ${IBMCLOUD_RESOURCE_GROUP}`
      if test "${RET}" = ""
      then
         ibmcloud resource group-create ${IBMCLOUD_RESOURCE_GROUP} 1>/dev/null 2>/dev/null
      fi
      ibmcloud target -g ${IBMCLOUD_RESOURCE_GROUP} 1>/dev/null 2>/dev/null
      ibmcloud is target --gen 2 1>/dev/null 2>/dev/null
   fi
}

############################################################

cleanup () {
   echo ${ESC} "${BLUE}Cleaning up${OFF}"

   echo
   echo ${ESC} "${BLUE}   Look for apikeys${OFF}"
   ALL_APIKEYS=`ibmcloud iam api-keys 2>/dev/null | egrep ${PREFIX} | awk '{print $2}'`
   for APIKEY in ${ALL_APIKEYS}
   do
      echo "   Found apikey ${APIKEY}, deleting..."
      ibmcloud iam api-key-delete --force ${APIKEY} 1>/dev/null 2>/dev/null
   done

   echo
   echo ${ESC} "${BLUE}   Look for servicekeys${OFF}"
   ALL_SERVICEKEYS=`ibmcloud resource service-keys 2>/dev/null | egrep '('${PREFIX}'|WDP-|watsonx-data-do-not-delete|Auto-generated)' | awk '{print $1}'`
   for SERVICEKEY in ${ALL_SERVICEKEYS}
   do
      if test "${SERVICEKEY}" = "Auto-generated"
      then
         SERVICEKEY="Auto-generated service credentials"
      fi
      echo "   Found servicekey ${SERVICEKEY}, deleting..."
      ibmcloud resource service-key-delete "${SERVICEKEY}" --force 1>/dev/null 2>/dev/null
   done

   echo
   echo ${ESC} "${BLUE}   Look for service instances${OFF}"
   ALL_SERVICEINSTANCES=`ibmcloud resource service-instances 2>/dev/null | egrep ${PREFIX} | awk '{print $1}'`
   for SERVICEINSTANCE in ${ALL_SERVICEINSTANCES}
   do
      echo "   Found service instance ${SERVICEINSTANCE}, deleting..."
      ibmcloud resource service-instance-delete --force ${SERVICEINSTANCE} 1>/dev/null 2>/dev/null
   done

   rm -rf /var/log/DONE
   touch /var/log/DONE
}

############################################################

show_resources () {
   echo
   echo ${ESC} "${BLUE}Actual resources:${OFF}"
   ibmcloud resources | egrep "Name:" | awk '{print $2}' | egrep ^${PREFIX} | sort -n
   echo
}

############################################################

add_watsonx_ai_Studio () {
   echo ${ESC} "${BLUE}Create watsonx.ai Studio service ${PREFIX}-${DATE}-watsonx.ai-studio${OFF}"
   ibmcloud resource service-instance-create ${PREFIX}-${DATE}-watsonx.ai-studio data-science-experience free-v1 ${REGION} 
   echo -n "Wait for instance active"
   RET=""
   while test "${RET}" = ""
   do
      RET=`ibmcloud resource service-instances | egrep ${PREFIX}-${DATE}-watsonx.ai-studio | egrep active`
      echo -n "."
      sleep 1
   done
   echo
   ID=`ibmcloud resource service-instance ${PREFIX}-${DATE}-watsonx.ai-studio | egrep "^ID:" | awk '{print $2}'`
   echo
   echo ID is $ID
}

############################################################

add_watsonx_governance () {
   ANS=""
   if test "${ACTION}" = "do_all"
   then
      ANS="n"
   fi
   while test "${ANS}" != "y" -a "${ANS}" != "n"
   do
      echo
      echo -n ${ESC} "Do you want to do this step in ${RED}GUI${OFF}? [y|n] (<Enter> for 'n'): "
      read ANS
      if test "${ANS}" = ""
      then
         ANS="n"
      fi
   done

   case ${ANS} in
   y)
      cat <<EOF
Search resources and products: watsonx.governance
Select a location: ${REGION}
Service name:${PREFIX}-${DATE}-watsonx-governance
Select a resource group: ${IBMCLOUD_RESOURCE_GROUP}
I have read...
Create
EOF
      echo
      echo -n "Press <Enter> when ready"
      read ANS
   ;;
   n)
      echo
      echo ${ESC} "${BLUE}Create watsonx.governance service ${PREFIX}-${DATE}-watsonx-governance${OFF}"
      #ibmcloud resource service-instance-create ${PREFIX}-${DATE}-watsonx-governance aiopenscale lite ${REGION}
      echo "1" | ibmcloud resource service-instance-create ${PREFIX}-${DATE}-watsonx-governance aiopenscale lite ${REGION}
      echo -n "Wait for instance active"
      RET=""
      while test "${RET}" = ""
      do
         RET=`ibmcloud resource service-instances | egrep ${PREFIX}-${DATE}-watsonx-governance | egrep active`
         echo -n "."
         sleep 1
      done
      echo
      ID=`ibmcloud resource service-instance ${PREFIX}-${DATE}-watsonx-governance | egrep "^ID:" | awk '{print $2}'`
   echo
   echo ID is $ID
   ;;
   esac
   echo "add_watsonx_governance" >> /var/log/DONE
}

############################################################

add_watsonx_orchestrate () {
   ANS=""
   if test "${ACTION}" = "do_all"
   then
      ANS="n"
   fi
   while test "${ANS}" != "y" -a "${ANS}" != "n"
   do
      echo
      echo -n ${ESC} "Do you want to do this step in ${RED}GUI${OFF}? [y|n] (<Enter> for 'n'): "
      read ANS
      if test "${ANS}" = ""
      then
         ANS="n"
      fi
   done

   case ${ANS} in
   y)
      cat <<EOF
Search resources and products: watsonx.orchestrate
Select a location: ${REGION}
Service name:${PREFIX}-${DATE}-watsonx-orchestrate
Select a resource group: ${IBMCLOUD_RESOURCE_GROUP}
I have read...
Create
EOF
      echo
      echo -n "Press <Enter> when ready"
      read ANS
   ;;
   n)
      echo
      echo ${ESC} "${BLUE}Create watsonx Orchestrate service ${PREFIX}-${DATE}-watsonx-orchestrate${OFF}"
      ibmcloud resource service-instance-create ${PREFIX}-${DATE}-watsonx-orchestrate watsonx-orchestrate lite ${REGION}
      echo -n "Wait for instance active"
      RET=""
      while test "${RET}" = ""
      do
         RET=`ibmcloud resource service-instances | egrep ${PREFIX}-${DATE}-watsonx-orchestrate | egrep active`
         echo -n "."
         sleep 1
      done
      echo
      ID=`ibmcloud resource service-instance ${PREFIX}-${DATE}-watsonx-orchestrate | egrep "^ID:" | awk '{print $2}'`
   echo
   echo ID is $ID
   ;;
   esac
   echo "add_watsonx_orchestrate" >> /var/log/DONE
}

############################################################

add_watsonx_data () {
   echo
   echo "H I N T: This will take ~20-30 min. !!!"
   echo
   ANS=""
   if test "${ACTION}" = "do_all"
   then
      ANS="n"
   fi
   while test "${ANS}" != "y" -a "${ANS}" != "n"
   do
      echo
      echo -n ${ESC} "Do you want to do this step in ${RED}GUI${OFF}? [y|n] (<Enter> for 'n'): "
      read ANS
      if test "${ANS}" = ""
      then
         ANS="n"
      fi
   done

   case ${ANS} in
   y)
      cat <<EOF
Search resources and products: watsonx.data
Select a location: ${REGION}
Service name:${PREFIX}-${DATE}-watsonx-data
Select a resource group: ${IBMCLOUD_RESOURCE_GROUP}
Select a use case: Generative AI
I have read...
Create
EOF
      echo
      echo -n "Press <Enter> when ready"
      read ANS
   ;;
   n)
      echo
      echo ${ESC} "${BLUE}Create watsonx.data service ${PREFIX}-${DATE}-watsonx-data${OFF}"
      ibmcloud resource service-instance-create ${PREFIX}-${DATE}-watsonx-data lakehouse lite ${REGION} --parameters '{"use_case":"ai"}'
      echo -n "Wait for instance active"
      RET=""
      while test "${RET}" = ""
      do
         RET=`ibmcloud resource service-instances | egrep ${PREFIX}-${DATE}-watsonx-data | egrep active`
         echo -n "."
         sleep 30
      done
      echo
      ID=`ibmcloud resource service-instance ${PREFIX}-${DATE}-watsonx-data | egrep "^ID:" | awk '{print $2}'`
   echo
   echo ID is $ID
   ;;
   esac
   echo "add_watsonx_data" >> /var/log/DONE
}

############################################################

add_watsonx_ai_Runtime () {
   echo
   echo ${ESC} "${BLUE}Create watsonx.ai Runtime service ${PREFIX}-${DATE}-watsonx.ai-runtime${OFF}"
   ibmcloud resource service-instance-create ${PREFIX}-${DATE}-watsonx.ai-runtime pm-20 v2-standard ${REGION}
   echo -n "Wait for instance active"
   RET=""
   while test "${RET}" = ""
   do
      RET=`ibmcloud resource service-instances | egrep ${PREFIX}-${DATE}-watsonx.ai-runtime | egrep active`
      echo -n "."
      sleep 1
   done
   echo
   ID=`ibmcloud resource service-instance ${PREFIX}-${DATE}-watsonx.ai-runtime | egrep "^ID:" | awk '{print $2}'`
echo
echo ID is $ID
}

############################################################

add_prompt_lab () {
   echo 
   echo ${ESC} "${RED}This functionality ONLY works in GUI (at the moment).${OFF}"
   echo

   cat <<EOF
Navigation Menu -> Resource list
AI / Machine Learning
Select ${PREFIX}-xxhxxmxx-watsonx-runtime
Launch in IBM watsonx
Open Prompt Lab
Save as
Select 'Prompt template'
Name: ${PREFIX}-${DATE}-watsonx-prompt-lab
Task: Retrieval-Augmented Generation
Save
EOF
   echo
   echo -n "Press <Enter> when ready"
   read ANS
   echo "add_prompt_lab" >> /var/log/DONE
}

############################################################

add_assistant_builder () {
   echo 
   echo ${ESC} "${RED}This functionality ONLY works in GUI (at the moment).${OFF}"
   echo

   cat <<EOF
Navigation Menu -> Resource list
AI / Machine Learning
Select ${PREFIX}-xxhxxmxx-watsonx-orchestrate
Launch watsonx Orchestrate
Navigation Menu -> Build -> Assistant Builder
Assistant name: ${PREFIX}-${DATE}-assistant
Assistant languege: German
Next
Where do you plan on deploying your assistant: Web
Which industry do you work in: Other
Enter your industry here: Marketing
What is your role on the team building the assistant: Other
Enter your role here: Marketer
Which statement describes your needs best: Not sure at this time.
Next
Enable Streaming: On
Next
Create
EOF
   echo
   echo -n "Press <Enter> when ready"
   read ANS
   echo "add_assistant_builder" >> /var/log/DONE
}

############################################################

setup_cos () {
   echo
   echo ${ESC} "${BLUE}Create cos instance ${PREFIX}-${DATE}-cosinstance-${DATE}${OFF}"
   ibmcloud resource service-instance-create -d premium-global-deployment ${PREFIX}-${DATE}-cosinstance-${DATE} cloud-object-storage Standard global 1>/dev/null 2>/dev/null

   echo
   echo ${ESC} "${BLUE}Get and set CRN${OFF}"
   CRN=`ibmcloud resource service-instance ${PREFIX}-${DATE}-cosinstance-${DATE} --id 2>/dev/null | egrep -v service | awk '{print $2}'`
   ibmcloud cos config crn --crn ${CRN} --force 1>/dev/null 2>/dev/null
   ibmcloud cos config region --region ${REGION} 1>/dev/null 2>/dev/null

   echo
   echo ${ESC} "${BLUE}Create cos bucket ${PREFIX}-${DATE}-cosbucket${OFF}"
   ibmcloud cos bucket-create --bucket ${PREFIX}-${DATE}-cosbucket --class Standard --region ${REGION} 1>/dev/null 2>/dev/null

   echo
   echo ${ESC} "${BLUE}Upload file watsonx_simple.sh to bucket ${PREFIX}-${DATE}-cosbucket${OFF}"
   ibmcloud cos upload --bucket ${PREFIX}-${DATE}-cosbucket --key watsonx_simple.sh --file /mnt/hgfs/C/work/watsonx_simple.sh 1>/dev/null 2>/dev/null

   echo
   echo ${ESC} "${BLUE}Create servicekey ${PREFIX}-${DATE}-servicekey${OFF}"
   ibmcloud resource service-key-create ${PREFIX}-${DATE}-servicekey Manager --instance-name ${PREFIX}-${DATE}-cosinstance --parameters '{"HMAC":true}' 2>/dev/null 1>/tmp/key_$$.txt
   ACCESS_KEY=`egrep " access_key_id:" /tmp/key_$$.txt | awk '{print $2}'`
   SECRET_ACCESS_KEY=`egrep " secret_access_key:" /tmp/key_$$.txt | awk '{print $2}'`
   PUBLIC_ENDPOINT="s3.${REGION}.cloud-object-storage.appdomain.cloud"
   echo "   ACCESS_KEY: ${ACCESS_KEY}"
   echo "   SECRET_ACCESS_KEY: ${SECRET_ACCESS_KEY}"
   echo "   PUBLIC_ENDPOINT: ${PUBLIC_ENDPOINT}"
}

############################################################

setup_cos_watsonxai_studio_watsonxai_runtime_project () {
   ANS=""
   if test "${ACTION}" = "do_all"
   then
      ANS="n"
   fi
   while test "${ANS}" != "y" -a "${ANS}" != "n"
   do
      echo
      echo -n ${ESC} "Do you want to do this step in ${RED}GUI${OFF}? [y|n] (<Enter> for 'n'): "
      read ANS
      if test "${ANS}" = ""
      then
         ANS="n"
      fi
   done

   case ${ANS} in
   y)
      LC_ALL=C
      UUID=`tr -dc 'a-z0-9' </dev/urandom | head -c 15`
      cat <<EOF
COS:
   Navigation Menu -> Infrastructure -> Storage > Object Storage
   Create an instance
   Service name: ${PREFIX}-${DATE}-cos
   Select a resource group: ${IBMCLOUD_RESOURCE_GROUP}
   Create
   Create bucket
   Create a Custom Bucket -> Create
   Unique bucket name:
   ${PREFIX}${DATE}${PREFIX}${DATE}project-donotdelete-pr-${UUID}
   Location: ${REGION}
   Create bucket
watsonx.ai Studio:
   Search resources and products: watsonx.ai Studio
   Select a location: ${REGION}
   Service name: ${PREFIX}-${DATE}-watsonx-studio
   Select a resource group: ${IBMCLOUD_RESOURCE_GROUP}
   I have read...
   Create
watsonx.ai Runtime:
   Search resources and products: watsonx.ai Runtime
   Select a location: ${REGION}
   Service name: ${PREFIX}-${DATE}-watsonx-runtime
   Select a resource group: ${IBMCLOUD_RESOURCE_GROUP}
   I have read...
   Create
Project:
   Navigation Menu -> Resource list
   AI / Machine Learning
   Select either ${PREFIX}-xxhxxmxx-watsonx-studio or ${PREFIX}-xxhxxmxx-watsonx-runtime
   Launch in IBM watsonx
   Navigation Menu -> Projects -> View all projects
   New project
   Name: ${PREFIX}-${DATE}-project-basic
   Select Cloud Object Storage instance from the list
   ${PREFIX}-${DATE}-cos
   Create
EOF
      echo
      echo -n "Press <Enter> when ready"
      read ANS
   ;;
   n)
      echo
      echo ${ESC} "${BLUE}Setup terraform-ibm-watsonx-ai (COS & watsonx.ai Studio & watsonx.ai Runtime)${OFF}"
      # Based upon:
      # https://github.com/terraform-ibm-modules/terraform-ibm-watsonx-ai
      cd
      rm -rf terraform-ibm-watsonx-ai
      git clone https://github.com/terraform-ibm-modules/terraform-ibm-watsonx-ai
      cd terraform-ibm-watsonx-ai/examples/basic
      #cd terraform-ibm-watsonx-ai/examples/complete
      mv variables.tf variables.tf_ORIG
      cat > variables.tf <<EOF
variable "ibmcloud_api_key" {
  description = "The IBM Cloud API Key."
  sensitive   = true
  type        = string
  default     = "${IBMCLOUD_API_KEY}"
}

variable "prefix" {
  type        = string
  description = "Prefix for the name of all resource created by this example."
  default     = "${PREFIX}-${DATE}"

  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "region" {
  type        = string
  description = "Region to provision all resources created by this example."
  default     = "${REGION}"
}

variable "resource_group" {
  type        = string
  description = "The name of a new or an existing resource group where the resources are created."
  default     = "${IBMCLOUD_RESOURCE_GROUP}"
}

variable "resource_tags" {
  description = "Optional list of tags to describe the service instances created by the module."
  type        = list(string)
  default     = []
}
EOF
      mv main.tf main.tf_ORIG
      cat > main.tf <<EOF
##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.2.0"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "\${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

module "cos" {
  source            = "terraform-ibm-modules/cos/ibm//modules/fscloud"
  version           = "9.0.4"
  resource_group_id = module.resource_group.resource_group_id
  cos_instance_name = "\${var.prefix}-cos"
  cos_plan          = "standard"
}

############################################################################################
# Create watsonx.ai project without KMS encryption
############################################################################################

data "ibm_iam_auth_token" "restapi" {}


module "watsonx_ai" {
  source                    = "../.."
  region                    = var.region
  resource_tags             = var.resource_tags
  resource_group_id         = module.resource_group.resource_group_id
  project_name              = "\${var.prefix}-project-basic"
  watsonx_ai_runtime_instance_name = "\${var.prefix}-watsonx-runtime"
  watsonx_ai_studio_instance_name = "\${var.prefix}-watsonx-studio"
  watsonx_ai_studio_plan    = "professional-v1"
  watsonx_ai_runtime_plan   = "v2-standard"
  enable_cos_kms_encryption = false
  cos_instance_crn          = module.cos.cos_instance_crn
}
EOF

      terraform init
      terraform apply -auto-approve
   ;;
   esac
   echo "setup_cos_watsonxai_studio_watsonxai_runtime_project" >> /var/log/DONE
}

############################################################

upload_to_cos () {
   COS_INSTANCE_NAME=`ibmcloud resource service-instances | egrep ${PREFIX} | egrep cos | awk '{print $1}'`
   COS_INSTANCE_ID=`ibmcloud resource service-instance ${COS_INSTANCE_NAME} | egrep ^ID: | awk '{print $2}'`
   COS_BUCKET=`ibmcloud cos buckets --json --ibm-service-instance-id "${COS_INSTANCE_ID}" | fgrep \"Name\": | awk 'BEGIN{FS="\""}{print $4}'`

   ANS=""
   if test "${ACTION}" = "do_all"
   then
      ANS="n"
   fi
   while test "${ANS}" != "y" -a "${ANS}" != "n"
   do
      echo
      echo -n ${ESC} "Do you want to do this step in ${RED}GUI${OFF}? [y|n] (<Enter> for 'n'): "
      read ANS
      if test "${ANS}" = ""
      then
         ANS="n"
      fi
   done

   case ${ANS} in
   y)
      cat <<EOF
Navigation Menu -> Resource list
Storage -> ${COS_INSTANCE_NAME}
Select ${COS_BUCKET}
Upload
Upload files
Navigate to ${LOC}/${DOC_DIR}
Select all *.doc* files
Upload
EOF
      echo
      echo -n "Press <Enter> when ready"
      read ANS
   ;;
   n)
      echo
      echo
      echo ${ESC} "${BLUE}Upload to COS${OFF}"

      echo "COS_INSTANCE_NAME: ${COS_INSTANCE_NAME}"
      echo "COS_INSTANCE_ID: ${COS_INSTANCE_ID}"
      echo "COS_BUCKET: ${COS_BUCKET}"

      echo
      for FILE in `ls ${LOC}/${DOC_DIR}/*.doc* | sed s/" "/"###"/g`
      do
         STRING=`echo ${FILE} | sed s/"###"/" "/g`
         BASE=`basename "${STRING}"`
         echo "Uploading ${BASE}"
         ibmcloud cos upload --bucket "${COS_BUCKET}" --key "${BASE}" --file "${STRING}" --region ${REGION} 1>/dev/null 2>/dev/null
      done
   ;;
   esac
   echo "upload_to_cos" >> /var/log/DONE
}

############################################################

select_region () {
   echo ${ESC} ""
   echo ${ESC} "${BLUE}Select region you want to setup${OFF}"
   echo ${ESC} "${BLUE}===============================${OFF}"

   echo
   REGION=""
   while test "${REGION}" = ""
   do
      echo "${IBMCLOUD_REGIONS}" | awk '{for(i=1;i<=NF;i++){printf("%s\n",$i)}}' | tee -a /tmp/$$.regions
      HEAD=`head -1 /tmp/$$.regions | awk '{print $1}'`
      TAIL=`tail -1 /tmp/$$.regions | awk '{print $1}'`
      echo
      echo -n "Select region [${HEAD} - ${TAIL}] (<Enter> for '${IBMCLOUD_DEFAULT_REGION}'): "
      read REGION
      if test "${REGION}" = ""
      then
         REGION="${IBMCLOUD_DEFAULT_REGION}"
      fi
   done
}

############################################################

install_SW_APIS
ibmcloud_login
select_region

while true
do
   DATE=`date +%Hh%Mm%S`
   ACTION=""
   while test "${ACTION}" = ""
   do
      for CHECK in setup_cos_watsonxai_studio_watsonxai_runtime_project upload_to_cos add_watsonx_governance add_watsonx_orchestrate add_prompt_lab add_assistant_builder add_watsonx_data
      do
         if test "`egrep ${CHECK} /var/log/DONE`" != ""
         then
            eval DONE_${CHECK}="\${GREEN}\(done\)\${OFF}"
         fi
      done
      echo ${ESC} ""
      echo ${ESC} "   1 Cleanup"
      echo ${ESC} "   2 Show all current resources"
      echo ${ESC} "   3 Setup COS & watsonx.ai Studio & watsonx.ai Runtime & Project ${DONE_setup_cos_watsonxai_studio_watsonxai_runtime_project}"
      echo ${ESC} "   4 Upload data to COS ${DONE_upload_to_cos}"
      echo ${ESC} "   5 Add watsonx.governance ${DONE_add_watsonx_governance}"
      echo ${ESC} "   6 Add watsonx Orchestrate ${DONE_add_watsonx_orchestrate}"
      echo ${ESC} "   7 Add watsonx.data ${DONE_add_watsonx_data}"
      echo ${ESC} "   8 Add Prompt Lab (GUI) ${DONE_add_prompt_lab}"
      echo ${ESC} "   9 Add Assistant Builder (GUI) ${DONE_add_assistant_builder}"
      echo ${ESC} ""
      echo ${ESC} "  42 The answer to everything (DO ALL)"
      echo ${ESC} ""
      echo -n "   Which action do you want to run? [1-8|42]? "
      read ANS
      case ${ANS} in
         1)  ACTION="cleanup" ;;
         2)  ACTION="show_resources" ;;
         3)  ACTION="setup_cos_watsonxai_studio_watsonxai_runtime_project" ;;
         4)  ACTION="upload_to_cos";;
         5)  ACTION="add_watsonx_governance";;
         6)  ACTION="add_watsonx_orchestrate";;
         7)  ACTION="add_watsonx_data";;
         8)  ACTION="add_prompt_lab";;
         9)  ACTION="add_assistant_builder";;
         42) ACTION="do_all";;
      esac
   done
   case ${ACTION} in
   cleanup)
      cleanup
   ;;
   show_resources)
      show_resources
   ;;
   setup_cos_watsonxai_studio_watsonxai_runtime_project)
     setup_cos_watsonxai_studio_watsonxai_runtime_project
   ;;
   upload_to_cos)
      upload_to_cos
   ;;
   add_watsonx_governance)
      add_watsonx_governance
   ;;
   add_watsonx_orchestrate)
      add_watsonx_orchestrate
   ;;
   add_watsonx_data)
      add_watsonx_data
   ;;
   add_prompt_lab)
      add_prompt_lab
   ;;
   add_assistant_builder)
      add_assistant_builder
   ;;
   do_all)
      cleanup
      setup_cos_watsonxai_studio_watsonxai_runtime_project
      upload_to_cos
      add_watsonx_governance
      add_watsonx_orchestrate
      add_watsonx_data
   ;;
   esac
done

############################################################
