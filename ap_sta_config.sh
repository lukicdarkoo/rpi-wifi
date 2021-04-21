#!/bin/bash
# The script configures simultaneous AP and Managed Mode Wifi on Raspberry Pi
# Distribution Raspbian Buster
# works on:
#           -Raspberry Pi Zero W
#           -Raspberry Pi 3 B+
#           -Raspberry Pi 3 A+
# Licence: GPLv3
# Author: Mickael Lehoux <mickael.lehoux@gmail.com>
# Special thanks to: https://github.com/lukicdarkoo/rpi-wifi

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
    VERSION="1.3"
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
    echo -e "Manage AP + STA modes on Raspberry Pi with the same wifi chip\n\n      "
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
    -ao, --ap-only      Set only AP
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
    echo "You need to be root to run this script"
    echo "Please run 'sudo bash $0'"
    echo -e "${DEFAULT}"
    exit 1
fi

(test -v AP_SSID && test -v CLIENT_SSID && test -v ARG_COUNTRY_CODE) || (test -v AP_SSID && test -v AP_ONLY) || (test -v CLIENT_SSID && test -v ARG_COUNTRY_CODE && test -v STA_ONLY) || _usage

WIFI_MODE=${ARG_WIFI_MODE:-'g'}
COUNTRY_CODE=${ARG_COUNTRY_CODE:-'FR'}
AP_IP=${ARG_AP_IP:-'192.168.10.1'}
AP_IP_BEGIN=$(echo "${AP_IP}" | sed -e 's/\.[0-9]\{1,3\}$//g')
MAC_ADDRESS="$(cat /sys/class/net/wlan0/address)"

if ! test -v AP_ONLY; then
    AP_ONLY="false"
fi

if ! test -v STA_ONLY; then
    STA_ONLY="false"
fi

# welcome cli user
_welcome

if test true != "${STA_ONLY}" && test true == "${AP_ONLY}"; then
    # Install dependencies
    _logger "check if dependencies needed"

    # keep order of dependencies installation
    if [[ $(dpkg -l | grep -c cron) == 0 ]]; then
        apt-get -y update
        apt-get -y install cron
        # init crontab by adding comment
        # crontab -l | {
        #     cat
        #     echo -e "# comment for crontab init"
        # } | crontab -
        EDITOR=nano crontab -l > cron_jobs
        echo -e "# comment for crontab init\n" >> cron_jobs
        EDITOR=nano crontab cron_jobs
        rm cron_jobs
    fi

    if [[ $(dpkg -l | grep -c dhcpcd) == 0 ]]; then
        apt-get -y update
        apt-get -y install dhcpcd
    fi

    if [[ $(dpkg -l | grep -c hostapd) == 0 ]]; then
        apt-get -y update
        apt-get -y install hostapd
    fi

    if [[ $(dpkg -l | grep -c dnsmasq) == 0 ]]; then
        apt-get -y update
        apt-get -y install dnsmasq
    fi
fi

if test true != "${STA_ONLY}"; then
    # Populate `/etc/udev/rules.d/70-persistent-net.rules`
    _logger "Populate /etc/udev/rules.d/70-persistent-net.rules"
    bash -c 'cat > /etc/udev/rules.d/70-persistent-net.rules' <<EOF
SUBSYSTEM=="ieee80211", ACTION=="add|change", ATTR{macaddress}=="${MAC_ADDRESS}", KERNEL=="phy0", \
RUN+="/sbin/iw phy phy0 interface add ap0 type __ap", \
RUN+="/bin/ip link set ap0 address ${MAC_ADDRESS}

EOF
fi

if test true != "${STA_ONLY}"; then
    # Populate `/etc/dnsmasq.conf`
    _logger "Populate /etc/dnsmasq.conf"
    bash -c 'cat > /etc/dnsmasq.conf' <<EOF
interface=lo,ap0
no-dhcp-interface=lo,wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=${AP_IP_BEGIN}.50,${AP_IP_BEGIN}.150,12h

EOF
fi

if test true != "${STA_ONLY}"; then
    # Populate `/etc/hostapd/hostapd.conf`
    _logger "Populate /etc/hostapd/hostapd.conf"
    bash -c 'cat > /etc/hostapd/hostapd.conf' <<EOF
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
interface=ap0
driver=nl80211
ssid=${AP_SSID}
hw_mode=${WIFI_MODE}
channel=11
wmm_enabled=0
macaddr_acl=0
auth_algs=1
wpa=2PASSPHRASE
$([ $AP_PASSPHRASE ] && echo "wpa_passphrase=${AP_PASSPHRASE}")
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
rsn_pairwise=CCMP

EOF
fi

if test true != "${STA_ONLY}"; then
    # Populate `/etc/default/hostapd`
    _logger "Populate /etc/default/hostapd"
    bash -c 'cat > /etc/default/hostapd' <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"

EOF
fi

if test true != "${AP_ONLY}"; then
    # Populate `/etc/wpa_supplicant/wpa_supplicant.conf`
    _logger "Populate /etc/wpa_supplicant/wpa_supplicant.conf"
    bash -c 'cat > /etc/wpa_supplicant/wpa_supplicant.conf' <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${COUNTRY_CODE}
network={
    ssid="${CLIENT_SSID}"
    $([ $CLIENT_PASSPHRASE ] && echo "psk=\"${CLIENT_PASSPHRASE}\"")
    id_str="AP1"
    scan_ssid=1
}

EOF
fi

# Populate `/etc/network/interfaces`
# TODO manage eth0 interface
# if current device is model B+ with ethernet port
# auto eth0
# allow-hotplug eth0
# iface eth0 inet manual
#
_logger "Populate /etc/network/interfaces"
bash -c 'cat > /etc/network/interfaces' <<EOF
source-directory /etc/network/interfaces.d

auto lo
auto ap0
auto wlan0

iface lo inet loopback

allow-hotplug ap0
iface ap0 inet static
    address ${AP_IP}
    netmask 255.255.255.0
    network ${AP_IP_BEGIN}.0
    broadcast ${AP_IP_BEGIN}.255
    gateway ${AP_IP}
    hostapd /etc/hostapd/hostapd.conf

allow-hotplug wlan0
iface wlan0 inet manual
    wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface AP1 inet dhcp

EOF

if test true != "${STA_ONLY}"; then
    # Populate `/bin/manage-ap0-iface.sh`
    _logger "Populate /bin/manage-ap0-iface.sh"
    bash -c 'cat > /bin/manage-ap0-iface.sh' <<EOF
#!/bin/bash
# check if hostapd service succes to start or not
# in our case, it cannot start when /var/run/hostapd/ap0 exist
# so we have to delete it
echo 'Check if hostapd.service is hang cause ap0 exist...'
hostapd_is_running=\$(service hostapd status | grep -c "Active: active (running)")
if test 1 -ne "\${hostapd_is_running}" ; then
    rm -rf /var/run/hostapd/ap0 | echo "ap0 interface does not exist, the faillure is elsewhere"
fi

EOF
    chmod +x /bin/manage-ap0-iface.sh
fi

# create ap sta log folder
mkdir -p /var/log/ap_sta_wifi

if test true != "${STA_ONLY}"; then
    # Create hostapd ap0 monitor
    _logger "Create hostapd ap0 monitor crontask"
    # do not create the same cron task if exist
    check_ap0_cron_exist=$(EDITOR=nano crontab -l | grep -cF "* * * * * /bin/manage-ap0-iface.sh >> /var/log/ap_sta_wifi/ap0_mgnt.log 2>&1")
    if test 1 != $check_ap0_cron_exist; then
        # crontab -l | {
        #     cat
        #     echo -e "# Start hostapd when ap0 already exists\n* * * * * /bin/manage-ap0-iface.sh >> /var/log/ap_sta_wifi/ap0_mgnt.log 2>&1\n"
        # } | crontab -
        EDITOR=nano crontab -l > cron_jobs
        echo -e "# Start hostapd when ap0 already exists\n* * * * * /bin/manage-ap0-iface.sh >> /var/log/ap_sta_wifi/ap0_mgnt.log 2>&1\n" >> cron_jobs
        EDITOR=nano crontab cron_jobs
        rm cron_jobs
    else
        _logger "crontask exists"
    fi
fi

if test true != "${STA_ONLY}"; then
    # Populate `/bin/rpi-wifi.sh`
    _logger "Populate /bin/rpi-wifi.sh"
    bash -c 'cat > /bin/rpi-wifi.sh' <<EOF
#!/bin/bash
echo 'Starting Wifi AP and client...'
ifdown --force wlan0
ifdown --force ap0
ifup ap0
ifup wlan0
$([ "${NO_INTERNET-}" != "true" ] && echo "sysctl -w net.ipv4.ip_forward=1")
$([ "${NO_INTERNET-}" != "true" ] && echo "iptables -t nat -A POSTROUTING -s ${AP_IP_BEGIN}.0/24 ! -d ${AP_IP_BEGIN}.0/24 -j MASQUERADE")
$([ "${NO_INTERNET-}" != "true" ] && echo "systemctl restart dnsmasq")
echo 'WPA Supplicant reconfigure in 5sec...'
sleep 5
wpa_cli -i wlan0 reconfigure

EOF
    chmod +x /bin/rpi-wifi.sh
fi

if test true != "${STA_ONLY}"; then
    # Create Reboot cron task
    _logger "Create reboot crontask"
    # do not create the same cron task if exist
    reboot_cron_exist=$(EDITOR=nano crontab -l | grep -cF "@reboot sleep 20 && /bin/rpi-wifi.sh >> /var/log/ap_sta_wifi/on_boot.log 2>&1")
    if test 1 != $reboot_cron_exist; then
        EDITOR=nano crontab -l > cron_jobs
        echo -e "# On boot start AP + STA config\n@reboot sleep 20 && /bin/rpi-wifi.sh >> /var/log/ap_sta_wifi/on_boot.log 2>&1\n" >> cron_jobs
        EDITOR=nano crontab cron_jobs
        rm cron_jobs
    else
        _logger "crontask exists"
    fi
fi

_logger "${STA_ONLY}"
if test true != "${STA_ONLY}"; then
    # unmask and enable dnsmasq.service / hostapd.service
    _logger "Unmask and enable dnsmasq.service / hostapd.service"
    systemctl unmask dnsmasq.service hostapd.service
    systemctl enable dnsmasq.service hostapd.service
    systemctl daemon-reload
fi

# Finish
if test true == "${STA_ONLY}" && test true != "${AP_ONLY}"; then
    wpa_cli -i wlan0 reconfigure
    sleep 15
    # wpa_cli -i wlan0 reassociate
    # sleep 3
    # ifdown --force wlan0
    ifconfig wlan0 down # better way for docker
    sleep 2
    # ifup --force wlan0
    ifconfig wlan0 up # better way for docker
    _logger "STA configuration is finished!"
elif test true != "${STA_ONLY}" && test true == "${AP_ONLY}"; then
    _logger "AP configuration is finished!"
elif test true != "${STA_ONLY}" && test true != "${AP_ONLY}"; then
    _logger "AP + STA configurations are finished!"
    _logger "You need to reboot Raspbery Pi to apply changes.."
fi
