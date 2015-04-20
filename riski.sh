#Install some utilities
sudo apt-get -y update
sudo apt-get -y install vim
sudo apt-get -y install build-essential ksh
sudo apt-get -y install libchromaprint-tools
sudo wget --no-check-certificate http://www.java.net/download/jdk8/archive/b108/binaries/jdk-8-ea-b108-linux-arm-vfp-hflt-18_sep_2013.tar.gz
sudo tar zxvf jdk-8-ea-b108-linux-arm-vfp-hflt-18_sep_2013.tar.gz -C /opt

#Install kodi
sudo apt-get -y install kodi
echo "#input
KERNEL==\"mouse*|mice|event*\", MODE=\"0660\", GROUP=\"input\"
KERNEL==\"ts[0-9]*|uinput\", MODE=\"0660\", GROUP=\"input\"
#KERNEL==\"js[0-9]*\", MODE=\"0660\", GROUP=\"input\"
#tty
KERNEL==\"tty[0-9]*\", MODE=\"0666\"
#vchiq
SUBSYSTEM==\"vchiq\", GROUP=\"video\", MODE=\"0660\"" | sudo tee /etc/udev/rules.d/10-permissions.rules
sudo usermod -a -G input pi
sudo usermod -a -G audio pi
sudo usermod -a -G video pi
sudo usermod -a -G dialout pi
sudo usermod -a -G plugdev pi
sudo usermod -a -G tty pi
echo "gpu_mem=128" | sudo tee --append /boot/config.txt
sudo sed -i -e 's/ENABLED=0/ENABLED=1/g' -e 's/USER=kodi/USER=pi/g'  /etc/default/kodi 

#Install Transmission
sudo apt-get -y install transmission-daemon
sudo usermod -a -G debian-transmission pi
sudo sed -i -e 's/\/var\/lib\/transmission-daemon\/downloads/\/media\/MEDIABOX\/torrent\/complet/g' \
 -e 's/\/root\/Downloads/\/media\/MEDIABOX\/torrent\/incomplet/g' \
 -e 's/incomplete-dir-enabled": false/incomplete-dir-enabled": true/g' \
 -e 's/rpc-whitelist-enabled": true/rpc-whitelist-enabled": false/g' \
 -e 's/script-torrent-done-enabled": false/script-torrent-done-enabled": true/g' \
 -e 's/.*rpc-password.*/    "rpc-password": "transmission",/' \
 -e 's/script-torrent-done-filename": ""/script-torrent-done-filename": "\/home\/pi\/transmission-postprocess.sh"/g' \
  /etc/transmission-daemon/settings.json 
sudo service transmission-daemon reload
sudo service transmission-daemon restart
sudo sed -i -e 's/USER=debian-transmission/USER=root/g' /etc/init.d/transmission-daemon

#Configure Static IP
ifconfig
netstat -nr
read -p "Type your chosen private IP address for the pMbox:" address
read -p "Type the Mask value:" mask
read -p "Type the Destination value:" destination
read -p "Type the Bcast value:" bcast
read -p "Type the Gateway value:" gateway
echo "auto lo

iface lo inet loopback
iface eth0 inet static
address $address
netmaks $mask
network $destination
broadcast $bcast
gateway $gateway

allow-hotplug wlan0
iface wlan0 inet manual
wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface default inet dhcp" | sudo tee /etc/network/interfaces


#Install Filebot
wget http://sourceforge.net/projects/filebot/files/filebot/FileBot_4.5.6/filebot_4.5.6_arm.ipk/download
mv download filebot_4.5.6_arm.ipk
sudo mkdir /tmp/filebot
sudo mv filebot_4.5.6_arm.ipk /tmp/filebot/
cd /tmp/filebot 
sudo ar -x filebot_4.5.6_arm.ipk
sudo tar zxvf data.tar.gz
sudo cp -r opt/share/* /usr/share/
sudo ln -s /usr/share/filebot/bin/filebot.sh /usr/bin/filebot
echo "#!/bin/sh
java -Dunixfs=false -DuseExtendedFileAttributes=false -Dfile.encoding=UTF-8 -Dsun.net.client.defaultConnectTimeout=10000 -Dsun.net.client.defaultReadTimeout=60000 -Dapplication.deployment=ipkg -Dapplication.analytics=true -Duser.home=/usr/share/filebot/data -Dapplication.dir=/usr/share/filebot/data -Djava.io.tmpdir=/usr/share/filebot/data/temp -Djna.library.path=/usr/share/filebot -Djava.library.path=/usr/share/filebot -Dnet.sourceforge.filebot.AcoustID.fpcalc=fpcalc -jar -Xmx400M /usr/share/filebot/FileBot.jar \"\$@\"" | sudo tee /usr/share/filebot/bin/filebot.sh 
echo "#!/bin/bash
filebot -script fn:amc --output \"/media/MEDIABOX/media/\" --log-file amc.log --action copy --conflict override -non-strict --def music=y clean=y subtitles=en,es xbmc="$address" artwork=y \"ut_dir=\$TR_TORRENT_DIR/\$TR_TORRENT_NAME\" \"ut_kind=multi\" \"ut_title=\$TR_TORRENT_NAME\"" | sudo tee /home/pi/transmission-postprocess.sh
sudo chmod -R a+wrx /usr/share/filebot/
sudo chmod a+wrx /home/pi/transmission-postprocess.sh
cd
filebot -script fn:configure

#Set DUCKDNS
mkdir /home/pi/duckdns 
read -p "Type your duckdns domain (without quotes):" url
echo "echo url=\"$url\" | curl -k -o ~/duckdns/duck.log -K -"  > /home/pi/duckdns/duck.sh
chmod 700 /home/pi/duckdns/duck.sh
crontab -l > mycron
echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1" >> mycron
crontab mycron
rm mycron
sudo service cron start

#Set MEDIABOX
read -p "Do you want to set Mediabox? (yes/no)" A
if [ "$A" = "yes" ]
then
	sudo fdisk -l
	read -p "Type the name (e.g. sda1,...) of the device that will become Mediabox:" device 
	sudo umount /dev/$device
	sudo mkfs.ext4 /dev/$device -L MEDIABOX
	sudo mkdir /media/MEDIABOX 
	sudo mount /dev/$device /media/MEDIABOX
	sudo mkdir -p /media/MEDIABOX/torrent
	sudo mkdir /media/MEDIABOX/torrent/complet
	sudo mkdir /media/MEDIABOX/torrent/incomplet
	sudo mkdir /media/MEDIABOX/media/
	sudo mkdir /media/MEDIABOX/media/Movies
	sudo mkdir /media/MEDIABOX/media/Music
	sudo mkdir /media/MEDIABOX/media/TV\ Shows
	sudo chmod -R a+wrx /media/MEDIABOX
	sudo umount /dev/$device
	sudo rm -r /media/MEDIABOX
fi

#Reboot Raspberry Pi
sudo reboot
