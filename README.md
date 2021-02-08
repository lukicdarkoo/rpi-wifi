# Simultaneous AP and Managed Mode Wifi on Raspberry Pi

## The script configures simultaneous AP and Managed Mode Wifi on Raspberry Pi

## Tested on:
    - Raspberry Pi Zero W 
    - Raspberry Pi 3 B+
    - Raspberry Pi 3 A+

## TODO add compatibility for B+ raspberry (with ethernet)

### With distribution Raspbian Buster

## Parameters
```bash
# ap ssid + ap passphrase
-a / --ap <ap_ssid> <ap_passphrase>

# ap ip address (by default ip pattern 192.168.10.x)
-i / --ip <ap_ip>

# sta ssid + sta passphrase
-c / --client <sta_ssid> <sta_passphrase>

# ISO3166 Country Code for wpa_supplicant (by default FR)
-cy / --country <ISO3166_country_code>

# mode Wi-Fi a = IEEE 802.11a, b = IEEE 802.11b, g = IEEE 802.11g (by default g)
-hw / --hwmode <mode>

```

## Flags
```bash
# Set only STA (used to update STA configuration)
-so, --sta-only

# Set only AP (used to update AP configuration)
-ao, --ap-only

# no ip forwarding on ap + sta or ap + eth mode
-n / --no-internet

# show script help
-h / --help

```

## Usage
```bash
curl https://raw.githubusercontent.com/MkLHX/AP_STA_RPI_SAME_WIFI_CHIP/master/ap_sta_config.sh | bash -s -- --ap ap_ssid ap_passphrases --client client_ssid client_passphrase --country FR

```

#### Special thanks to: https://github.com/lukicdarkoo/rpi-wifi