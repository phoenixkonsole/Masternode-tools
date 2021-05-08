#!/bin/bash
cd ~
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ ! -d "/root/bin" ]; then
mkdir /root/bin
fi

## Setup

if [ ! -f "/root/bin/dep" ]
then
  clear
  echo -e "Installing ${GREEN}Transcendence dependencies${NC}. Please wait."
  sleep 2
  apt update 
  apt -y upgrade
  apt update
  apt install -y zip unzip bc curl nano lshw gawk ufw wget
  
  ## Checking for Swap
  
  if [ ! -f /var/swap.img ]
  then
  clear
  echo -e "${RED}Creating swap. This may take a while.${NC}"
  dd if=/dev/zero of=/var/swap.img bs=2048 count=1M status=progress
  chmod 600 /var/swap.img
  mkswap /var/swap.img 
  swapon /var/swap.img 
  free -m
  echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
  fi
  
  ufw allow ssh/tcp
  ufw limit ssh/tcp
  ufw logging on
  echo "y" | ufw enable 
  ufw allow 8051

  sysctl vm.swappiness=30
  sysctl vm.vfs_cache_pressure=200
  echo 'vm.swappiness=30' | tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure=200' | tee -a /etc/sysctl.conf
  touch /root/bin/dep

fi

## Constants

IP4COUNT=$(find /root/.transcendence_* -maxdepth 0 -type d 2>/dev/null | wc -l)
IP4=$(curl -s4 api.ipify.org)
version=$(curl -s https://raw.githubusercontent.com/phoenixkonsole/Masternode-tools/master/current)
link=$(curl -s https://raw.githubusercontent.com/phoenixkonsole/Masternode-tools/master/download)
PORT=8051
RPCPORTT=8351

## Systemd Function

function configure_systemd() {
  cat << EOF > /etc/systemd/system/transcendenced.service
[Unit]
Description=transcendenced service
After=network.target
 [Service]
User=root
Group=root
Type=forking
ExecStart=/usr/local/bin/transcendenced -daemon
ExecStop=/usr/local/bin/transcendence-cli stop
Restart=always
PrivateTmp=true
TimeoutStopSec=160s
TimeoutStartSec=100s
StartLimitInterval=240s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  sleep 2
  systemctl start transcendenced.service
}

function configure_bashrc() {
  cat << EOF > ~/.bashrc
alias ${ALIAS}_status="transcendence-cli masternode status"
alias ${ALIAS}_stop="systemctl stop transcendenced"
alias ${ALIAS}_start="systemctl start transcendenced"
alias ${ALIAS}_config="nano /root/.transcendence/transcendence.conf"
alias ${ALIAS}_getinfo="transcendence-cli getinfo"
alias ${ALIAS}_getpeerinfo="transcendence-cli getpeerinfo"
alias ${ALIAS}_resync="transcendence-cli -resync"
alias ${ALIAS}_reindex="transcendence-cli -reindex"
alias ${ALIAS}_restart="systemctl restart transcendenced"
EOF
}

## Check for wallet update

clear

if [ -f "/usr/local/bin/transcendenced" ]
then

if [ ! -f "/root/bin/$version" ]
then

echo -e "${GREEN}Please wait, updating wallet.${NC}"
sleep 1

mnalias=$(find /root/.transcendence_* -maxdepth 0 -type d | cut -c22- | head -n 1)
PROTOCOL=$(transcendence-cli -datadir=/root/.transcendence_${mnalias} getinfo | grep "protocolversion" | sed 's/[^0-9]*//g')

if [ $PROTOCOL != 71006 ]
then
sed -i 's/22123/8051/g' /root/.transcendence*/transcendence.conf
rm .transcendence*/blocks -rf
rm .transcendence*/chainstate -rf
rm .transcendence*/sporks -rf
rm .transcendence*/zerocoin -rf
fi

wget $link -O /root/Linux.zip 
rm /usr/local/bin/transcendence*
unzip Linux.zip -d /usr/local/bin 
chmod +x /usr/local/bin/transcendence*
rm Linux.zip
touch /root/bin/$version
echo -e "${GREEN}Wallet updated.${NC} ${RED}PLEASE RESTART YOUR NODES OR REBOOT VPS WHEN POSSIBLE.${NC}\n"
fi

fi

## Start of Guided Script

if [ -z $1 ]; then
echo "1 - Create new node
2 - Safely remove node
3 - Compile wallet locally
What would you like to do?"
read DO
echo ""
else
DO=$1
ALIAS=$2
ALIASD=$2
PRIVKEY=$3
fi

if [ $DO = "help" ]
then
echo "Usage:"
echo "./lobocain.sh Action Alias PrivateKey"
fi

## Compiling wallet

if [ $DO = "3" ]
then
echo -e "${GREEN}Compiling wallet, this may take some time.${NC}"
sleep 2
systemctl stop transcendenced*

if [ ! -f "/root/bin/depc" ]
then

## Installing pre-requisites

apt install -y zip unzip bc curl nano lshw ufw gawk libdb++-dev git zip automake software-properties-common unzip build-essential libtool autotools-dev autoconf pkg-config libssl-dev libcrypto++-dev libevent-dev libminiupnpc-dev libgmp-dev libboost-all-dev devscripts libsodium-dev libprotobuf-dev protobuf-compiler libcrypto++-dev libminiupnpc-dev --auto-remove
thr="$(nproc)"

## Compatibility issues
  
  export LC_CTYPE=en_US.UTF-8 
  export LC_ALL=en_US.UTF-8
  apt update
  apt install libssl1.0-dev -y
  apt install libzmq3-dev -y --auto-remove
  touch /root/bin/depc

fi

## Preparing and building

  git clone https://github.com/phoenixkonsole/transcendence -b 3.0.4
  cd transcendence
  ./autogen.sh
  ./configure --with-incompatible-bdb --disable-tests --without-gui
  make -j $thr
  make install
  touch /root/bin/$version
  
systemctl start transcendenced*

fi

## Properly Deleting node

if [ $DO = "2" ]
then

echo -e "\n${GREEN}Deleting node${NC}. Please wait."

## Removing service

systemctl stop transcendenced* >/dev/null 2>&1 &
systemctl disable transcendenced* >/dev/null 2>&1
rm /etc/systemd/system/transcendenced* >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
systemctl reset-failed >/dev/null 2>&1

## Removing node files 

rm /root/.transcendence* -r >/dev/null 2>&1
sed -i "/transcendence/d" .bashrc

rm /root/bin/transcendence* >/dev/null 2>&1
echo -e "Node Successfully deleted."

fi

## Creating new nodes

if [ $DO = "1" ]
then
MAXC="32"
if [ ! -f "/usr/local/bin/transcendenced" ]
then
  ## Downloading and installing wallet 
  echo -e "${GREEN}Downloading precompiled wallet${NC}"
  wget $link -O /root/Linux.zip 
  touch /root/bin/$version
  unzip Linux.zip -d /usr/local/bin 
  chmod +x /usr/local/bin/transcendence*
  rm Linux.zip  
fi

## Downloading bootstrap

if [ ! -f bootstrap2.zip ]
then
wget https://github.com/ZenH2O/001/releases/download/Latest/bootstrap.zip && wget https://github.com/ZenH2O/001/releases/download/Latest/bootstrap.z01 && zip -s- bootstrap.zip -O /root/bootstrap2.zip
fi

## Start of node creation

if [ $IP4COUNT = "0" ] 
then

echo -e "${RED}Masternode must be ipv4 as ipv6 is not supported anymore since TELOS 2.x.${NC}"
let COUNTER=0
RPCPORT=$(($RPCPORTT+$COUNTER))
  if [ -z $1 ]; then
  echo -e "\nEnter alias for first node (optional)"
  read ALIAS
  if [ -z $ALIAS ]; then
  ALIAS=telos
  fi
  echo -e "\nEnter masternode private key for your node"
  read PRIVKEY
  fi
  CONF_DIR=/root/.transcendence
  
  mkdir /root/.transcendence
  unzip bootstrap2.zip -d /root/.transcendence
  
  cat << EOF > $CONF_DIR/transcendence.conf
rpcuser=user`shuf -i 100000-10000000 -n 1`
rpcpassword=pass`shuf -i 100000-10000000 -n 1`
rpcallowip=127.0.0.1
rpcport=$RPCPORT
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=$MAXC
masternode=1
dbcache=20
maxorphantx=5
maxmempool=100

bind=$IP4:$PORT
externalip=$IP4
masternodeaddr=$IP4:$PORT
masternodeprivkey=$PRIVKEY
EOF
  echo -e "\nYour ip is ${GREEN}$IP4:$PORT${NC}"
	configure_bashrc
	configure_systemd
else
echo -e "You already have a node."
fi

echo -e "${RED}Please do not set maxconnections lower than 16 and not higher than 32 or your node may not receive rewards as often.${NC}

${RED}If every member of the community buys TELOS for 1$ a day we quickly reach a value of 1$ per coin.${NC}

Commands:
${ALIAS}_start
${ALIAS}_restart
${ALIAS}_status
${ALIAS}_stop
${ALIAS}_config
${ALIAS}_getinfo
${ALIAS}_getpeerinfo
${ALIAS}_resync
${ALIAS}_reindex
"
fi

echo -e "Lobocain by GrumpyDEV blatantly stolen from lobo & xispita in the name of the Transcendence community 
lobo's Transcendence Address for donations: GWe4v6A6tLg9pHYEN5MoAsYLTadtefd9o6
xispita's Transcendence Address for donations: GRDqyK7m9oTsXjUsmiPDStoAfuX1H7eSfh
GrumpyDEV's Milkpot ................. nah.. enjoy and buy at least for 30$ TELOS
Bitcoin Address for donations: oh common !! Who cares about Bitcoin? Shame on you Lobo!" ## sorry :(

source ~/.bashrc
