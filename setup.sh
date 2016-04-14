#!/usr/bin/env

# Check if we can use colours in our output
use_colour=0
[ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null && use_colour=1

# Some useful functions
progress() {
	[ $use_colour -eq 1 ] && echo -ne "\033[01;32m"
	echo "$@" >&2
	[ $use_colour -eq 1 ] && echo -ne "\033[00m"
}

info() {
	[ $use_colour -eq 1 ] && echo -ne "\033[01;34m"
	echo "$@" >&2
	[ $use_colour -eq 1 ] && echo -ne "\033[00m"
}

die () {
	[ $use_colour -eq 1 ] && echo -ne "\033[01;31m"
	echo "$@" >&2
	[ $use_colour -eq 1 ] && echo -ne "\033[00m"
	exit 1
}

install_package() {
	package=$1
	info "install ${package}"
	sudo apt-get -y --force-yes install $package 2>&1 > /dev/null
	return $?
}

# check architecture
sudo test "`dpkg --print-architecture`" == "armhf" || die "This Repos is only for armhf."

# set timezone and update system
info "Setting up locale and keyboard"
sudo dpkg-reconfigure locales

TIMEZONE="Europe/Berlin"
echo $TIMEZONE | sudo tee /etc/timezone
sudo cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
sudo dpkg-reconfigure -f noninteractive tzdata

info "Setting up Hostname"
echo 'Homebridge' | sudo tee /etc/hostname

info "Cleaning up"
sudo dpkg --configure -a

info "Update Package Lists this may take some time (10-20 min) depending on your internet connection"
sudo apt-get update -y
sudo apt-get dist-upgrade -y
info "Done"

info "Installing Zeroconf"

install_package "libavahi-compat-libdnssd-dev"
install_package "gcc-4.8 g++-4.8"
install_package "libkrb5-dev"
install_package "git"

info "Installing node"
wget https://s3-eu-west-1.amazonaws.com/conoroneill.net/wp-content/uploads/2015/03/node-v0.12.1-linux-arm-pi.tar.gz
tar -zxvf node-v0.12.1-linux-arm-pi.tar.gz
cd node-v0.12.1-linux-arm-pi
sudo cp -R * /usr/local/

cd /home/pi
info "Cleaning ..."
rm node-v0.12.1-linux-arm-pi.tar.gz
rm node-v0.12.1-linux-arm-pi -R

info "Installing Homebridge Node Modules"
sudo npm install -g homebridge
sudo npm install -g homebridge-homematic
mkdir /home/pi/.homebridge
configfile="/home/pi/.homebridge/config.json"

info "Setup for Homematic"

hazconfig="$(cat $configfile| grep 'bridge' | wc -l)"
if [ "$hazconfig" = "0" ]; then

  CCUIP=$(whiptail --inputbox "Please enter your CCU IP" 20 60 "000.000.000.000" 3>&1 1>&2 2>&3)

  subsection=$(whiptail --inputbox "Please choose a name for a subsection at your CCU. Insert all the devices, you want to control from HomeKit, in that subsection." 20 60 "HomeKit" 3>&1 1>&2 2>&3)
  
  
  if [ $? -eq 0 ]; then
   echo "{\"bridge\": {\"name\": \"Homebridge\", \"username\": \"CC:22:3D:E3:CE:30\",\"port\": 51826,\"pin\": \"031-45-154\"}," >> $configfile;
   echo "\"description\": \"This is an autogenerated config. only the homematic platform is enabled. see the sample for more\"," >> $configfile;
   echo "\"platforms\": [" >> $configfile;
   echo "{\"platform\": \"HomeMatic\",\"name\": \"HomeMatic CCU\",\"ccu_ip\": \"$CCUIP\"," >> $configfile;
   echo "\"subsection\":\"$subsection\"">>$configfile;
   echo "\"filter_device\":[],\"filter_channel\":[],\"outlets\":[]}"  >> $configfile;
   echo "],\"accessories\": []}"  >> $configfile;
  fi
fi

whiptail --yesno "Would you like to start homebridge at boot by default?" $DEFAULT 20 60 2
RET=$?
if [ $RET -eq 0 ]; then

    wget https://raw.githubusercontent.com/thkl/homebridge/xmlrpc/homebridge
  	sudo mv /home/pi/homebridge /etc/init.d/homebridge
  	sudo chmod 755 /etc/init.d/homebridge
	sudo update-rc.d homebridge defaults
fi

echo '127.0.0.1  Homebridge' | sudo tee /etc/hosts

info "Done. If there are no error messages you are done."
info "Your config.json is here : /home/pi/.homebridge/config.json"
info "If you want to install more modules use npm install -G MODULENAME"
info "Available Modules are here https://www.npmjs.com/browse/keyword/homebridge-plugin"

info "Please navigate to https://github.com/nfarina/homebridge for more informations."
info "Start the Homebridge by typing homebridge"

