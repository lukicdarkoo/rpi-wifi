#!/bin/bash
# The script configures simultaneous AP and Managed Mode Wifi on Raspberry Pi
# Distribution Raspbian Bullseye
# works on:
#           -Raspberry Pi Zero 2 W
#           -Raspberry Pi 4 B
# Licence: GPLv3
# Author: Mickael Lehoux <mickael.lehoux@gmail.com>
# Repository: https://github.com/MkLHX/AP_STA_RPI_SAME_WIFI_CHIP
# Special thanks to: https://github.com/lukicdarkoo/rpi-wifi

# set -exv

# Error management
set -o errexit
set -o pipefail
set -o nounset

DEFAULT='\033[0;39m'
WHITE='\033[0;02m'
RASPBERRY='\033[0;35m'
GREEN='\033[1;32m'
RED='\033[1;31m'

_welcome() {
    VERSION="2.0.1"
    echo -e "${RASPBERRY}\n"
    echo -e "                                                                       "
    echo -e "  /888888  /8888888                         /888888  /88888888 /888888 "
    echo -e " /88__  88| 88__  88          /88          /88__  88|__  88__//88__  88"
    echo -e "| 88  \ 88| 88  \ 88         | 88         | 88  \__/   | 88  | 88  \ 88"
    echo -e "| 88888888| 8888888/       /88888888      |  888888    | 88  | 88888888"
    echo -e "| 88__  88| 88____/       |__  88__/       \____  88   | 88  | 88__  88"
    echo -e "| 88  | 88| 88               | 88          /88  \ 88   | 88  | 88  | 88"
    echo -e "| 88  | 88| 88               |__/         |  888888/   | 88  | 88  | 88"
    echo -e "|__/  |__/|__/                             \______/    |__/  |__/  |__/"
    echo -e "                                                                       "
    echo -e "                                                    version ${VERSION} "
    echo -e " By https://github.com/MkLHX                                           "
    echo -e "${GREEN}                                                               "
    echo -e "Manage AP + STA modes on Raspberry Pi with the same wifi chip\n        "
    echo -e "${RASPBERRY}                                                           "
    echo -e "V2.x.x replaces chron with an integrated service model.                "
    echo -e "${GREEN}                                                               "
}

_logger() {
    echo -e "${GREEN}"
    echo "${1}"
    echo -e "${DEFAULT}"
}

_usage() {
    cat 1>&2 <<EOF
Configures simultaneous AP and Managed Mode Wifi on Raspberry Pi

USAGE:
    ap_sta_config.sh --ap <ap_ssid> [<ap_password>] --client <client_password> [<client_password>] --country <iso_3166_country_code>

    # configure AP + STA
    ap_sta_config.sh --ap ap_ssid ap_passphrases --client client_ssid client_passphrase --country FR

    # configure AP + STA and change the wifi mode
    ap_sta_config.sh --ap ap_ssid ap_passphrases --client client_ssid client_passphrase --country FR --hwmode b

    # update the AP configuration
    ap_sta_config.sh --ap ap_ssid ap_passphrases --ap-only

    # update the STA (client) configuration
    ap_sta_config.sh --client client_ssid client_passphrase --country FR --sta-only

    # logs are written in /var/log/ap_sta_wifi folder

PARAMETERS:
    -a, --ap      	    AP SSID & password
    -c, --client	    Client SSID & password
    -i, --ip            AP IP (by default ip pattern 192.168.10.x)
    -cy, --country      ISO3166 Country Code (by default FR)
    -hw, --hwmode       Mode Wi-Fi a = IEEE 802.11a, b = IEEE 802.11b, g = IEEE 802.11g (by default g)

FLAGS:
    -ao, --ap-only      Set only AP (Reboot required)
    -so, --sta-only     Set only STA
    -n, --no-internet   Disable IP forwarding
    -h, --help          Show this help
EOF
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -c | --client)
        CLIENT_SSID="$2"
        CLIENT_PASSPHRASE="$3"
        shift
        shift
        shift
        ;;
    -a | --ap)
        AP_SSID="$2"
        AP_PASSPHRASE="$3"
        shift
        shift
        shift
        ;;
    -i | --ip)
        ARG_AP_IP="$2"
        shift
        shift
        ;;
    -cy | --country)
        ARG_COUNTRY_CODE="$2"
        shift
        shift
        ;;
    -hw | --hwmode)
        ARG_WIFI_MODE="$2"
        shift
        shift
        ;;
    -n | --no-internet)
        NO_INTERNET="true"
        shift
        ;;
    -ao | --ap-only)
        AP_ONLY="true"
        shift
        ;;
    -so | --sta-only)
        STA_ONLY="true"
        shift
        ;;
    -h | --help)
        _usage
        shift
        ;;
    *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done
set -- "${POSITIONAL[@]}"

if [ $(id -u) != 0 ]; then
    echo -e "${RED}"
    echo "You need to be root to run this script! Please run 'sudo bash $0'"
    echo -e "${DEFAULT}"
    exit 1
fi

(test -v AP_SSID && test -v CLIENT_SSID && test -v ARG_COUNTRY_CODE) || (test -v AP_SSID && test -v AP_ONLY) || (test -v CLIENT_SSID && test -v ARG_COUNTRY_CODE && test -v STA_ONLY) || _usage

WIFI_MODE=${ARG_WIFI_MODE:-'g'}
COUNTRY_CODE=${ARG_COUNTRY_CODE:-'FR'}
AP_IP=${ARG_AP_IP:-'192.168.10.1'}
AP_IP_BEGIN=$(echo "${AP_IP}" | sed -e 's/\.[0-9]\{1,3\}$//g')

if ! test -v AP_ONLY; then
    AP_ONLY="false"
fi

if ! test -v STA_ONLY; then
    STA_ONLY="false"
fi

if ! test -v NO_INTERNET; then
    NO_INTERNET="false"
fi

# welcome cli user
_welcome

# Install dependencies
_logger "check if dependencies needed"
# keep order of dependencies installation
if [[ $(dpkg -l | grep -c dnsmasq) == 0 ]]; then
    apt -y update
    # apt -y install cron # --> no longer using chron (it's a service!).
    apt -y install dhcpcd
    apt -y install hostapd
    apt -y install dnsmasq
fi

if test true != "${STA_ONLY}"; then
    # Exclude ap0 from `/etc/dhcpcd.conf`
    sudo bash -c 'cat >> /etc/dhcpcd.conf' << EOF
# this defines static addressing to ap@wlan0 and disables wpa_supplicant for this interface
interface ap@wlan0
    static ip_address=${AP_IP}/24
    ipv4only
    nohook wpa_supplicant
EOF

    # Populate `/etc/dnsmasq.conf`
    _logger "Populate /etc/dnsmasq.conf"
    bash -c 'cat > /etc/dnsmasq.conf' << EOF
interface=lo,ap@wlan0
no-dhcp-interface=lo,wlan0
bind-interfaces
server=1.1.1.1
domain-needed
bogus-priv
dhcp-range=${AP_IP_BEGIN}.50,${AP_IP_BEGIN}.150,12h
dhcp-option=3,${AP_IP}
EOF

    # Populate `/etc/hostapd/hostapd.conf`
    _logger "Populate /etc/hostapd/hostapd.conf"
    bash -c 'cat > /etc/hostapd/hostapd.conf' << EOF
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
interface=ap@wlan0
driver=nl80211
ieee80211n=1
ssid=${AP_SSID}
hw_mode=${WIFI_MODE}
channel=11
wmm_enabled=1
macaddr_acl=0
auth_algs=1
wpa=2
$([ $AP_PASSPHRASE ] && echo "wpa_passphrase=${AP_PASSPHRASE}")
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

    sudo chmod 600 /etc/hostapd/hostapd.conf
    sudo bash -c 'SYSTEMD_EDITOR=tee systemctl edit --force --full accesspoint@.service' << EOF
[Unit]
Description=IEEE 802.11 ap@%i AP on %i with hostapd
Wants=wpa_supplicant@%i.service
[Service]
Type=forking
PIDFile=/run/hostapd.pid
Restart=on-failure
RestartSec=2
Environment=DAEMON_CONF=/etc/hostapd/hostapd.conf
EnvironmentFile=-/etc/default/hostapd
ExecStartPre=/sbin/iw dev %i interface add ap@%i type __ap
ExecStart=/usr/sbin/hostapd -i ap@%i -P /run/hostapd.pid -B /etc/hostapd/hostapd.conf
ExecStopPost=-/sbin/iw dev ap@%i del
[Install]
WantedBy=sys-subsystem-net-devices-%i.device
EOF

    # not used, as the agent is hooked by dhcpcd
    sudo systemctl disable wpa_supplicant.service

if test true != "${NO_INTERNET}"; then
    # We can then follow Raspberry’s documentation to enable routing and IP masquerading:
    sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent

    sudo bash -c 'cat >/etc/sysctl.d/routed-ap.conf' << EOF
# https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md
# Enable IPv4 routing
net.ipv4.ip_forward=1
EOF
fi
fi

if test true != "${AP_ONLY}"; then
    # Populate `/etc/wpa_supplicant/wpa_supplicant.conf`
    _logger "Populate /etc/wpa_supplicant/wpa_supplicant.conf"
    sudo bash -c 'cat > /etc/wpa_supplicant/wpa_supplicant.conf' << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${COUNTRY_CODE}
network={
    ssid="${CLIENT_SSID}"
    $([ $CLIENT_PASSPHRASE ] && echo "psk=\"${CLIENT_PASSPHRASE}\"")
    scan_ssid=1
}
EOF
sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
fi

if test true != "${STA_ONLY}"; then
    # enable dnsmasq.service / disable hostapd.service
    _logger "enable dnsmasq.service / disable hostapd.service"
    systemctl unmask dnsmasq.service
    systemctl enable dnsmasq.service
    sudo systemctl stop hostapd # if the default hostapd service was active before
    sudo systemctl disable hostapd # if the default hostapd service was enabled before
    sudo systemctl enable accesspoint@wlan0.service
    sudo rfkill unblock wlan
    systemctl daemon-reload
fi

# create ap sta log folder
mkdir -p /var/log/ap_sta_wifi
touch /var/log/ap_sta_wifi/ap0_mgnt.log
touch /var/log/ap_sta_wifi/on_boot.log

if test true != "${NO_INTERNET}"; then
  if test true != "${STA_ONLY}"; then
    # Add firewall rules
    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
    sudo iptables -A FORWARD -i wlan0 -o ap@wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A FORWARD -i ap@wlan0 -o wlan0 -j ACCEPT
    sudo netfilter-persistent save
  fi
fi

# persist powermanagement off for wlan0
grep 'iw dev wlan0 set power_save off' /etc/rc.local || sudo sed -i 's:^exit 0:iw dev wlan0 set power_save off\n\nexit 0:' /etc/rc.local

# Finish
if test true == "${STA_ONLY}"; then
    _logger "Reconfiguring wlan for new WiFi connection: ${CLIENT_SSID}"
    _logger " --> please wait (usually 20-30 seconds total)."
    sleep 1
    wpa_cli -i wlan0 reconfigure
    sleep 10
    ifconfig wlan0 down # better way for docker
    sleep 2
    ifconfig wlan0 up # better way for docker
    _logger "STA configuration is finished!"
elif test true == "${AP_ONLY}"; then
    _logger "AP configuration is finished!"
    _logger " --> You MUST REBOOT for the new AP changes to take effect."
elif test true != "${STA_ONLY}" && test true != "${AP_ONLY}"; then
    _logger "AP + STA configurations are finished!"
    _logger " --> You MUST REBOOT for the new AP changes to take effect."
fi

if test true != "${STA_ONLY}"; then
    _logger "Wait during wlan0 reconnecting to internet..."
    sleep 5
    # pushd "$(dirname "${BASH_SOURCE[0]}")"; sudo ./ap_sta_cron2.sh; popd
    #curl https://raw.githubusercontent.com/MkLHX/AP_STA_RPI_SAME_WIFI_CHIP/master/ap_sta_cron.sh | bash -s --
fi
