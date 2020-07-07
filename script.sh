#!/bin/bash
cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
## Setup
source /etc/os-release
if [ ! -z $UBUNTU_CODENAME ]
then
if [ $UBUNTU_CODENAME = "focal" ]
then
BINARY=Ubuntu20.zip
elif [ $UBUNTU_CODENAME = "bionic" ]
then
BINARY=Ubuntu18.zip
fi
else
BINARY=Linux.zip
fi

if [ -z "$HOME" ] ## If home is not set for whatever reason
then
if [[ $EUID -ne 0 ]]
then
   HOME=/home/`whoami`
else
   HOME=/root
fi
fi

if [ ! -f "$INFO_DIR/dep" ]
then
  printf "Installing ${GREEN}Transcendence dependencies${NC}. Please wait.\n"
  sleep 1
  if [ $EUID -eq 0 ]
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
  printf "\n${GREEN}Creating swap. This may take a while.${NC}\n"
  sudo fallocate -l 2G /var/swap.img
  sudo chmod 600 /var/swap.img
  sudo mkswap /var/swap.img 
  sudo swapon /var/swap.img 
  sudo su -c 'echo "/var/swap.img none swap sw 0 0" >> /etc/fstab'
  fi
  
  sudo ufw allow ssh/tcp
  sudo ufw limit ssh/tcp
  sudo ufw logging on
  sudo su -c 'echo "y" | ufw enable'
  sudo ufw allow 8051
  cd
  touch $INFO_DIR/dep
fi

IP=$(curl -s4 api.ipify.org)
version=$(curl -s https://raw.githubusercontent.com/lobomfz/Masternode-tools/no-ipv6/current)
link="https://github.com/lobomfz/Masternode-tools/releases/download/1.0"

function update_wallet() {
printf "\n${GREEN}Downloading latest precompiled wallet${NC}\n"
wget $link/${BINARY}  -O ~/${BINARY}
touch $INFO_DIR/${version}
sudo unzip ${BINARY} -d /usr/local/bin 
sudo chmod +x /usr/local/bin/transcendence*
rm ${BINARY} 
}

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
TimeoutStopSec=300s
TimeoutStartSec=300s
StartLimitInterval=480s
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
update_wallet
printf "\n${GREEN}Wallet updated.${NC} ${RED}Restart your nodes or reboot your system when possible.${NC}"
fi
fi

NODECOUNT=$(find /root/.transcendence* -maxdepth 0 -type d | wc -l)

clear
if [ -z $1 ]; then
printf "1 - Create masternode"
printf "\n2 - Delete masternodes"
printf "\n3 - Compile wallet locally"
printf "\n4 - Create regular wallet"
printf "\nWhat would you like to do?\n"
read DO
else
DO=$1
PRIVKEY=$2
fi
if [ $DO = "4" ]
then
if [ $NODECOUNT = "0" ] 
then
  CONF_DIR=$HOME/.transcendence
  mkdir $CONF_DIR
  if [ ! -f "/usr/local/bin/transcendenced" ] 
  then
  update_wallet
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
maxconnections=16
EOF
	configure_bashrc
	configure_systemd
printf "\n${GREEN}Please be patient after installing, wait a few minutes if the node says ${RED}\"couldn't connect to server\"${GREEN} or ${RED}\"This is not a masternode\"${NC}\n"
printf "\n${GREEN}Run 'source ~/.bashrc' for your commands to work.${NC}\nCommands:\ntelos_start\ntelos_restart\ntelos_status\ntelos_stop\ntelos_config\ntelos_getinfo\ntelos_getpeerinfo\ntelos_resync\ntelos_reindex\n"
else
printf "\nOnly 1 wallet allowed per vps, if this is a mistake, try deleting the masternodes with the script.\n"
fi
fi

if [ $DO = "help" ]
then
printf "\nUsage:"
printf "\n./script.sh Create/Delete PrivateKey(If creating)"
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

sudo apt install -y zip unzip bc curl libunbound-dev nano lshw ufw libexpat-dev gawk libdb++-dev git zip automake software-properties-common unzip build-essential libtool autotools-dev autoconf pkg-config libssl-dev libcrypto++-dev libevent-dev libminiupnpc-dev libgmp-dev libboost-all-dev devscripts libsodium-dev libprotobuf-dev protobuf-compiler libcrypto++-dev libminiupnpc-dev gcc g++ --auto-remove
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

  git clone https://github.com/phoenixkonsole/transcendence.git
  cd transcendence/depends
  BUILD=$(./config.guess)
  make -j $thr
  cd ..
  ./autogen.sh
  ./configure --with-incompatible-bdb --prefix=$HOME/transcendence/depends/$BUILD --disable-tests --without-gui
  make -j $thr
  sudo make install
  touch $INFO_DIR/${version}
  start_nodes

fi

## Properly Deleting node

if [ $DO = "2" ]
then
if [ $NODECOUNT = "0" ] 
then
printf "\n${RED}You don't have any nodes installed.\n${NC}"
exit
fi
printf "\n${RED}This will delete ALL telos Masternodes on this system if you have more than 1, are you sure? [y/n]\n${NC}"
read CONFIRM
if [ $CONFIRM = "y" ]
then
printf "\n${GREEN}Deleting Telos masternodes${NC}. Please wait."
sudo systemctl stop transcendence*
sudo systemctl disable transcendence* > /dev/null 2>&1
sudo rm /etc/systemd/system/transcendence*
sudo systemctl daemon-reload >/dev/null 2>&1
sudo systemctl reset-failed >/dev/null 2>&1

## Removing node files 

rm ~/.transcendence* -r
sed -i '/transcendence/d' ~/.bashrc
printf "\nTelos masternodes successfully deleted.\n"
fi
fi

## Creating new nodes

if [ $DO = "1" ]
then
if [ $NODECOUNT = "0" ] 
then
  if [ -z $1 ]; then
  printf "\nEnter masternode private key: "
  read PRIVKEY
  fi
  CONF_DIR=$HOME/.transcendence
  mkdir $CONF_DIR
  if [ ! -f "/usr/local/bin/transcendenced" ] 
  then
  update_wallet
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
maxconnections=16

masternode=1
externalip=$IP
masternodeaddr=$IP:8051
masternodeprivkey=$PRIVKEY
EOF
  printf "\nYour ip is ${GREEN}$IP:8051${NC}\n"
	configure_bashrc
	configure_systemd
printf "\n${GREEN}Please be patient after installing, wait a few minutes if the node says ${RED}\"couldn't connect to server\"${GREEN} or ${RED}\"This is not a masternode\"${NC}\n"
printf "\n${GREEN}Run 'source ~/.bashrc' for your commands to work.${NC}\nCommands:\ntelos_start\ntelos_restart\ntelos_status\ntelos_stop\ntelos_config\ntelos_getinfo\ntelos_getpeerinfo\ntelos_resync\ntelos_reindex\n"
else
printf "\nOnly 1 node allowed per vps, if this is a mistake, try deleting the masternodes with the script.\n"
fi
fi
