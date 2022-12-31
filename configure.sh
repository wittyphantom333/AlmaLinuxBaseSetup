#!/bin/bash
#Provided by adam@wittsgarage.com
#@wittyphantom333

function pause(){
   read -p "$*"
}

echo "=======================">>setup.log 2>>error.log
date>>setup.log 2>>error.log
echo "=======================">>setup.log 2>>error.log

echo "Detecting IP Address and Hostname"
IPADDY="$(hostname -I)"
HOSTNAMED="$(hostname)"
echo "Detected IP Address is $IPADDY and Hostname as $HOSTNAMED"

SERVERNAME=$HOSTNAMED
SERVERALIAS=$IPADDY

echo "Installind PreReqs"
yum install -y pwgen git nano screen wget >>setup.log 2>>error.log
