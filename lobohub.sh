#!/bin/bash
cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
USER=`whoami`
IP=$(curl -s4 api.ipify.org)
version=$(curl -s https://raw.githubusercontent.com/lobomfz/Masternode-tools/master/current)
link="https://github.com/phoenixkonsole/transcendence/releases/download/$version"
## Setup

if [ $USER = "root" ]
then
HOME=/root
else
HOME=/home/$USER
fi
INFO_DIR=$HOME/.local/share/telos
if [ ! -d "$INFO_DIR" ]; then
mkdir -p $INFO_DIR
fi

if [ ! -f "$INFO_DIR/dep" ]
then
  printf "Installing ${GREEN}Transcendence dependencies${NC}. Please wait.\n"
  sleep 2
  if [ $USER = "root" ]
  then
  apt update
  apt install -y sudo
  else
  sudo apt update
  fi
  sudo apt -y upgrade
  sudo apt install -y zip p7zip-full unzip curl nano lshw gawk ufw wget
  
  ## Checking for Swap
  
  if [ ! -f /var/swap.img ]
  then
  printf "\n${RED}Creating swap. This may take a while.${NC}\n"
  sudo dd if=/dev/zero of=/var/swap.img bs=2048 count=1M
  sudo chmod 600 /var/swap.img
  sudo mkswap /var/swap.img 
  sudo swapon /var/swap.img 
  sudo printf "\n/var/swap.img none swap sw 0 0" >> /etc/fstab
  fi
  
  sudo ufw allow ssh/tcp
  sudo ufw limit ssh/tcp
  sudo ufw logging on
  sudo su -c 'echo "y" | ufw enable'
  sudo ufw allow 8051
  cd
  touch $INFO_DIR/dep
fi

function configure_systemd() {
  sudo su -c 'cat << EOF > /etc/systemd/system/transcendenced.service
[Unit]
Description=transcendenced.service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=$HOME/.transcendence/transcendenced.pid
ExecStart=/usr/local/bin/transcendenced
ExecStop=/usr/local/bin/transcendence-cli stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF'
  sudo systemctl daemon-reload
  sudo systemctl enable transcendenced
  sudo systemctl start transcendenced
}

function configure_bashrc() {	
	cat << EOF >> $HOME/.bashrc
alias telos_status="transcendence-cli masternode status"
alias telos_stop="systemctl stop transcendenced"
alias telos_start="systemctl start transcendenced"
alias telos_config="nano $HOME/.transcendence/transcendence.conf"
alias telos_getinfo="transcendence-cli getinfo"
alias telos_getpeerinfo="transcendence-cli getpeerinfo"
alias telos_resync="transcendenced -resync"
alias telos_reindex="transcendenced -reindex"
alias telos_restart="systemctl restart transcendenced"
EOF
}

function startnode() {
	sudo systemctl start transcendence
}

## Check for wallet update

if [ -f "/usr/local/bin/transcendenced" ]
then

if [ ! -f "$INFO_DIR/${version}" ]
then

printf "\n${GREEN}Please wait, updating wallet.${NC}"
sleep 1

wget $link/Linux.zip -O ~/Linux.zip 
rm /usr/local/bin/transcendence*
sudo unzip Linux.zip -d /usr/local/bin 
sudo chmod +x /usr/local/bin/transcendence*
rm Linux.zip
touch $INFO_DIR/${version}
printf "\n${GREEN}Wallet updated.${NC} ${RED}PLEASE RESTART YOUR NODES OR REBOOT SYSTEM WHEN POSSIBLE.${NC}"
fi
fi

clear
if [ -z $1 ]; then
printf "1 - Create masternode"
printf "\n2 - Delete masternode"
printf "\n3 - Compile wallet locally"
printf "\nWhat would you like to do?\n"
read DO
else
DO=$1
PRIVKEY=$2
fi

if [ $DO = "help" ]
then
printf "\nUsage:"
printf "\n./lobohub.sh Create/Delete PrivateKey(If creating)"
fi

## Compiling wallet

if [ $DO = "3" ]
then
printf "\n${GREEN}Compiling wallet, this may take some time.${NC}"
sleep 2

sudo systemctl stop transcendenced

if [ ! -f "$INFO_DIR/depc" ]
then

## Installing pre-requisites

sudo apt install -y zip unzip bc curl nano lshw ufw libexpat-dev gawk libdb++-dev git zip automake software-properties-common unzip build-essential libtool autotools-dev autoconf pkg-config libssl-dev libcrypto++-dev libevent-dev libminiupnpc-dev libgmp-dev libboost-all-dev devscripts libsodium-dev libprotobuf-dev protobuf-compiler libcrypto++-dev libminiupnpc-dev gcc g++ --auto-remove
thr="$(nproc)"

## Compatibility issues
  
  export LC_CTYPE=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  sudo apt update
  sudo apt install libssl1.0-dev -y
  sudo apt install libzmq3-dev -y --auto-remove
  touch $INFO_DIR/depc

fi

## Preparing and building

  git clone https://github.com/phoenixkonsole/transcendence.git -b 2.1.0.0
  cd transcendence/depends
  BUILD=$(./config.guess)
  make NO_QT=1 -j $thr
  cd ..
  ./autogen.sh
  ./configure --prefix=`pwd`/depends/$BUILD --disable-tests --without-gui
  make -j $thr
  sudo make install
  touch $INFO_DIR/${version}
  start_nodes

fi

## Properly Deleting node

if [ $DO = "2" ]
then
printf "\n${GREEN}Deleting Telos masternode${NC}. Please wait."
## Removing service
sudo systemctl stop transcendenced 
sudo systemctl disable transcendenced > /dev/null 2>&1
sudo rm /etc/systemd/system/transcendenced.service 
sudo systemctl daemon-reload >/dev/null 2>&1
sudo systemctl reset-failed >/dev/null 2>&1

## Removing node files 

rm ~/.transcendence -r
sed -i '/telos/d' ~/.bashrc
printf "\nTelos masternode successfully deleted."
fi

## Creating new nodes

if [ $DO = "1" ]
then
if [ ! -d ~/.transcendence ] 
then
  if [ -z $1 ]; then
  printf "\nEnter masternode private key for your masternode: "
  read PRIVKEY
  fi
  CONF_DIR=$HOME/.transcendence
  mkdir $CONF_DIR
  if [ ! -f "/usr/local/bin/transcendenced" ]
  then
  printf "\n${GREEN}Downloading precompiled wallet${NC}\n"
  wget $link/Linux.zip  -O ~/Linux.zip 
  touch $INFO_DIR/${version}
  sudo unzip Linux.zip -d /usr/local/bin 
  sudo chmod +x /usr/local/bin/transcendence*
  rm Linux.zip 
fi
  if [ ! -f Bootstrap.7z ]
  then
  printf "\nDownloading bootstrap"
  wget $link/Bootstrap.7z -O ~/Bootstrap.7z
  fi
  printf "\n${GREEN}Extracting bootstrap, may take some time${NC}\n"
  7z x Bootstrap.7z -o$CONF_DIR
  
  cat << EOF >> $CONF_DIR/transcendence.conf
rpcuser=user`shuf -i 100000-10000000 -n 1`
rpcpassword=pass`shuf -i 100000-10000000 -n 1`
rpcallowip=127.0.0.1
rpcport=8351
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=64
masternode=1
dbcache=20
maxorphantx=5
maxmempool=100

externalip=$IP
masternodeaddr=$IP:8051
masternodeprivkey=$PRIVKEY
EOF
  printf "\nYour ip is ${GREEN}$IP:8051${NC}\n"
	configure_bashrc
	configure_systemd
else
printf "\nOnly 1 node allowed per vps, if this is a mistake, try deleting the masternode with the script."
fi
printf "\nCommands:\ntelos_start\ntelos_restart\ntelos_status\ntelos_stop\ntelos_config\ntelos_getinfo\ntelos_getpeerinfo\ntelos_resync\ntelos_reindex\n"
fi
printf "\nMade by lobo with the help of all Transcendence team\nlobo's Transcendence Address for donations: GWe4v6A6tLg9pHYEN5MoAsYLTadtefd9o6\nBitcoin Address for donations: 1NqYjVMA5DhuLytt33HYgP5qBajeHLYn4d\n"
source ~/.bashrc
