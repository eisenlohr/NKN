#!/bin/bash

while getopts 'ha:u:p:b:d:w:' OPTION; do
    case "$OPTION" in
        a)
            arch="$OPTARG"
            ;;
        u)
            user="$OPTARG"
            ;;
        p)
            pwd="$OPTARG"
            ;;
        b)
            addr="$OPTARG"
            ;;
        d)
            deploy="$OPTARG"
            ;;
        w)
            wallet="$OPTARG"
            ;;
        h*)
            cat << EOM
Usage: sudo $0 [options]

This script installs a (commercial) NKN node on a Raspberry Pi.
If a dedicated mining user should be created, provide their name and password.
Otherwise, installation will be done for the current user.

Options:
  -a arch    ARM architecture (armv7 or arm64)                 [armv7]
  -u name    name of NKN mining user                           [current user]
  -p secret  password of new NKN mining user                   []
  -b addr    NKN wallet address for mining rewards
  -w dir     directory that contains existing wallet.json and wallet.pswd to be used
  -d dir     deployment directory relative to mining user home [nkn-commercial-node]
  -h         print this help message

EOM
            exit 1
        ;;
    esac
done

shift "$(($OPTIND -1))"

arch=linux-${arch:-armv7}
deploy=${deploy:-nkn-commercial-node}
addr=${addr:-NKNFipsCCK8EaBVkqEFAf6hfEhiHYQLmSuBq}

echo "installing necessary libraries..."
echo "---------------------------------"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install make curl git unzip whois makepasswd ufw -y --allow-downgrades --allow-remove-essential --allow-change-held-packages


if [ "x$user" == "x" ]
then
    user=$(whoami)
else
    echo "adding mining user..."
    echo "---------------------"
    useradd -m -p $(mkpasswd "$pwd") -s /bin/bash "$user"
    adduser "$user" sudo
fi


echo "downloading NKN miner..."
echo "------------------------"

dply="/home/$user/$deploy"
wget -O /tmp/${arch}.zip --quiet --continue https://commercial.nkn.org/downloads/nkn-commercial/${arch}.zip
unzip /tmp/${arch}.zip -d "$dply"

chown -R $user:$user "$dply" > /dev/null 2>&1
chmod -R 755 "$dply" > /dev/null 2>&1

wget -O - --quiet https://raw.githubusercontent.com/nknorg/nkn/master/config.mainnet.json \
| jq --arg addr "$addr" '.BeneficiaryAddr = $addr' \
> "$dply/config.json"

"$dply/$arch/nkn-commercial" -b $addr -c "$dply/config.json" -d "$dply" -u $user install


echo "waiting for node wallet creation..."
echo "-----------------------------------"
while [[ ! -d "$dply/services/nkn-node/ChainDB" \
      || ! -f "$dply/services/nkn-node/wallet.json" ]]
do
    echo -n .
    sleep 5
done
echo


if [[ -f "$wallet/wallet.json" && -f "$wallet/wallet.pswd" ]]
then
    echo "transferring existing wallet..."
    echo "-------------------------------"
    cp "$wallet/wallet.json" "$dply/services/nkn-node/"
    cp "$wallet/wallet.pswd" "$dply/services/nkn-node/"
fi

sleep 5 > /dev/null 2>&1
systemctl stop nkn-commercial.service > /dev/null 2>&1
sleep 5 > /dev/null 2>&1
cp "$dply/config.json" "$dply/services/nkn-node/config.json"
rm -rf "$dply/services/nkn-node/ChainDB" > /dev/null 2>&1


echo "downloading ChainDB archive..."
echo "------------------------------"

cd "$dply/services/nkn-node/"
wget --quiet --continue --show-progress https://nkn.org/ChainDB_pruned_latest.tar.gz
tar -xvzf ChainDB_pruned_latest.tar.gz

chown -R $user:$user "$dply/services/nkn-node/" > /dev/null 2>&1
chmod -R 755 "$dply/services/nkn-node/" > /dev/null 2>&1


echo "configuring firewall..."
echo "-----------------------"

ufw allow 30001 > /dev/null 2>&1
ufw allow 30002 > /dev/null 2>&1
ufw allow 30003 > /dev/null 2>&1
ufw allow 30004 > /dev/null 2>&1
ufw allow 30005 > /dev/null 2>&1
ufw allow 30010/tcp > /dev/null 2>&1
ufw allow 30011/udp > /dev/null 2>&1
ufw allow 30020/tcp > /dev/null 2>&1
ufw allow 30021/udp > /dev/null 2>&1
ufw allow 32768:65535/tcp > /dev/null 2>&1
ufw allow 32768:65535/udp > /dev/null 2>&1
ufw allow 22 > /dev/null 2>&1
ufw allow 80 > /dev/null 2>&1
ufw allow 443 > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1

echo "firing up the NKN miner..."
echo "--------------------------"
systemctl start nkn-commercial.service > /dev/null 2>&1

cat << EOM
Summary
-------

deployment directory:    $dply
beneficiary address:     $addr

node wallet information: $dply/services/nkn-node/wallet.json|pswd
EOM
