#!/usr/bin/env bash

# Set on every new instantiation
### TO BE FILLED: Please provide all cluster IPs
    # Node w/ first IP (i.e., "manager") must run script before the rest of the nodes
    # (instantiates a memcached to setup RDMA connections)
ORDERED_HOST_NAMES=(
  "apt120.apt.emulab.net"
  "apt102.apt.emulab.net"
  "apt115.apt.emulab.net"
  "apt099.apt.emulab.net"
  "apt103.apt.emulab.net"
)

# Include cloudlab_ssh_config in ssh
# assumes you have created a key w/ ssh-keygen (here named id_rsa_cloudlab)
# and already registered its public key on cloudlab

# set once
CONFIG_NAME="cloudlab_ssh_config"
CLOUDLAB_USERNAME="akats"
CLOUDLAB_SSHKEY_FILE="${HOME}/.ssh/id_rsa_cloudlab"
SSH_CONFIG="/home/akatsarakis/.ssh/config"
SSH_PREFIX="n"

# Create file
echo "# cloudlab config" > ${CONFIG_NAME}
echo " " >> ${CONFIG_NAME}
for i in "${!ORDERED_HOST_NAMES[@]}"; do
  echo "Host ${SSH_PREFIX}$((i+1))" >> ${CONFIG_NAME}
  echo "    User ${CLOUDLAB_USERNAME}" >> ${CONFIG_NAME}
  echo "    IdentityFile ${CLOUDLAB_SSHKEY_FILE}" >> ${CONFIG_NAME}
  echo "    HostName ${ORDERED_HOST_NAMES[i]}" >> ${CONFIG_NAME}
  echo " " >> ${CONFIG_NAME}
done

cp ${CONFIG_NAME} ~/.ssh/

# Include in ssh_config if it does not exist
if cat ~/.ssh/config | grep "Include ${CONFIG_NAME}" ; then
   echo "${CONFIG_NAME} is already included in your ${SSH_CONFIG}"
else
   echo "Including ${CONFIG_NAME} in your ${SSH_CONFIG}"

   cp ${SSH_CONFIG} ${SSH_CONFIG}_backup  # take a backup of ssh config
   echo "Include ${CONFIG_NAME}" > ${SSH_CONFIG}
   echo " " >> ${SSH_CONFIG}
   cat ${SSH_CONFIG}_backup >> ${SSH_CONFIG}
fi

##insert to known_hosts
for i in "${!ORDERED_HOST_NAMES[@]}"; do
  ssh-keyscan -H ${ORDERED_HOST_NAMES[i]} >> ~/.ssh/known_hosts
done

# copy id_rsa_cloudlab to internal nodes (to allow access/scp with each other)
# and init to setup their initial environment
SSH_REMOTE_SSHKEY="/users/${CLOUDLAB_USERNAME}/.ssh/id_rsa"
for i in "${!ORDERED_HOST_NAMES[@]}"; do
  scp ./init.sh ${SSH_PREFIX}$((i+1)):~/init.sh
  scp ${CLOUDLAB_SSHKEY_FILE} ${SSH_PREFIX}$((i+1)):${SSH_REMOTE_SSHKEY}
done
