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
sudo echo $TIMEZONE > /etc/timezone
sudo cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
sudo dpkg-reconfigure -f noninteractive tzdata

info "Setting up Hostname"
sudo echo Homebridge > /etc/hostname

info "Cleaning up"
sudo dpkg --configure -a

info "Update Package Lists this may take some time (10-20 min) depending on your internet connection"
sudo apt-get update -y
sudo apt-get dist-upgrade -y
info "Done"

info "Installing Zeroconf"

install_package "libavahi-compat-libdnssd-dev"
install_package "gcc-4.8 g++-4.8"
info "Installing node"
wget https://s3-eu-west-1.amazonaws.com/conoroneill.net/wp-content/uploads/2015/03/node-v0.12.1-linux-arm-pi.tar.gz
tar -zxvf node-v0.12.1-linux-arm-pi.tar.gz
cd node-v0.12.1-linux-arm-pi
sudo cp -R * /usr/local/


info "Cloning Repository"
cd /home/pi
git clone -b xmlrpc --single-branch https://github.com/thkl/homebridge.git 
cd homebridge

info "Installing Node Modules"
npm install

info "Setup"

hazconfig="$(cat /home/pi/homebridge/config.json| grep 'bridge' | wc -l)"
if [ "$hazconfig" = "0" ]; then
  
  CCUIP=$(whiptail --inputbox "Please enter your CCU IP" 20 60 "000.000.000.000" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
   echo "{\"bridge\": {\n\"name\": \"Homebridge\", \n\"username\": \"CC:22:3D:E3:CE:30\",\n\"port\": 51826,\n\"pin\": \"031-45-154\"\n},\n" >> /home/pi/homebridge/config.json;
   echo "\"description\": \"This is an autogenerated config. only the homematic platform is enabled. see the sample for more\",\n" >> /home/pi/homebridge/config.json;
   echo "\"platforms\": [\n" >> /home/pi/homebridge/config.json;
   echo "{\n\"platform\": \"HomeMaticPlatform\",\n\"name\": \"HomeMatic CCU\",\n\"ccu_ip\": \"$CCUIP\"," >> /home/pi/homebridge/config.json;
   echo "\"filter_device\":[],\n\"filter_channel\":[],\n\"outlets\":[]\n}"  >> /home/pi/homebridge/config.json;
   echo "],\n\"accessories\": []}\n"  >> /home/pi/homebridge/config.json;
  fi
fi

whiptail --yesno "Would you like to start homebridge at boot by default?" $DEFAULT 20 60 2
RET=$?
if [ $RET -eq 0 ]; then
  sudo cp /home/pi/homebridge/homebridge.txt /etc/init.d/homebridge
  sudo chmod 755 /etc/init.d/homebridge
  sudo update-rc.d homebridge defaults
fi

info "Done. If there are no error messages you are done."
info "Your config is ready to use"
info "to start the homebridge call npm run start."