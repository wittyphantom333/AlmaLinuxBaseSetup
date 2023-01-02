#!/bin/bash
#Provided by witt@allthingsops.io
#@wittyphantom333

echo "Setting variables"
PASSWDDB="$(openssl rand -base64 12)"
INSTALL_FIVEM=false
INSTALL_MYSQL=false
TXADMIN_INSTALLED=false

#### CHange These ####
SERVERNAME="fivem-col-dev"
TXADMIN_PORT=40150
######################

MAINDB=${SERVERNAME//[^a-zA-Z0-9]/_}

echo "Cleaning up workspace"
rm error.log >>setup.log 2>>error.log
rm setup.log >>setup.log 2>>error.log
rm -R kpatch/ >>setup.log 2>>error.log

echo "Declaring functions"
function pause() {
   read -p "$*"
}

function isinstalled {
   if yum list installed "$@" >/dev/null 2>&1; then
      true
   else
      false
   fi
}

echo "=======================" >>setup.log 2>>error.log
date >>setup.log 2>>error.log
echo "=======================" >>setup.log 2>>error.log

echo "Detecting IP Address and Hostname"
IPADDY="$(hostname -I)"
SERVERNAME="$(hostname)"

read -p 'Install MySQL? (y/N)' MYSQL_VAR
if [[ $MYSQL_VAR == y ]]; then
   INSTALL_MYSQL= true
fi

if [[ $MYSQL_USERVAR == y ]]; then
   read -p 'Create new user? (y/N)' MYSQL_NEWUSERVAR
   if [[ $MYSQL_NEWUSERVAR == y ]]; then
      read -p 'MySQL Username: ' MYSQL_USERNAME
      MAINDB_USER = $MYSQL_USERNAME
   fi
fi

read -p 'Install FiveM? (y/N)' FIVEM_VAR
if [[ $FIVEM_VAR == y ]]; then
   INSTALL_FIVEM= true
fi

if [[ $SERVERNAME == *"localhost"* ]]; then
   echo "Setting IP Hostname"
   #SRVSTR= echo $RANDOM | base64 | head -c 20
   #echo ""
   #SERVERNAME= echo "app_server_$SERVERNAME"
   hostnamectl set-hostname $MAINDB
else
   echo "Server already renamed"
fi

### Argument handling
if [[ $1 == '-n' ]]; then
   if [[ -n $2 ]]; then
      SERVERNAME=$2
      echo "Server name found.  Setting to $SERVERNAME"
      hostnamectl set-hostname $SERVERNAME
   else
      echo "Servername not declared"
      exit
   fi
fi

if [[ $1 == '-u' ]]; then
   if [[ -n $2 ]]; then
      MAINDB_USER=$2
      echo "Username set to: $MAINDB_USER"
   else
      echo "Username not declared"
      exit
   fi
fi

echo "Updating Repositories"
yum update >>setup.log 2>>error.log

echo "Installing PreReqs"
if ! isinstalled ntpdate; then
   yum install -y tar git nano wget npm >>setup.log 2>>error.log
   systemctl start chrnoyd && systemctl enable chrnoyd >>setup.log 2>>error.log
   echo 0.us.pool.ntp.org \n1.us.pool.ntp.org \n2.us.pool.ntp.org >>/etc/chrony.conf >>setup.log 2>>error.log
   systemctl restart chrnoyd >>setup.log 2>>error.log
fi
systemctl start chrnoyd
if ! isinstalled epel-release; then
   echo "Installing epel-release"
   yum install -y epel-release >>setup.log 2>>error.log
fi

if ! [ -x "$(command -v ccache)" ]; then
   echo "Installing ccache"
   yum install -y ccache >>setup.log 2>>error.log
   ccache --max-size=5G
fi

if ! [ -x "$(command -v cockpit)" ]; then
   echo "Installing Cockpit"
   yum install -y cockpit >>setup.log 2>>error.log
   systemctl start cockpit >>setup.log 2>>error.log
   systemctl enable cockpit >>setup.log 2>>error.log
fi

if ! [ -x "$(command -v mysql)" ]; then
   echo "Installing MariaDB"
   yum install -y mariadb-server >>setup.log 2>>error.log
   systemctl start mariadb >>setup.log 2>>error.log
   systemctl enable mariadb >>setup.log 2>>error.log
fi

echo "Installing Apps"
yum install -y git-lfs tuned cockpit-storaged cockpit-pcp cockpit-packagekit cockpit-doc cpupowerutils dnf-automatic >>setup.log 2>>error.log

echo "Disabling SELinux"
sed -i -e "s|SELINUX=enforcing|SELINUX=disabled|" /etc/selinux/config >>setup.log 2>>error.log

echo "Enabling auto updates"
sed -i -e "s|apply_updates = no|apply_updates = yes|" /etc/dnf/automatic.conf >>setup.log 2>>error.log
systemctl enable --now dnf-automatic-notifyonly.timer >>setup.log 2>>error.log

if ! [[ -x "$(command -v kpatch)" ]]; then
   echo "Setting up live patching"
   yum install -y git gcc kernel-devel elfutils elfutils-devel rpmdevtools pesign yum-utils zlib-devel binutils-devel newt-devel python-devel perl-ExtUtils-Embed audit-libs-devel numactl-devel pciutils-devel bison >>setup.log 2>>error.log
   git clone https://github.com/dynup/kpatch.git >>setup.log 2>>error.log && cd kpatch >>setup.log 2>>error.log && make install >>setup.log 2>>error.log && make -C kpatch-build install >>setup.log 2>>error.log

   echo "Installing live patching kernel tools"
   yum install -y asciidoc bc hmaccalc net-tools xmlto ncurses-devel >>setup.log 2>>error.log
   yum --enablerepo base-debuginfo install kernel-debuginfo -y >>setup.log 2>>error.log

   echo "Enabling live kernel updates"
   yum kpatch auto >>setup.log 2>>error.log

   echo "Restarting services"
   systemctl restart polkit >>setup.log 2>>error.log
   systemctl restart auditd >>setup.log 2>>error.log
fi

if ! [ -x "$(command -v tuned-adm)" ]; then
   echo "Boosting CPU to max frequency"
   systemctl enable --now tuned >>setup.log 2>>error.log
   tuned-adm profile throughput-performance >>setup.log 2>>error.log
   cpupower frequency-set -g performance >>setup.log 2>>error.log
fi

if [ $INSTALL_FIVEM == true ]; then
   echo "Creating directory structure"
   if [[ -d /home/fivem ]]; then
      if [[ -d /home/fivem/fx-server ]]; then
         if [[ -d /home/fivem/fx-server-data ]]; then
            echo "Folder structure already configured"
         else
            mkdir /home/fivem/fx-server-data >>setup.log 2>>error.log
            echo "fx-server-data directory created"
         fi
      else
         mkdir /home/fivem/fx-server >>setup.log 2>>error.log
         mkdir /home/fivem/fx-server-data >>setup.log 2>>error.log
         echo "fx-server and fx-server-data directories created"
      fi
   else
      mkdir /home/fivem >>setup.log 2>>error.log
      mkdir /home/fivem/fx-server >>setup.log 2>>error.log
      mkdir /home/fivem/fx-server-data >>setup.log 2>>error.log
      echo "FiveM directories created"
   fi

   echo "Removing old cfx server files"
   rm -R /home/fivem/fx-server/alpine >>setup.log 2>>error.log
   echo "Downloading latest artifacts"
   wget https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/6183-eab7a55b8f98149ac76af234107e2952c13d4cbb/fx.tar.xz >>setup.log 2>>error.log
   echo "Extracting files"
   tar -xvf fx.tar.xz -C /home/fivem/fx-server/ >>setup.log 2>>error.log
   echo "Cleaning up downloads"
   rm fx.tar.xz >>setup.log 2>>error.log

   if ! [ -f /home/fivem/fx-server/start.sh ]; then
      echo "Installing PM2"
      npm install -g pm2 >>setup.log 2>>error.log
      touch /home/fivem/fx-server/start.sh >>setup.log 2>>error.log
      echo "./run.sh +set serverProfile $MAINDB +set txAdminPort $TXADMIN_PORT" >>/home/fivem/fx-server/start.sh >>setup.log 2>>error.log
      cd /home/fivem/fx-server/ && pm2 start startup.sh --name fivem >>setup.log 2>>error.log
      pm2 startup && pm2 save
   fi
   TXADMIN_INSTALLED=true
fi

echo "Enabling MySQL remote access"
sed -i -e "s|#bind-address=0.0.0.0|bind-address=0.0.0.0|" /etc/my.cnf.d/mariadb-server.cnf >>setup.log 2>>error.log
systemctl restart mysql >>setup.log 2>>error.log

if ! [ -x "$(command -v netdata)" ]; then
   echo "Installing Netdata monitoring"
   wget -O "/tmp/netdata-kickstart.sh" "https://my-netdata.io/kickstart.sh" >>setup.log 2>>error.log && sh "/tmp/netdata-kickstart.sh" --claim-token "CCqBjXCMf3SAbaFysiEwOmqpauPxea7k0ZXw1VZrP3M8x4KF6xAukgvIDM_l7kkCVQ2zwFtSxGImUR3n-ExWbtoM4iKWOIkTQVNhbDrreOwKg5D-PYmQNdbM7X6W29JRiD7jwJM" --claim-url "https://app.netdata.cloud" >>setup.log 2>>error.log
fi

if [[ $INSTALL_MYSQL ]]; then
   if [ -d /var/lib/mysql/$MAINDB ]; then
      echo "Database Exists"
      if ! [[ $MAINDB_USER ]]; then
         MAINDB_USER=$MAINDB
      fi
      mysql -e "ALTER USER '${MAINDB_USER}'@'%' IDENTIFIED BY '${PASSWDDB}';"
      mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${MAINDB_USER}'@'%';"
      mysql -e "GRANT GRANT OPTION ON *.* TO '${MAINDB_USER}'@'%';"
      mysql -e "FLUSH PRIVILEGES;"
   else
      echo "Creating database $MAINDB"
      mysql -e "CREATE DATABASE ${MAINDB} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
      if ! [[ -n $MAINDB_USER ]]; then
         read -p 'MySQL Username: ' MAINDB_USER
         mysql -e "CREATE USER '${MAINDB_USER}'@'%' IDENTIFIED BY '${PASSWDDB}';"
         mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${MAINDB_USER}'@'%';"
         mysql -e "GRANT GRANT OPTION ON *.* TO '${MAINDB_USER}'@'%';"
         mysql -e "FLUSH PRIVILEGES;"
      fi
   fi
fi

echo "Configuring firewall"
firewall-cmd --zone=public --permanent --add-port=3306/tcp >>setup.log 2>>error.log
firewall-cmd --zone=public --permanent --add-port=30120/tcp >>setup.log 2>>error.log
firewall-cmd --zone=public --permanent --add-port=30120/udp >>setup.log 2>>error.log
firewall-cmd --zone=public --permanent --add-port=40120/tcp >>setup.log 2>>error.log
firewall-cmd --reload >>setup.log 2>>error.log

echo "================================================================="
echo ""
echo "Installation has completed!!"
echo "Browse to IP address of this AlmaServer Used for Installation"
echo ""
SITEIP="$(echo -e "${IPADDY}" | tr -d '[:space:]')"
SITEADDR= echo "https://$SERVERNAME.pushingstart.com:9090"
SITEIP= echo "https://$SITEIP:9090"
echo ""
echo "DB Username: $MAINDB_USER"
echo "DB Token: $PASSWDDB"
echo ""
echo "================================================================="
