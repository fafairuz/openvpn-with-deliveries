#!/usr/bin/env bash

# just a little modified version of https://gist.github.com/sot001/3da9f5c00beb2e96e2edef74556fb1fb

# touch createcert.sh && chmod +x createcert.sh && vi createcert.sh

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [ ! "$1" ]; then
    echo Specify client name. Exiting.. ; exit
fi

DATE=`date "+%Y.%m.%d-%H.%M.%S"`
LOGFILE=createcert.$DATE.log
EZRSA=/etc/openvpn/easy-rsa
RECIPIENT=
CLIENT=$1
DIR=~/clients
HOST=
OVPNPORT=
OVPNPROTOCOL=

if [ ! "$HOST" ]; then
    echo Host not specified. Exiting.. ; exit
fi

if [ ! "$RECIPIENT" ]; then
    echo No recipient specified. Exiting.. ; exit
fi

#ensure we have some packages (dig to check my IP, zip to make a bundled .zip)
if [ ! `rpm -qa | grep ^zip` ]; then
    echo "Please install zip: yum install zip" ; exit
fi
if [ ! `rpm -qa | grep ^bind-utils` ]; then
    echo "Please install dig: yum install bind-utils" ; exit
fi

if [ -f "$EZRSA/keys/$1.key" ]; then
    echo Looks like $1 already has a key 2>&1 | tee -a $LOGFILE
    ls -l $EZRSA/keys/$1.* 2>&1 | tee -a $LOGFILE
    exit
fi

echo +Generating client cert for $1  | tee -a $LOGFILE
cd $EZRSA
source vars

# Generate the key
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" --batch $1

if [ ! -d "$DIR" ]; then
    mkdir -p "$DIR"
fi

CONF="$DIR/$CLIENT/$CLIENT.ovpn"

if [ ! -f $EZRSA/keys/$CLIENT.crt ]; then
    echo "No client .crt found : $EZRSA/keys/$CLIENT.crt" ; exit
fi
if [ ! -f $EZRSA/keys/$CLIENT.key ]; then
    echo "No client .key found : $EZRSA/keys/$CLIENT.key" ; exit
fi

rm -rf "$DIR/$CLIENT"
mkdir -p "$DIR/$CLIENT"

cat > "$CONF" <<EOF
client
dev tun
proto $OVPNPROTOCOL
remote $HOST $OVPNPORT
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
verb 3
EOF

printf "<ca>\n" >> "$CONF"
cat $EZRSA/keys/ca.crt >> "$CONF"
cp $EZRSA/keys/ca.crt "$DIR/$CLIENT"/.
printf "</ca>\n" >> "$CONF"

printf "<cert>\n" >> "$CONF"
cat $EZRSA/keys/$CLIENT.crt >> "$CONF"
cp $EZRSA/keys/$CLIENT.crt "$DIR/$CLIENT"/.
printf "</cert>\n" >> "$CONF"

printf "<key>\n" >> "$CONF"
cat $EZRSA/keys/$CLIENT.key >> "$CONF"
cp $EZRSA/keys/$CLIENT.key "$DIR/$CLIENT"/.
printf "</key>\n" >> "$CONF"

cd $DIR
ZIP="$CLIENT-`date +%y%m%d`.zip"
zip -rq "$ZIP" "$CLIENT/" && echo "New account and config+cert bundle created.. see: $DIR/$ZIP"
echo Sending Email
mutt -s "VPN config for $1" $RECIPIENT  -a ~/clients/$1/$1.ovpn  < ~/emailcontent.txt
echo Done
