# Simultaneous AP and Managed Mode Wifi on Raspberry Pi

## The script configures simultaneous AP and Managed Mode Wifi on Raspberry Pi

## Tested on:
    - Raspberry Pi Zero W 
    - Raspberry Pi 3 B+
    - Raspberry Pi 3 A+
### With distribution Raspbian Buster

## Parameters
```bash
# ap ssid + ap passphrase
-a / --ap <ap_ssid> <ap_passphrase>

# ap ip address
-i / --ip <ap_ip>

# sta ssid + sta passphrase
-c / --client <sta_ssid> <sta_passphrase>

# ISO3166 Country Code for wpa_supplicant
-cy / --country <ISO3166_country_code>

```

## Flags
```bash
# no ip forwarding on ap + sta or ap + eth mode
-n / --no-internet

# show script help
-h / --help

```

## Usage
```bash
curl https://raw.githubusercontent.com/MkLHX/AP_STA_RPI_SAME_WIFI_CHIP/master/ap_sta_config | bash -s -- -a MyAP myappass -c WifiSSID wifipass -cy FR

```

#### Special thanks to: https://github.com/lukicdarkoo/rpi-wifi