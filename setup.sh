#!/bin/bash
 
# -- User Defined Variables --# 
hostname='local.vagranttest.com'            # Your hostname (e.g. example.com)
sudo_user='admin'                           # Your sudo username
sudo_user_passwd='vagranttest'              # Your sudo user password
mysql_root_passwd='vagrantmysqlroot'
ssh_port='22'                               # Your SSH port if you wish to change it from the default
timezone='America/Los_Angeles'              # Your server's default timezone

# Servers
includeGit=true                             # Set to true to install Git
includeNginx=true                           # Set to true to install Nginx
includePhp=false                            # Set to true to install PHP
includeMySql=false                          # Set to true to install MySql

cleanup()
{
  echo -n "Cleaning up tmp directory... "
  rm -rf tmp/*
  echo "done."
}

setLocale()
{
  echo -n "Setting up system locale... "
  { 
    locale-gen en_US.UTF-8
    unset LANG
    /usr/sbin/update-locale LANG=en_US.UTF-8
  } > /dev/null 2>&1
  export LANG=en_US.UTF-8
  echo "done."
}

setHostname()
{
  if [ -n "$hostname" ]
  then
    echo -n "Setting up hostname... "
    hostname $hostname
    echo $hostname > /etc/hostname
    echo "127.0.0.1 $hostname" >> /etc/hostname
    echo "done."
  fi
}
 
setTimezone()
{
  echo -n "Setting up timezone... "
  echo $timezone > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1
  echo "done."
}

upgradeAptitude()
{
  echo -n "Upgrading aptitude... "
  aptitude update > /dev/null 2>&1
  aptitude -y safe-upgrade > /dev/null 2>&1
  aptitude -y full-upgrade > /dev/null 2>&1
  aptitude -y install curl build-essential python-software-properties htop > /dev/null 2>&1
  echo "done."
}

setupGit()
{
  echo -n "Installing Git... "
  aptitude -y install git-core > /dev/null 2>&1
  echo "done."
}

setupNginx()
{
  echo -n "Installing Nginx... "
  add-apt-repository ppa:nginx/stable > /dev/null 2>&1
  aptitude -y update > /dev/null 2>&1
  aptitude -y install nginx > /dev/null 2>&1
  echo "done."
}

setupPhp()
{
  echo -n "Installing PHP... "
  aptitude -y install php5-cli php5-common php5-mysql php5-suhosin php5-gd php5-curl > /dev/null 2>&1
  aptitude -y install php5-fpm php5-cgi php-pear php-apc php5-dev libpcre3-dev > /dev/null 2>&1
  echo "done."
}

setupMySql()
{
  echo -n "Installing MySql... "
  echo "mysql-server mysql-server/root_password select $mysql_root_passwd" | debconf-set-selections
  echo "mysql-server mysql-server/root_password_again select $mysql_root_passwd" | debconf-set-selections
  aptitude -y install mysql-server > /dev/null 2>&1
  cat <<EOF > /root/.my.cnf
[client]
user=root
password=$mysql_root_passwd

EOF
  chmod 600 /root/.my.cnf
  mv /etc/mysql/my.cnf /etc/mysql/my.cnf.`date "+%Y-%m-%d"`
  cp files/my.cnf /etc/mysql/
  touch /var/log/mysql/mysql-slow.log
  chown mysql:mysql /var/log/mysql/mysql-slow.log
  service mysql restart > /dev/null 2>&1
  echo "done."
}

finishSetup()
{
  echo -n "Server setup is complete."
}

# Start running the setup scripts

cleanup
setLocale
setHostname
setTimezone
upgradeAptitude

if $includeGit; then setupGit; fi

if $includeNginx; then setupNginx; fi

if $includePhp; then setupPhp; fi

if $includeMySql; then setupMySql; fi

finishSetup