# Beepergotchi

## Hardware
Raspberry Pi Zero 2 W  
PiSugar 3 1200 mAh battery  
Pimoroni Display Hat Mini  
ATGM 336H GPS Radio  

## Wiring the GPS Radio to the Pi Zero
```
GPS       Pi
VCC  ->   3.3v (pin 1)
GND  ->   GND (pin 14)
TX   ->   UART RX (pin 10)
RX   ->   UART TX (pin 8)
```
30 Gauge Wire fits through the holes in the PiSugar board nicely

## 3D Printed Case
Coming soon  

## Building the image
Flash the 64 bit version 2.9.4 of the jayofelony image, 2.9.5 crashes the broadcom driver and implodes  
[jayofelony github](https://github.com/jayofelony/pwnagotchi/releases/tag/v2.9.4)  
Using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)  
Boot with keyboard and monitor connected  
Configure username/password  
Power off  
Swap keyboard for USB to ethernet adapter  
Boot  

## Set Local Timezone
```
sudo raspi-config
	-> Localization Options
	-> Timezone
```

## Set WLAN Country
Wifi will not work if you do not set the country
```
sudo raspi-config
	-> Localization Options
	-> WLAN Country
```

## System Update and install vim
DO NOT run apt upgrade, it will break pwnagotchi
```
sudo apt update
sudo apt install vim
```

## Pi Sugar 3 RTC
[Pi Sugar github](https://github.com/PiSugar/pisugar-power-manager-rs)

```
wget https://cdn.pisugar.com/release/pisugar-power-manager.sh
bash pisugar-power-manager.sh -c release
```

Browse to port 8421 in a web browser on the Pi's IP address  
Login with the credentials you configured  
You should see the Pi Sugar control interface  

## Generate /etc/pwnagotchi/config.toml by loading plugins page
Browse to port 8080 in a web browser on the Pi's IP address  
Click on plugins  

> Optional - disable grid plugin

validate /etc/pwnagotchi/config.toml now exists

## Install PiSugar3 plugin for Pwnagotchi
[nullm0ose PiSugar3 plugin](https://github.com/nullm0ose/pwnagotchi-plugin-pisugar3/tree/main)
```
git clone https://github.com/nullm0ose/pwnagotchi-plugin-pisugar3.git
cd pwnagotchi-plugin-pisugar3
sudo cp pisugar3.py /usr/local/share/pwnagotchi/custom-plugins/
sudo vim /etc/pwnagotchi/config.toml
```
Add these settings to config.toml:  
> main.plugins.pisugar3.enabled = true  
> main.plugins.pisugar3.shutdown = 5

> Optional - change the name of the pwnagotchi  
> main.name = "Beepergotchi"

```
sudo systmctl restart pwnagotchi
```
Browse to port 8080 in a web browser on the Pi's IP address  
The power status should show up at the top of the pwnagotchi display in the browser  

## Setting up GPSd on the Pi
```
sudo raspi-config
   -> Interface Options
   -> Serial Port
   -> Disable login shell over serial
   -> Enable serial port hardware
reboot
sudo apt install gpsd gpsd-clients
gpsd -V
```
We will see version 3.22 which needs to be uninstalled
```
sudo apt remove gpsd
```
The fix for 3.22 only pulling the location from first fix can be found on this thread post:  
[why does gpsd not update a location past its first fix](https://raspberrypi.stackexchange.com/questions/136196/why-does-gpsd-not-update-a-location-past-its-first-fix)  
```
sudo apt install scons
wget http://download.savannah.gnu.org/releases/gpsd/gpsd-3.25.tar.gz
tar -zxvf gpsd-3.25.tar.gz
cd gpsd-3.25/
sudo scons
sudo scons install
which gpsd
/usr/local/sbin/gpsd -V
```
validate we are now running version 3.25
```
sudo rm /etc/default/gpsd
```
```
sudo bash -c 'cat > /etc/default/gpsd' << EOF
# Default settings for the gpsd init script and the hotplug wrapper.

# Start the gpsd daemon automatically at boot time
START_DAEMON="true"

# Use USB hotplugging to add new USB devices automatically to the daemon
USBAUTO="false"

# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="/dev/ttyS0"
# or, if you want to setup with BlueNMEA on your android phone, with bt-tethering :
# DEVICES="tcp://192.168.44.1:4352"

# Other options you want to pass to gpsd
GPSD_OPTIONS="-n -F /var/run/gpsd.sock"
EOF
```
Finish creating the gpsd.service following this forum topic:  
[gpsd failing on boot, but starts manually](https://forums.raspberrypi.com/viewtopic.php?t=53644)  
```
which gpsd
```
take note to modify ExecStart line below
```
sudo vim /etc/systemd/system/gpsd.service
```
```
[Unit]
Description=GPS (Global Positioning System) Daemon
Requires=gpsd.socket
# Needed with chrony SOCK refclock
# After=chronyd.service

[Service]
EnvironmentFile=-/etc/default/gpsd
EnvironmentFile=-/etc/sysconfig/gpsd
ExecStart=/usr/local/sbin/gpsd -N $GPSD_OPTIONS $DEVICES

[Install]
WantedBy=multi-user.target
Also=gpsd.socket
```
```
sudo systemctl enable gpsd.service
sudo reboot
gpsmon
```
Once we get a GPS fix, we should now see current location data in gpsmon  

## Enable bettermon interface during auto mode
```
cd /usr/local/share/bettercap/caplets/
> backup original auto caplet incase you need to restore later
cp pwnagotchi-auto.cap /home/pi
sudo cp pwnagotchi-manual.cap pwnagotchi-auto.cap
sudo reboot
```

## Configure GPS for bettercap
Browse to the Pi's IP Address in a browser
> Advanced -> gps  
> baud rate 9600  
> click the save button on baud rate  
> device 127.0.0.1:2947  
> click the save button on device  
> click gps on  
> click Position on the top menu bar and validate you have location after you get a GPS fix

## Install gpsd library for python
```
sudo pip3 install --break-system-packages gpsd-py3
```

## Install GPSd plugin for pwnagotchi
[kellertk gpsd plugin](https://github.com/kellertk/pwnagotchi-plugin-gpsd)
```
git clone https://github.com/kellertk/pwnagotchi-plugin-gpsd.git
cd pwnagotchi-plugin-gpsd
sudo cp gpsd.py /usr/local/share/pwnagotchi/custom-plugins/
sudo vim /etc/pwnagotchi/config.toml
```
> main.plugins.gpsd.enabled = true  
> main.plugins.gpsd.gpsdhost = "127.0.0.1"  
> main.plugins.gpsd.gpsdport = 2947  
```
sudo reboot
```

## Enable memtemp plugin
Browse to port 8080 in a web browser on the Pi's IP address  
>	plugins -> enable memtemp

## Configure memtemp
```
sudo vim /etc/pwnagotchi/config.toml
```
> main.plugins.memtemp.scale = "fahrenheit"  
> main.plugins.memtemp.orientation = "vertical"  

## Enable screen and rotate it 180
```
sudo vim /etc/pwnagotchi/config.toml
```
> ui.display.enabled = true  
> ui.display.rotation = 180  
> ui.display.type = "displayhatmini"
```
sudo systemctl restart pwnagotchi
```
Display should now be working
## Enable the Fancygotchi repo
```
sudo vim /etc/pwnagotchi/config.toml
```
Add the URL below to the existing main.custom_plugin_repos list

> main.custom_plugin_repos = [  
>  "https://github.com/V0r-T3x/Fancygotchi/archive/main.zip",  
> ]  
```
sudo pwnagotchi plugins update
sudo pwnagotchi plugins list
sudo pwnagotchi plugins install Fancygotchi
sudo reboot
```
Browse to port 8080 in a web browser on the Pi's IP address  
> click on plugins  
> enable Fancygotchi  
> refresh the page  
> click on Fancygotchi  
> click on theme downloader  
> click load theme list  
> click select theme  
> click theme manager  
> select cyber theme from the drop down  
> click select theme  

## Installing the Wardriver plugin
[cyberartemio's wardriver plugin](https://github.com/cyberartemio/wardriver-pwnagotchi-plugin)
```
git clone https://github.com/cyberartemio/wardriver-pwnagotchi-plugin.git
cd wardriver-pwnagotch-plugin
sudo cp wardriver.py /usr/local/share/pwnagotchi/custom-plugins/
sudo cp -r wardriver_assets/ /usr/local/share/pwnagotchi/custom-plugins/
sudo vim /etc/pwnagotchi/config.toml
```
Add the following code block to config.toml
```
# Enable the plugin
main.plugins.wardriver.enabled = true
# Path where SQLite db will be saved
main.plugins.wardriver.path = "/home/pi/wardriver"
# Enable UI status text
main.plugins.wardriver.ui.enabled = true
# Enable UI icon
main.plugins.wardriver.ui.icon = true
# Set to true if black background, false if white background
main.plugins.wardriver.ui.icon_reverse = false
# Position of UI status text
main.plugins.wardriver.ui.position.x = 7
main.plugins.wardriver.ui.position.y = 95
# Enable WiGLE automatic file uploading
main.plugins.wardriver.wigle.enabled = false
# WiGLE API key (encoded)
main.plugins.wardriver.wigle.api_key = "xyz..."
# Enable commercial use of your reported data
main.plugins.wardriver.wigle.donate = false
# OPTIONAL: networks whitelist aka don't log these networks
main.plugins.wardriver.whitelist = [
    "network-1",
    "network-2"
]
# NOTE: SSIDs in main.whitelist will always be ignored
```
```
sudo systemctl restart pwnagotchi
```

## Clone the Beepergotchi repo
```
git clone https://github.com/r3dfish/Beepergotchi.git
```

## Replace the background image
```
sudo cp /home/pi/Beepergotchi/320x240e-t-g.png /usr/local/share/pwnagotchi/custom-plugins/themes/cyber/img/bg/320x240e-t-g.png
```

## Replace the boot images
```
sudo cp -r /home/pi/Beepergotchi/boot /usr/local/share/pwnagotchi/custom-plugins/themes/cyber/img/
```

## Configure memtemp labels and position
```
sudo cp /home/pi/Beepergotchi/memtemp.py /home/pi/.pwn/lib/python3.11/site-packages/pwnagotchi/plugins/default/memtemp.py
```

## Position CPU and Temp readings
```
sudo cp /home/pi/Beepergotchi/config-h.toml /usr/local/share/pwnagotchi/custom-plugins/themes/cyber/config/config-h.toml
```

## Remove battery label and position the battery status
```
sudo cp /home/pi/Beepergotchi/pisugar3.py /usr/local/share/pwnagotchi/custom-plugins/pisugar3.py
```

## Add GPS date/time and position info
> local timezone must be set via raspi-config to convert UTC to local time
```
sudo cp /home/pi/Beepergotchi/gpsd.py /usr/local/share/pwnagotchi/custom-plugins/gpsd.py
```

## Disable the LED on the Pimoroni display hat mini
[cyberspacemanmike's guide](https://cyberspacemanmike.com/2024/11/05/pwnagotchi-%E2%9E%A8fancygotchi-2-0/)
```
sudo mkdir -p /etc/systemd/scripts
sudo vim /etc/systemd/scripts/turnOffDisplayLED.py
```
```
import RPi.GPIO as GPIO

red_pin = 17  # GPIO pin for red channel
green_pin = 22  # GPIO pin for green channel
blue_pin = 27  # GPIO pin for blue channel

GPIO.setmode(GPIO.BCM)
GPIO.setup(red_pin, GPIO.OUT)
GPIO.setup(green_pin, GPIO.OUT)
GPIO.setup(blue_pin, GPIO.OUT)

GPIO.output(red_pin, GPIO.LOW)
GPIO.output(green_pin, GPIO.LOW)
GPIO.output(blue_pin, GPIO.LOW)

GPIO.cleanup()
```
```
sudo vim /etc/systemd/system/turnOffDisplayLED.service
```
```
[Unit]
Description=Dim LED on Display HAT Mini
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/systemd/scripts/turnOffDisplayLED.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
```
sudo systemctl daemon-reload
sudo systemctl enable turnOffDisplayLED.service
sudo reboot
```
# BT-Tether plugin

## Replace bt-tether.py
```
sudo cp /home/pi/Beepergotchi/bt-tether.py /home/pi/.pwn/lib/python3.11/site-packages/pwnagotchi/plugins/default/
```
## Android

For Android, you must enable bluetooth tethering prior to connecting
```
Settings -> Connections -> Mobile Hotspot and Tethering -> Bluetooth tethering
```
```
Browse to port 8080 in a web browser on the Pi's IP address  
> click on plugins  
> enable bt-tether
```
```
sudo bluetoothctl
scan on
discoverable on
```
Copy the phone's mac address and name once it is discovered
```
sudo vim /etc/pwnagotchi/config.toml
```
```
main.plugins.bt-tether.phone = "android"
main.plugins.bt-tether.phone-name = "<<phone name>>"
main.plugins.bt-tether.mac = "<<phone mac>>"
```
Find the pwnagotchi in the list of available bluetooth devices on the Android phone and click it to begin pairing  
type yes in bluetoothctl to authorize pairing  
click on "pair" on the Android phone  
once bluetoothctl says it has paired, run the following command in bluetoothctl:  
```
trust "<<phone mac>>"
exit
sudo systemctl restart pwnagotchi
```
After a restart, the pwnagotchi should automatically connect to the Android phone via bluetooth  
The IP address of the pwnagotchi will be displayed on the screen in the bottom right  
you can navigate to this IP address in a browser on the Android phone to interact with the pwnagotchi  
NOTE: If you disable bluetooth, you will have to manually re-enable bluetooth tethering on the Android phone or the pwnagotchi will not connect  

## iOS
Coming Soon
