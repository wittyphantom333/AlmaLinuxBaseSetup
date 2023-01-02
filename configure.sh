#!/bin/bash
#Provided by adam@wittsgarage.com
#@wittyphantom333

function pause() {
   read -p "$*"
}

echo "=======================" >>setup.log 2>>error.log
date >>setup.log 2>>error.log
echo "=======================" >>setup.log 2>>error.log

echo "Detecting IP Address and Hostname"
IPADDY="$(hostname -I)"
SERVERNAME="$(hostname)"

if [[ $SERVERNAME == *"localhost"* ]]; then
   echo "Setting IP Hostname"
   SRVSTR= echo $RANDOM | base64 | head -c 20
   echo ""
   SERVERNAME= echo "app_server_$SERVERNAME"
   hostnamectl set-hostname $SERVERNAME
else
   echo "Server already renamed"
fi

if [[ -n $1 ]]; then
   SERVERNAME=$1
   echo "Server name found.  Setting to $SERVERNAME"
   hostnamectl set-hostname $SERVERNAME
   #read -p 'Username: ' USERVAR
   #else
   #read -p 'Username: ' USERVAR
fi

USER_NAME=$USERVAR

echo "Updating Repositories"
yum update >>setup.log 2>>error.log

echo "Installing PreReqs"
yum install -y tar git nano wget npm >>setup.log 2>>error.log

echo "Installing epel-release"
yum install -y epel-release >>setup.log 2>>error.log

echo "Installing ccache"
yum install -y ccache >>setup.log 2>>error.log
ccache --max-size=5G

echo "Installing Cockpit"
yum install -y cockpit >>setup.log 2>>error.log
systemctl start cockpit >>setup.log 2>>error.log
systemctl enable cockpit >>setup.log 2>>error.log

echo "Installing MariaDB"
yum install -y mariadb-server >>setup.log 2>>error.log
systemctl start mariadb >>setup.log 2>>error.log
systemctl enable mariadb >>setup.log 2>>error.log

echo "Installing Apps"
yum install -y git-lfs tuned cockpit-storaged cockpit-pcp cockpit-session cockpit-packagekit cockpit-doc cpupowerutils dnf-automatic >>setup.log 2>>error.log

echo "Disabling SELinux"
sed -i -e "s|SELINUX=enforcing|SELINUX=disabled|" /etc/selinux/config >>setup.log 2>>error.log

echo "Enabling auto updates"
sed -i -e "s|apply_updates = no|apply_updates = yes|" /etc/dnf/automatic.conf >>setup.log 2>>error.log
systemctl enable --now dnf-automatic-notifyonly.timer >>setup.log 2>>error.log

echo "Setting up live patching"
yum install -y git gcc kernel-devel elfutils elfutils-devel rpmdevtools pesign yum-utils zlib-devel binutils-devel newt-devel python-devel perl-ExtUtils-Embed audit-libs-devel numactl-devel pciutils-devel bison >>setup.log 2>>error.log
git clone https://github.com/dynup/kpatch.git && cd kpatch && make install && make -C kpatch-build install >>setup.log 2>>error.log

echo "Installing live patching kernel tools"
yum install -y asciidoc bc hmaccalc net-tools xmlto ncurses-devel >>setup.log 2>>error.log
yum --enablerepo base-debuginfo install kernel-debuginfo -y >>setup.log 2>>error.log

echo "Enabling live kernel updates"
yum kpatch auto >>setup.log 2>>error.log

echo "Restarting services"
systemctl restart polkit >>setup.log 2>>error.log
systemctl restart auditd >>setup.log 2>>error.log

echo "Boosting CPU to max frequency"
systemctl enable --now tuned >>setup.log 2>>error.log
tuned-adm profile throughput-performance >>setup.log 2>>error.log
cpupower frequency-set -g performance >>setup.log 2>>error.log

# echo "Installing Netdata Monitoring Software"
#wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh --claim-token CCqBjXCMf3SAbaFysiEwOmqpauPxea7k0ZXw1VZrP3M8x4KF6xAukgvIDM_l7kkCVQ2zwFtSxGImUR3n-ExWbtoM4iKWOIkTQVNhbDrreOwKg5D-PYmQNdbM7X6W29JRiD7jwJM --claim-url https://app.netdata.cloud

# create random password
PASSWDDB="$(openssl rand -base64 12)"

# replace "-" with "_" for database username
MAINDB=${SERVERNAME//[^a-zA-Z0-9]/_}

if [ -d /var/lib/mysql/$MAINDB ]; then
   echo "Database Exists"
   mysql -e "ALTER USER '${MAINDB}'@'%' IDENTIFIED BY '${PASSWDDB}';"
   mysql -e "GRANT ALL PRIVILEGES ON ${MAINDB}.* TO '${MAINDB}'@'%';"
   mysql -e "GRANT GRANT OPTION ON ${MAINDB}.* TO '${MAINDB}'@'%';"
   mysql -e "FLUSH PRIVILEGES;"
else
   echo "creating database $MAINDB"
   mysql -e "CREATE DATABASE ${MAINDB} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
   mysql -e "CREATE USER '${MAINDB}'@'%' IDENTIFIED BY '${PASSWDDB}';"
   mysql -e "GRANT ALL PRIVILEGES ON ${MAINDB}.* TO '${MAINDB}'@'%';"
   mysql -e "FLUSH PRIVILEGES;"
fi

echo "Making Directories"
if [[ -d /home/fivem ]]; then
   if [[ -d /home/fivem/fx-server ]]; then
      if [[ -d /home/fivem/fx-server-data ]]; then
         echo "Folder structure already configured"
      else
         mkdir /home/fivem/fx-server-data
         echo "Directories created"
      fi
   else
      mkdir /home/fivem/fx-server
      mkdir /home/fivem/fx-server-data
      echo "Directories created"
   fi
else
   mkdir /home/fivem
   mkdir /home/fivem/fx-server
   mkdir /home/fivem/fx-server-data
   echo "Directories created"
fi

echo "Removing old cfx server files"
rm -R /home/fivem/fx-server/alpine >>setup.log 2>>error.log
echo "Downloading latest artifacts"
wget https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/6183-eab7a55b8f98149ac76af234107e2952c13d4cbb/fx.tar.xz >>setup.log 2>>error.log
echo "Extracting files"
tar -xvf fx.tar.xz -C /home/fivem/fx-server/ >>setup.log 2>>error.log
echo "Cleaning up downloads"
rm fx.tar.xz >>setup.log 2>>error.log

if ! [ -x "$(command -v pm2)" ]; then
   echo "Installing PM2"
   npm install -g pm2 >>setup.log 2>>error.log
fi

echo "Enabling MySQL remote access"
sed -i -e "s|#bind-address=0.0.0.0|bind-address=0.0.0.0|" /etc/my.cnf.d/mariadb-server.cnf >>setup.log 2>>error.log
systemctl restart mysql >>setup.log 2>>error.log

if ! [ -x "$(command -v netdata)" ]; then
   echo "Installing Netdata monitoring"
   wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh --claim-token CCqBjXCMf3SAbaFysiEwOmqpauPxea7k0ZXw1VZrP3M8x4KF6xAukgvIDM_l7kkCVQ2zwFtSxGImUR3n-ExWbtoM4iKWOIkTQVNhbDrreOwKg5D-PYmQNdbM7X6W29JRiD7jwJM --claim-url https://app.netdata.cloud >>setup.log 2>>error.log
fi

echo "Configuring firewall"
firewall-cmd --zone=public --permanent --add-port=3306/tcp >>setup.log 2>>error.log
firewall-cmd --zone=public --permanent --add-port=30120/tcp >>setup.log 2>>error.log
firewall-cmd --zone=public --permanent --add-port=30120/udp >>setup.log 2>>error.log
firewall-cmd --zone=public --permanent --add-port=40120/tcp >>setup.log 2>>error.log
firewall-cmd --reload >>setup.log 2>>error.log

echo ""
echo "Installation has completed!!"
echo "Browse to IP address of this AlmaServer Used for Installation"

SITEIP="$(echo -e "${IPADDY}" | tr -d '[:space:]')"
#SITEIP= "echo $IPADDY | xargs"

echo ""
SITEADDR= echo "https://$SERVERNAME:9090"
SITEIP= echo "https://$SITEIP:9090"
echo ""
echo "Username: $MAINDB"
echo "Token: $PASSWDDB"
echo ""
