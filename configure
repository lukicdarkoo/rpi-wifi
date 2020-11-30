#!/bin/bash
# The script configures simultaneous AP and Managed Mode Wifi on Raspberry Pi Zero W (should also work on Raspberry Pi 3)
# Licence: GPLv3
# Author: Darko Lukic <lukicdarkoo@gmail.com>
# Special thanks to: https://albeec13.github.io/2017/09/26/raspberry-pi-zero-w-simultaneous-ap-and-managed-mode-wifi/

# Error management
set -o errexit
set -o pipefail
set -o nounset

usage() {
    cat 1>&2 <<EOF
Configures simultaneous AP and Managed Mode Wifi on Raspberry Pi

USAGE:
    rpi-wifi -a <ap_ssid> [<ap_password>] -c <client_ssid> [<client_password>]
    
    rpi-wifi -a MyAP myappass -c MyWifiSSID mywifipass

PARAMETERS:
    -a, --ap      	AP SSID & password
    -c, --client	Client SSID & password
    -i, --ip            AP IP

FLAGS:
    -n, --no-internet   Disable IP forwarding
    -h, --help          Show this help
EOF
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--client)
    CLIENT_SSID="$2"
    CLIENT_PASSPHRASE="$3"
    shift
    shift
    shift
    ;;
    -a|--ap)
    AP_SSID="$2"
    AP_PASSPHRASE="$3"
    shift
    shift
    shift
    ;;
    -i|--ip)
    ARG_AP_IP="$2"
    shift
    shift
    ;;
    -h|--help)
    usage
    shift
	;;
    -n|--no-internet)
    NO_INTERNET="true"
    shift
    ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}"

[ $AP_SSID ] || usage

AP_IP=${ARG_AP_IP:-'192.168.10.1'}
AP_IP_BEGIN=`echo "${AP_IP}" | sed -e 's/\.[0-9]\{1,3\}$//g'`
MAC_ADDRESS="$(cat /sys/class/net/wlan0/address)"

# Install dependencies
sudo apt -y update
sudo apt -y upgrade
sudo apt -y install dnsmasq dhcpcd hostapd cron

# Populate `/etc/udev/rules.d/70-persistent-net.rules`
sudo bash -c 'cat > /etc/udev/rules.d/70-persistent-net.rules' << EOF
SUBSYSTEM=="ieee80211", ACTION=="add|change", ATTR{macaddress}=="${MAC_ADDRESS}", KERNEL=="phy0", \
  RUN+="/sbin/iw phy phy0 interface add ap0 type __ap", \
  RUN+="/bin/ip link set ap0 address ${MAC_ADDRESS}
EOF

# Populate `/etc/dnsmasq.conf`
sudo bash -c 'cat > /etc/dnsmasq.conf' << EOF
interface=lo,ap0
no-dhcp-interface=lo,wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=${AP_IP_BEGIN}.50,${AP_IP_BEGIN}.150,12h
EOF

# Populate `/etc/hostapd/hostapd.conf`
sudo bash -c 'cat > /etc/hostapd/hostapd.conf' << EOF
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
interface=ap0
driver=nl80211
ssid=${AP_SSID}
hw_mode=g
channel=11
wmm_enabled=0
macaddr_acl=0
auth_algs=1
wpa=2
$([ $AP_PASSPHRASE ] && echo "wpa_passphrase=${AP_PASSPHRASE}")
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
rsn_pairwise=CCMP
EOF

# Populate `/etc/default/hostapd`
sudo bash -c 'cat > /etc/default/hostapd' << EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

# Populate `/etc/wpa_supplicant/wpa_supplicant.conf`
sudo bash -c 'cat > /etc/wpa_supplicant/wpa_supplicant.conf' << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="${CLIENT_SSID}"
    $([ $CLIENT_PASSPHRASE ] && echo "psk=\"${CLIENT_PASSPHRASE}\"")
    id_str="AP1"
}
EOF

# Populate `/etc/network/interfaces`
sudo bash -c 'cat > /etc/network/interfaces' << EOF
source-directory /etc/network/interfaces.d

auto lo
auto ap0
auto wlan0
iface lo inet loopback

allow-hotplug ap0
iface ap0 inet static
    address ${AP_IP}
    netmask 255.255.255.0
    hostapd /etc/hostapd/hostapd.conf

allow-hotplug wlan0
iface wlan0 inet manual
    wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface AP1 inet dhcp
EOF

# Populate `/bin/start_wifi.sh`
sudo bash -c 'cat > /bin/rpi-wifi.sh' << EOF
echo 'Starting Wifi AP and client...'
sleep 30
sudo ifdown --force wlan0
sudo ifdown --force ap0
sudo ifup ap0
sudo ifup wlan0
$([ "${NO_INTERNET-}" != "true" ] && echo "sudo sysctl -w net.ipv4.ip_forward=1")
$([ "${NO_INTERNET-}" != "true" ] && echo "sudo iptables -t nat -A POSTROUTING -s ${AP_IP_BEGIN}.0/24 ! -d ${AP_IP_BEGIN}.0/24 -j MASQUERADE")
$([ "${NO_INTERNET-}" != "true" ] && echo "sudo systemctl restart dnsmasq")
EOF
sudo chmod +x /bin/rpi-wifi.sh

# Configure cron job
# sudo bash -c 'cat > /etc/systemd/system/rpi-wifi.service' << EOF
# [Unit]
# Description=Simultaneous AP and Managed Mode Wifi on Raspberry Pi
# Requires=network.target
# After=network.target
#
# [Service]
# ExecStart=/bin/bash -c 'rpi-wifi.sh'
# User=root
#
# [Install]
# WantedBy=multi-user.target
# EOF
# sudo systemctl daemon-reload
# sudo systemctl enable rpi-wifi.service
crontab -l | { cat; echo "@reboot /bin/rpi-wifi.sh"; } | crontab -

# Finish
echo "Wifi configuration is finished! Please reboot your Raspberry Pi to apply changes..."
