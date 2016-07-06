#!/bin/bash -ex

##########CONFIGURE############
#Set full path to install directory
target=/opt/etherpad-lite
port=8080 #must be above 1024
###############################



#Check for Root
ifaces=/etc/network/interfaces
LUID=$(id -u)
if [[ $LUID -ne 0 ]]; then
	echo "$0 must be run as root"
	exit 1
fi

#Create the directory
if [ ! -d $target ]; then mkdir -p $target
fi

#Function install
install ()
{
	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o DPkg::Options::=--force-confdef \
        -o DPkg::Options::=--force-confold \
        install $@
}

#installer les paquets nécessaires

install gzip git-core curl python libssl-dev pkg-config build-essential 


# install nodejs 
wget   https://nodejs.org/dist/v4.2.5/node-v4.2.5-linux-armv6l.tar.gz

tar -xvf node-v4.2.5-linux-armv6l.tar.gz
rm -f node-v4.2.5-linux-armv6l.tar.gz
cd node-v4.2.5-linux-armv6l
cp -R * /usr/local


#installer node-gyp pour un support multiplateforme
#npm install -g node-gyp

#git-clone to /opt/etherpad-lite
git clone https://github.com/ether/etherpad-lite.git $target

#Create settings.json
cp $target/settings.json.template $target/settings.json
#Create settings.json2
cp $target/settings.json.template $target/settings2.json

#configure etherpad port
sudo sed -i "s|9001|$port|" $target/settings.json

#service configure the ip
#sudo sed -i "s|0.0.0.0|IPDUSERVEUR|" $target/settings2.json

#useradd system user named etherpad-lite
if ! grep etherpad-lite /etc/passwd; then useradd -p etherpad-lite -MrU etherpad-lite
fi 

#create log directory
if [ ! -d /var/log/etherpad-lite ]; then mkdir /var/log/etherpad-lite/
fi
#create home directory
if [ ! -d /home/etherpad-lite ]; then mkdir /home/etherpad-lite
fi

#permissions
chown -R etherpad-lite:etherpad-lite $target/
chown -R etherpad-lite:etherpad-lite /var/log/etherpad-lite/
chown -R etherpad-lite:etherpad-lite /home/etherpad-lite


#installer node-gyp pour un support multiplateforme
#npm install -g node-gyp
#vérifier les dépendances
#sudo npm i -g npm
#sudo npm i --save lodash
#npm update
npm install -g lodash
npm install -g elasticsearch
#npm install follow
sudo -u etherpad-lite $target/bin/installDeps.sh

#configure daemon
cat > /etc/init.d/etherpad-lite <<"EOF"
#!/bin/sh
### BEGIN INIT INFO
# Provides:          etherpad-lite
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts etherpad lite
# Description:       starts etherpad lite using start-stop-daemon
### END INIT INFO
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
LOGFILE="/var/log/etherpad-lite/etherpad-lite.log"
EPLITE_DIR="#target#"
EPLITE_BIN="bin/safeRun.sh"
USER="etherpad-lite"
GROUP="etherpad-lite"
DESC="Etherpad Lite"
NAME="etherpad-lite"
MYHOST=$(hostname -I)
sed -e "s/IPDUSERVEUR/$MYHOST/" $target/settings2.json > $target/settings.json
#sed -e "s/ //" $target/settings.json2 > $target/settings.json
set -e
. /lib/lsb/init-functions
start() {
  echo "Starting $DESC... "
  
	start-stop-daemon --start --chuid "$USER:$GROUP" --background --make-pidfile --pidfile /var/run/$NAME.pid --exec $EPLITE_DIR/$EPLITE_BIN -- $LOGFILE || true
  echo "done"
}
#We need this function to ensure the whole process tree will be killed
killtree() {
    local _pid=$1
    local _sig=${2-TERM}
    for _child in $(ps -o pid --no-headers --ppid ${_pid}); do
        killtree ${_child} ${_sig}
    done
    kill -${_sig} ${_pid}
}
stop() {
  echo "Stopping $DESC... "
   while test -d /proc/$(cat /var/run/$NAME.pid); do
    killtree $(cat /var/run/$NAME.pid) 15
    sleep 0.5
  done
  rm /var/run/$NAME.pid
  echo "done"
}
status() {
  status_of_proc -p /var/run/$NAME.pid "" "etherpad-lite" && exit 0 || exit $?
}
case "$1" in
  start)
	  start
	  ;;
  stop)
    stop
	  ;;
  restart)
	  stop
	  start
	  ;;
  status)
	  status
	  ;;
  *)
	  echo "Usage: $NAME {start|stop|restart|status}" >&2
	  exit 1
	  ;;
esac
exit 0
EOF

#specify the etherpad install directory
sed -i "s|#target#|$target|" /etc/init.d/etherpad-lite

#Make daemon file executeable
chmod +x /etc/init.d/etherpad-lite

#Configure as a service
update-rc.d etherpad-lite defaults

#create a subdirectory
if [ ! -d /var/www/etherpad-lite ]; then mkdir /var/www/etherpad-lite
fi
touch /var/www/etherpad-lite/.htacces
echo -e "DirectoryIndex \"\" \nRewriteEngine On \nRewriteRule (.*) http://localhost:"$port > /var/www/etherpad-lite/.htacces


echo "Installation d'Etherpad terminée"


#démarrage du service

service etherpad-lite start

echo "Service etherpad-lite démarré"

