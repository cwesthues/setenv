A collection of Client Engineering install/setup scripts
to quickly and easy deploy/recover.
Actually, there are 2 sections:

Pilots:
  weihenstephan.sh
   Purpose: Setup all components for the PoC for Weihenstephan
   Input variables:
      IBMCLOUD_RESOURCE_GROUP   IBMCLOUD_API_KEY

TechZone:
   
   1_setup_techzone.sh
     Purpose: Pre-script for all TechZone scenarios


   2_install_Concert.sh
     Purpose: Setup an (OpenShift based) installation of IBM Concert on TechZone
   Input variables:
     API_URL BASTION_PASSWD SSH_CONNECTION CLUSTER_ADMIN_PWD TOKEN IBM_ENTITLEMENT_KEY

   2_install_Instana.sh
     Purpose: Setup a (single VM) installation of IBM Concert on TechZone
   Input variables:
     VNC_URL SSH_CONNECTION ITZUSER_PASSWD


   2_install_Turbonomic.sh
     Purpose: Setup an (OpenShift based) installation of IBM Turbonomic on TechZone
   Input variables:
     API_URL BASTION_PASSWD SSH_CONNECTION CLUSTER_ADMIN_PWD TOKEN IBM_ENTITLEMENT_KEY




        G R A P H I C A L    A C C E S S
   MacOS (ARM):
      podman run --name setenv -d -p 8080:8080 --replace docker.io/cwesthues/setenv
   Linux:
      podman run --name setenv -d -p 8080:8080 --replace docker.io/cwesthues/setenv
   Browse to : http://localhost:8080

   C M D L I N E    A C C E S S
   Windows:
      docker run -ti docker.io/cwesthues/setenv /bin/bash
   MacOS (ARM):
      podman run -ti docker.io/cwesthues/setenv /bin/bash
   Linux:
      podman run -ti docker.io/cwesthues/setenv /bin/bash

   C O D E E N G I N E    A C C E S S
   Create application:
      Image reference: docker.io/cwesthues/setenv
      CPU and memory: 0.5 vCPU / 2 GB   Ephem. storage 1.4
      Min. number of instances: 1
   Open URL: https://........codeengine.appdomain.cloud/














A **gateway** to run LSF-CE or SLURM **workload** (‚jobs‘) on (dynamic) IBM **CodeEngine instances**


This script is going to install LSF-CE and SLURM on the local host
as a master node. A gateway is installed to forward LSF/SLURM jobs
as CodeEngine jobs, which is essentially starting a CE docker/k8s
instance and execute the workload there. Furthermore, file exchange
is done through mounting a COS bucket.

In addition, this script can setup a CodeEngine Application 'cemaster'
that can act as a master for LSF/SLURM, access is through guacamole.

The short cut:

To download the script itself:
```
curl -fsSLo install_cemaster_onprem.sh  https://raw.github.ibm.com/cwesthues/cemaster/main/install_cemaster_onprem.sh?token=GHSAT0AAAAAAACIZSSA2R737EV2VNEH35MMZZHOJIA

```
To execute the script directly:

As root:
```
curl -fsSL https://raw.github.ibm.com/cwesthues/cemaster/main/install_cemaster_onprem.sh?token=GHSAT0AAAAAAACIZSSA2R737EV2VNEH35MMZZHOJIA | sh
```
As non-root:
```
curl -fsSL https://raw.github.ibm.com/cwesthues/cemaster/main/install_cemaster_onprem.sh?token=GHSAT0AAAAAAACIZSSA2R737EV2VNEH35MMZZHOJIA | sudo sh
```

To allow CodeEngine instances to be launched, specify upfront:

```
export IBMCLOUD_API_KEY="xxxxxxxxxxxxxxxxxxxxxxx"
export IBMCLOUD_RESOURCE_GROUP="xxx"
export IBMCLOUD_REGION="xx-xx"
export IBMCLOUD_PROJECT="xxxxx"
```
To allow COS mounts, specify upfront:

```
export COSBUCKET="xxxxxxxxxxxxx"
export ACCESS_KEY_ID="xxxxxxxxxxxxxxxxxxxxxxxxxx"
export SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxx"
```
To create new docker images, specify upfront:
```
export CREATE_IMAGES="y"
```
To create a cemaster instance, specify upfront:
```
export CREATE_CEMASTER_INSTANCE="y"
```
You can put all these envvar settings into <cwd>/.ce-gateway.conf
  
A short PDF with screenshots can be found [here](https://github.ibm.com/cwesthues/cemaster/blob/main/LSF-CodeEngine-Gateway.pdf).

cwesthues@de.ibm.com 2024/10/23
