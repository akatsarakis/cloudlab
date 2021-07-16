#!/usr/bin/env bash

# WARNING: Before executing this script make sure to have setup
#   ssh-key on github and cloudlab and have share it with executing node

# TODO: Set this variable below
NO_NODES="5" # WARNING: cannot be higher than number of allocated nodes in cloudlab

if [[ "${NO_NODES}" -gt 9 ]]; then
  echo "Current script supports up to 9 nodes"
  exit 1;
fi



# silence parallel citation without the manual "will-cite" after parallel --citation
mkdir ~/.parallel
touch ~/.parallel/will-cite

# Configure (2MB) huge-pages for the KVS
echo 4096 | sudo tee /sys/devices/system/node/node*/hugepages/hugepages-2048kB/nr_hugepages
echo 10000000001 | sudo tee /proc/sys/kernel/shmmax
echo 10000000001 | sudo tee /proc/sys/kernel/shmall

ssh-keyscan -H github.com >> ~/.ssh/known_hosts
git clone git@github.com:vasigavr1/dotfiles.git dotfiles
rm  ~/.bashrc
cd ~/dotfiles ; ./install ; cd ..
source ~/.bashrc


sleep 10 # if we try to init nic immediately it typically fails

# Setting the ip to the ib0 might not work on the first try so repeat
MAX_RETRIES=10
for i in `seq 1 ${MAX_RETRIES}`; do
  sudo ifconfig ib0 10.0.3.${HOSTNAME:5:1}/24 up
  if ibdev2netdev | grep "Up" ; then
    break
  fi
  sleep 5
done

if ibdev2netdev | grep "Up" ; then
  echo "IB0 is Up!"
else
  ibdev2netdev
  echo "IB0 is not Up --> setup failed!"
  exit 1
fi

# [Optionally] For dbg ensure everything was configured properly
#ibdev2netdev # --> must show ib0 (up)
#ifconfig --> expected ib0 w/ expected ip
#ibv_devinfo --> PORT_ACTIVE

#############################
# WARNING only on first node!
#############################
if [[ "${HOSTNAME:5:1}" == 1 ]]; then
    sleep 20 # give some time so that all peers have setup their NICs

    # start a subnet manager
    sudo /etc/init.d/opensmd start # there must be at least one subnet-manager in an infiniband subnet cluster


    git clone git@github.com:vasigavr1/Odyssey.git odyssey
    cd ~/odyssey/bin; ./install-latest-cmake.sh
    cd git-scripts;   ./init_submodules.sh
    cd ../.. ; cmake -B build


    # Add all cluster nodes to known hosts
    # WARNING: execute this only after all nodes have setup their NICs (i.e., ifconfig up above)
    for i in `seq 1 ${NO_NODES}`; do
      ssh-keyscan -H 10.0.3.${i} >> ~/.ssh/known_hosts
    done
else
  mkdir -p odyssey/build
fi