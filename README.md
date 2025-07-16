---

# setenv

A collection of Client Engineering install/setup scripts
to quickly and easy deploy/recover.
Actually, there are 2 sections:

### Pilots:
  [weihenstephan.sh](Pilots/weihenstephan.sh)
  
  - **Purpose:** Setup all components for the PoC for Weihenstephan
  
  - **Input variables:** _IBMCLOUD_RESOURCE_GROUP IBMCLOUD_API_KEY_

### Techzone:
  [1_setup_techzone.sh](Techzone/1_setup_techzone.sh)

  - **Purpose:** Pre-script for all TechZone scenarios

  [2_install_Concert.sh](Techzone/2_install_Concert.sh)
   
  - **Purpose:** Setup an (OpenShift based) installation of IBM Concert on TechZone
  - **Input variables:** _API_URL BASTION_PASSWD SSH_CONNECTION CLUSTER_ADMIN_PWD TOKEN IBM_ENTITLEMENT_KEY_
   
  [2_install_Instana.sh](Techzone/2_install:Instana.sh)
  
  - **Purpose:** Setup a (single VM) installation of IBM Concert on TechZone
  - **Input variables:** _VNC_URL SSH_CONNECTION ITZUSER_PASSWD_

  [2_install_Turbonomic.sh](Techzone/2_install_Turbonomic.sh)
  
  - **Purpose:** Setup an (OpenShift based) installation of IBM Turbonomic on TechZone
  - **Input variables:** _API_URL BASTION_PASSWD SSH_CONNECTION CLUSTER_ADMIN_PWD TOKEN IBM_ENTITLEMENT_KEY_

### How and where to execute all that

All the scripts can be executed on a Linux based node, both x86_64 and aarch64, both RHEL and Ubuntu should work.

This could be any bare metal or VM node.

In addition, there is a docker/podman container [setenv](https://hub.docker.com/u/cwesthues) that automatically git-clones this repo at startup.

It can be used on a pure cmdline way, as well as serve noVNC/xfce4 on the local host.
___

**Graphical access:**

MacOS (ARM) 
```
podman run --name setenv -d -p 8080:8080 --replace docker.io/cwesthues/setenv
```
Linux
```
podman run --name setenv -d -p 8080:8080 --replace docker.io/cwesthues/setenv
```
Browse to : http://localhost:8080
___

**Cmdline access:**

Windows: 
```
docker run -ti docker.io/cwesthues/setenv /bin/bash
```
MacOS (ARM):
```
podman run -ti docker.io/cwesthues/setenv /bin/bash
```
Linux
```
podman run -ti docker.io/cwesthues/setenv /bin/bash
```
___

**Codeengine access:**

Create application:
   
  - Image reference: docker.io/cwesthues/setenv

  - CPU and memory: 0.5 vCPU / 2 GB   Ephem. storage 1.4

  - Min. number of instances: 1
      
  - Open URL: https://........codeengine.appdomain.cloud
___

Sample screenshots:

[On Windows](images/windows.jpg)

[On MacOS](images/MacOS.jpg)

___

cwesthues@de.ibm.com 2025/7/16
