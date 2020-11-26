#!/usr/bin/bash

curl_wget(){
    if [[ -x $(command -v curl) ]]; then
        ambil="curl $1 $2"
    elif [[ -x $(command -v wget) ]]; then
        ambil="wget $3 $1"
    else
    echo "Harap install cURL atau wget"
    exit 1
  fi
}

install(){
    # Install Stunnel
    sudo pacman -S stunnel iptables screen sshpass

    # Install Redsocks
    yay -S redsocks

    # Konfigurasi File  
    systemctl disable stunnel
    
    # Download File
    mkdir $HOME/.config/stunect
    dir=$HOME/.config/stunect/redsocks.conf
    curl_wget https://raw.githubusercontent.com/icaksh/stunect/main/config/redsocks.conf "-o $dir --progress-bar" "-O $dir -q --show-progress --progress=bar:force"
    $ambil
    dir=$HOME/.config/stunect/ssh_config
    curl_wget https://raw.githubusercontent.com/icaksh/stunect/main/config/ssh_config "-o $dir --progress-bar" "-O $dir -q --show-progress --progress=bar:force"
    $ambil
    dir=$HOME/.config/stunect/stunect.conf
    curl_wget https://raw.githubusercontent.com/icaksh/stunect/main/config/stunect.conf "-o $dir --progress-bar" "-O $dir -q --show-progress --progress=bar:force"
    $ambil
}
uninstall(){
    rm -rf $HOME/.config/stunect/stunect.conf
    #sudo pacman -R stunnel sshpass
    #yay -R redsocks
}
config(){
    rm -rf $1/.config/stunect/stunect.conf
    read -p "Masukkan host SSH: " host
    read -p "Masukkan port SSH: " port
    read -p "Masukkan username SSH: " nama
    read -p "Masukkan password SSH: " pass
    read -p "Masukkan SNI (domain.com): " sni
bash -c 'cat >> '$1'/.config/stunect/stunect.conf'<<EOF
# Ganti true menjadi false untuk menggunakan
configured=true

# Host SSH
host=$host

# Port SSH
port=$port

# Username SSH
user=$nama

# Password SSH
pass=$pass

# Server Name Indication
sni=$sni
EOF
}
stunconf(){
source $1/.config/stunect/stunect.conf
rm -rf $1/.config/stunect/stunnel.conf
touch $1/.config/stunect/stunnel.conf
if [[ $configured ]]; then
bash -c 'cat >> '$1'/.config/stunect/stunnel.conf'<<EOF
[SSH]
client = yes
sslVersion = all
accept = localhost:1954
connect = $host:$port
sni = $sni
EOF
else
    echo "Stunect not configurated"
fi
}

start(){
    echo "STUNECT START\n\n\n"
    stop noexit
    source $1/.config/stunect/stunect.conf
    if [[ $configured ]]; then
        stunconf $1
        sudo stunnel $1/.config/stunect/stunnel.conf
        screen -d -m -S 'stunect-screen' sshpass -p $pass ssh -F $1/.config/stunect/ssh_config -N $user@stunect-start
        sudo iptables -t nat -N REDSOCKS
        sudo iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
        sudo iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
        sudo iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
        sudo iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
        sudo iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
        sudo iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
        sudo iptables -t nat -A REDSOCKS -d 202.152.240.50/32 -j RETURN
        sudo iptables -t nat -A REDSOCKS -d $host -j RETURN
        sudo iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 1955
        sudo iptables -t nat -A PREROUTING -d 192.168.0.0/16 -j RETURN
        sudo iptables -t nat -A PREROUTING -p tcp -j REDIRECT --to-ports 1955
        sudo iptables -t nat -A OUTPUT -j REDSOCKS
        sudo redsocks -c $1/.config/stunect/redsocks.conf > /dev/null &
        echo "Stunect Connected"
    else
        echo "Stunect not configurated"
    fi
    exit
}

stop(){
    sudo iptables -t nat -F REDSOCKS
    sudo iptables -t nat -F OUTPUT
    sudo iptables -t nat -F PREROUTING
    echo "Stunect Disconnected"
    sudo killall redsocks
    sudo killall stunnel
    if ! [[ "$1" == "noexit" ]]; then
        exit
    fi
}

case $1 in
    start)
        start $HOME
        ;;
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    config)
        config $HOME
        ;;
    stop)
        stop
        ;;
esac
