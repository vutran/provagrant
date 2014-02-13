#!/bin/bash
 
# -- User Defined Variables --# 
hostname='local.vagranttest.com'            # Your hostname (e.g. example.com)
sudo_user='admin'                           # Your sudo username
sudo_user_passwd='vagranttest'              # Your sudo user password
ssh_port='22'                               # Your SSH port if you wish to change it from the default

 cleanup()
{
  rm -rf tmp/*
}

set_locale()
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

set_hostname()
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
 
set_timezone()
{
  echo "America/Los_Angeles" > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1
}
 
create_sudo_user()
{
  if [ -n "$sudo_user" -a -n "$sudo_user_passwd" ]
  then
    id $sudo_user > /dev/null 2>&1 && echo "Cannot create sudo user! User $sudo_user already exists!" && touch tmp/sudofailed.$$ && return
    echo -n "Creating sudo user... "
    useradd -d /home/$sudo_user -s /bin/bash -m $sudo_user
    echo "$sudo_user:$sudo_user_passwd" | chpasswd
    echo "$sudo_user ALL=(ALL) ALL" >> /etc/sudoers
    { echo 'export PS1="\[\e[32;1m\]\u\[\e[0m\]\[\e[32m\]@\h\[\e[36m\]\w \[\e[33m\]\$ \[\e[0m\]"'
    } >> /home/$sudo_user/.bashrc
    echo "done."
  fi
}

config_ssh()
{
  conf='/etc/ssh/sshd_config'
  echo -n "Configuring SSH... "
  mkdir ~/.ssh && chmod 700 ~/.ssh/
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.`date "+%Y-%m-%d"`
  sed -i -r 's/\s*X11Forwarding\s+yes/X11Forwarding no/g' $conf
  sed -i -r 's/\s*UsePAM\s+yes/UsePAM no/g' $conf
  sed -i -r 's/\s*UseDNS\s+yes/UseDNS no/g' $conf
  perl -p -i -e 's|LogLevel INFO|LogLevel VERBOSE|g;' $conf
  grep -q "UsePAM no" $conf || echo "UsePAM no" >> $conf
  grep -q "UseDNS no" $conf || echo "UseDNS no" >> $conf
  if [ -n "$ssh_port" ]
  then
    sed -i -r "s/\s*Port\s+[0-9]+/Port $ssh_port/g" $conf 
    cp /vagrant/files/iptables.up.rules tmp/fw.$$
    sed -i -r "s/\s+22\s+/ $ssh_port /" tmp/fw.$$
  fi
  if id $sudo_user > /dev/null 2>&1 && [ ! -e tmp/sudofailed.$$ ]
  then
    sed -i -r 's/\s*PermitRootLogin\s+yes/PermitRootLogin no/g' $conf
    echo "AllowUsers $sudo_user" >> $conf
  fi
  echo "done."
}
 
setup_firewall()
{
  echo -n "Setting up firewall... "
  cp tmp/fw.$$ /etc/iptables.up.rules
  iptables -F
  iptables-restore < /etc/iptables.up.rules > /dev/null 2>&1 &&
  sed -i 's%pre-up iptables-restore < /etc/iptables.up.rules%%g' /etc/network/interfaces
  sed -i -r 's%\s*iface\s+lo\s+inet\s+loopback%iface lo inet loopback\npre-up iptables-restore < /etc/iptables.up.rules%g' /etc/network/interfaces
  /etc/init.d/ssh reload > /dev/null 2>&1
  echo "done."
}
 
setup_tmpdir()
{
  echo -n "Setting up temporary directory... "
  echo "APT::ExtractTemplates::TempDir \"/var/local/tmp\";" > /etc/apt/apt.conf.d/50extracttemplates && mkdir /var/local/tmp/
  mkdir ~/tmp && chmod 777 ~/tmp
  mount --bind ~/tmp /tmp
  echo "done."
}
 
install_base()
{
  echo -n "Setting up base packages... "
  aptitude update > /dev/null 2>&1
  aptitude -y safe-upgrade > /dev/null 2>&1
  aptitude -y full-upgrade > /dev/null 2>&1
  aptitude -y install curl build-essential python-software-properties git-core htop > /dev/null 2>&1
  echo "done."
}
 
install_php()
{
  echo -n "Installing PHP... "
  mkdir -p /var/www
  aptitude -y install php5-cli php5-common php5-mysql php5-suhosin php5-gd php5-curl > /dev/null 2>&1
  aptitude -y install php5-fpm php5-cgi php-pear php-apc php5-dev libpcre3-dev > /dev/null 2>&1
  perl -p -i -e 's|# Default-Stop:|# Default-Stop:      0 1 6|g;' /etc/init.d/php5-fpm
  cp /etc/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf.`date "+%Y-%m-%d"`
  chmod 000 /etc/php5/fpm/pool.d/www.conf.`date "+%Y-%m-%d"` && mv /etc/php5/fpm/pool.d/www.conf.`date "+%Y-%m-%d"` /tmp
  perl -p -i -e 's|listen = 127.0.0.1:9000|listen = /var/run/php5-fpm.sock|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;listen.allowed_clients = 127.0.0.1|listen.allowed_clients = 127.0.0.1|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;pm.status_path = /status|pm.status_path = /status|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;ping.path = /ping|ping.path = /ping|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;ping.response = pong|ping.response = pong|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;request_terminate_timeout = 0|request_terminate_timeout = 300s|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;request_slowlog_timeout = 0|request_slowlog_timeout = 5s|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;listen.backlog = -1|listen.backlog = -1|g;' /etc/php5/fpm/pool.d/www.conf
  sed -i -r "s/www-data/$sudo_user/g" /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;slowlog = log/\$pool.log.slow|slowlog = /var/log/php5-fpm.log.slow|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;catch_workers_output = yes|catch_workers_output = yes|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|pm.max_children = 50|pm.max_children = 25|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;pm.start_servers = 20|pm.start_servers = 3|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|pm.min_spare_servers = 5|pm.min_spare_servers = 2|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|pm.max_spare_servers = 35|pm.max_spare_servers = 4|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;pm.max_requests = 500|pm.max_requests = 500|g;' /etc/php5/fpm/pool.d/www.conf
  perl -p -i -e 's|;emergency_restart_threshold = 0|emergency_restart_threshold = 10|g;' /etc/php5/fpm/main.conf
  perl -p -i -e 's|;emergency_restart_interval = 0|emergency_restart_interval = 1m|g;' /etc/php5/fpm/main.conf
  perl -p -i -e 's|;process_control_timeout = 0|process_control_timeout = 5s|g;' /etc/php5/fpm/main.conf
  perl -p -i -e 's|;daemonize = yes|daemonize = yes|g;' /etc/php5/fpm/main.conf
  cp /etc/php5/fpm/php.ini /etc/php5/fpm/php.ini.`date "+%Y-%m-%d"`
  perl -p -i -e 's|;date.timezone =|date.timezone = America/Los_Angeles|g;' /etc/php5/fpm/php.ini
  perl -p -i -e 's|expose_php = On|expose_php = Off|g;' /etc/php5/fpm/php.ini
  perl -p -i -e 's|allow_url_fopen = On|allow_url_fopen = Off|g;' /etc/php5/fpm/php.ini
  perl -p -i -e 's|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|g;' /etc/php5/fpm/php.ini
  perl -p -i -e 's|;realpath_cache_size = 16k|realpath_cache_size = 128k|g;' /etc/php5/fpm/php.ini
  perl -p -i -e 's|;realpath_cache_ttl = 120|realpath_cache_ttl = 600|g;' /etc/php5/fpm/php.ini
  perl -p -i -e 's|disable_functions =|disable_functions = "system,exec,shell_exec,passthru,escapeshellcmd,popen,pcntl_exec"|g;' /etc/php5/fpm/php.ini
  cp /vagrant/files/apc.ini /etc/php5/fpm/conf.d/apc.ini
  service php5-fpm stop > /dev/null 2>&1
  service php5-fpm start > /dev/null 2>&1
  echo "done."
}
 
config_nginx()
{
  echo -n "Setting up Nginx... "
  add-apt-repository ppa:nginx/stable > /dev/null 2>&1
  aptitude -y update > /dev/null 2>&1
  aptitude -y install nginx > /dev/null 2>&1
  cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.`date "+%Y-%m-%d"`
  rm -rf /etc/nginx/nginx.conf
  cp /vagrant/files/nginx.conf /etc/nginx/nginx.conf
  /bin/mkdir -p ~/.vim/syntax/
  cp /vagrant/files/nginx.vim ~/.vim/syntax/nginx.vim
  touch ~/.vim/filetype.vim
  echo "au BufRead,BufNewFile /etc/nginx/* set ft=nginx" >> ~/.vim/filetype.vim
  rm -rf /etc/nginx/sites-available/default
  unlink /etc/nginx/sites-enabled/default
  mkdir -p /etc/nginx/global
  cp /vagrant/files/global/* /etc/nginx/global
  cp /vagrant/files/mydomain.com.conf /etc/nginx/sites-available/$hostname.conf
  rm -rf /etc/nginx/fastcgi_params
  sed -i -r "s/sudoer/$sudo_user/g" /etc/nginx/nginx.conf
  sed -i -r "s/mydomain.com/$hostname/g" /etc/nginx/sites-available/$hostname.conf
  sed -i -r "s/sudoer/$sudo_user/g" /etc/nginx/sites-available/$hostname.conf
  ln -s -v /etc/nginx/sites-available/$hostname.conf /etc/nginx/sites-enabled/001-$hostname.conf > /dev/null 2>&1
  rm -rf /var/www/nginx-default
  service nginx restart > /dev/null 2>&1
  echo "done."
}
 
print_report()
{
  echo ""
  echo "Venison is delicious... enjoy!"
  echo ""
}
 
#-- Function calls and flow of execution --#
 
# clean up tmp
cleanup
 
# set system locale
set_locale
 
# set host name of server
set_hostname
 
# set timezone of server
set_timezone
 
# create and configure sudo user
create_sudo_user
 
# configure ssh
config_ssh
 
# set up and activate firewall
setup_firewall
 
# set up temp directory
setup_tmpdir
 
# set up base packages
install_base
 
# install php
install_php
 
# configure nginx web server
config_nginx
 
# clean up tmp
cleanup
 
# print report of db info
print_report