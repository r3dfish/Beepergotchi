#!/bin/bash

set -e # Exit on any error

PISUGAR3_POWER_MANAGER_URL="https://cdn.pisugar.com/release/pisugar-power-manager.sh"
PISUGAR3_PLUGIN_REPO="https://github.com/nullm0ose/pwnagotchi-plugin-pisugar3.git"
PISUGAR3_PLUGIN_REPO_NAME=$(basename "$PISUGAR3_PLUGIN_REPO" .git)
GPSD_3_25_URL="http://download.savannah.gnu.org/releases/gpsd/gpsd-3.25.tar.gz"
CAPLETS_DIR="/usr/local/share/bettercap/caplets"
GPSD_PLUGIN_REPO="https://github.com/kellertk/pwnagotchi-plugin-gpsd.git"
CUSTOM_PLUGINS_DIR="/usr/local/share/pwnagotchi/custom-plugins/"
CONFIG_TOML="/etc/pwnagotchi/config.toml"
WARDRIVER_PLUGIN_REPO="https://github.com/cyberartemio/wardriver-pwnagotchi-plugin.git"
FANCYGOTCHI_THEMES_REPO="https://github.com/V0r-T3x/Fancygotchi_themes.git"
FANCYGOTCHI_CYBER_THEME_DIR="Fancygotchi_themes/fancygotchi_2.0/themes"
THEMES_DIR="/usr/local/share/pwnagotchi/custom-plugins/themes"
MEMTEMP_PY=".pwn/lib/python3.11/site-packages/pwnagotchi/plugins/default/memtemp.py"
BT_TETHER_DIR=".pwn/lib/python3.11/site-packages/pwnagotchi/plugins/default"

if [ ! -f "/etc/pwnagotchi/config.toml" ]; then
	echo "ERROR: /etc/pwnagotchi/config.toml does not exist"
	echo "please generate this file by visiting port 8080"
	echo "of the pi's IP address in a browser"
	echo "then click on Plugins and make a change to a plugin"
	echo "the file will be generated on a change to a plugin"
	echo "after it has been generated, run this script again"
	exit 1 # Exit as config.toml does not yet exist
fi

echo "updating apt"
sudo apt update

echo "installing vim"
sudo apt install -y vim

echo "downloading Pi Sugar 3 power manager"
wget -P $HOME $PISUGAR3_POWER_MANAGER_URL

echo "installing Pi Sugar 3 power manager"
bash $HOME/pisugar-power-manager.sh -c release

echo "cloning Pi Sugar 3 plugin to home directory"
git clone $PISUGAR3_PLUGIN_REPO $HOME/$PISUGAR3_PLUGIN_REPO_NAME

echo "copying pisugar3.py into /usr/local/share/pwnagotchi/custom-plugins/"
sudo cp $HOME/$PISUGAR3_PLUGIN_REPO_NAME/pisugar3.py $CUSTOM_PLUGINS_DIR

echo "writing pi sugar 3 config to /etc/pwnagotchi/config.toml"
sudo sed -i '66i\main.plugins.pisugar3.enabled = true' $CONFIG_TOML
sudo sed -i '67i\main.plugins.pisugar3.shutdown = 5' $CONFIG_TOML
sudo sed -i '67a\ ' $CONFIG_TOML

echo "changing name to Beepergotchi"
sudo sed -i '/main\.name/c\main.name = "Beepergotchi"' $CONFIG_TOML

echo "installing GPSd"
sudo apt install -y gpsd gpsd-clients scons

echo "removing GPSd due to wrong version"
sudo apt remove -y gpsd

echo "installing scons"
sudo apt install -y scons cppcheck

echo "downloading GPSd 3.25"
wget -P $HOME $GPSD_3_25_URL

echo "untar GPSd 3.25"
tar -zxvf $HOME/gpsd-3.25.tar.gz -C $HOME

echo "cd into GPSd directory"
cd $HOME/gpsd-3.25/

echo "running scons"
sudo scons

echo "running scons install"
sudo scons install

echo "remove default gpsd config"
sudo rm /etc/default/gpsd

echo "write new gpsd config"
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

echo "writing gpsd.service"
sudo bash -c 'cat > /etc/systemd/system/gpsd.service' << EOF
[Unit]
Description=GPS (Global Positioning System) Daemon
Requires=gpsd.socket
# Needed with chrony SOCK refclock
# After=chronyd.service

[Service]
EnvironmentFile=-/etc/default/gpsd
EnvironmentFile=-/etc/sysconfig/gpsd
ExecStart=/usr/local/sbin/gpsd -N \$GPSD_OPTIONS \$DEVICES

[Install]
WantedBy=multi-user.target
Also=gpsd.socket
EOF

echo "setting gpsd.service to start at boot"
sudo systemctl enable gpsd.service

echo "enable bettermon interface during auto mode"
cp $CAPLETS_DIR/pwnagotchi-auto.cap $HOME
sudo cp $CAPLETS_DIR/pwnagotchi-manual.cap $CAPLETS_DIR/pwnagotchi-auto.cap

echo "installing gpsd library for python"
sudo pip3 install --break-system-packages gpsd-py3

echo "installing GPSd plugin for pwnagotchi"
cd $HOME
git clone $GPSD_PLUGIN_REPO
sudo cp pwnagotchi-plugin-gpsd/gpsd.py $CUSTOM_PLUGINS_DIR

echo "writing GPSd config to /etc/pwnagotchi/config.toml"
sudo sed -i '45i\main.plugins.gpsd.enabled = true' $CONFIG_TOML
sudo sed -i '46i\main.plugins.gpsd.gpsdhost = "127.0.0.1"' $CONFIG_TOML
sudo sed -i '47i\main.plugins.gpsd.gpsdport = 2947' $CONFIG_TOML
sudo sed -i '47a\ ' $CONFIG_TOML

echo "enabling and configuring memtemp plugin"
sudo sed -i '/main\.plugins\.memtemp\.enabled/c\main.plugins.memtemp.enabled = true' $CONFIG_TOML
sudo sed -i '/main\.plugins\.memtemp\.scale/c\main.plugins.memtemp.scale = "fahrenheit"' $CONFIG_TOML
sudo sed -i '/main\.plugins\.memtemp\.orientation/c\main.plugins.memtemp.orientation = "vertical"' $CONFIG_TOML

echo "enable screen and rotate it 180"
sudo sed -i '/ui\.display\.enabled/c\ui.display.enabled = true' $CONFIG_TOML
sudo sed -i '/ui\.display\.rotation/c\ui.display.rotation = 0' $CONFIG_TOML
sudo sed -i '/ui\.display\.type/c\ui.display.type = "displayhatmini"' $CONFIG_TOML

echo "enable fancygotchi repo"
sudo sed -i '16i\ "https://github.com/V0r-T3x/Fancygotchi/archive/main.zip",' $CONFIG_TOML

echo "update pwnagotchi plugins"
sudo pwnagotchi plugins update

echo "install fancygotchi plugin"
sudo pwnagotchi plugins install Fancygotchi

echo "cloning Fancygotchi Themes Repo"
git clone $FANCYGOTCHI_THEMES_REPO

echo "installing Fancygotchi Cyber theme"
sudo cp -r $HOME/$FANCYGOTCHI_CYBER_THEME_DIR $CUSTOM_PLUGINS_DIR/themes/

echo "enable fancygotchi plugin"
sudo sed -i '100i\main.plugins.Fancygotchi.enabled = true' $CONFIG_TOML
sudo sed -i '101i\main.plugins.Fancygotchi.rotation = 0' $CONFIG_TOML
sudo sed -i '102i\main.plugins.Fancygotchi.theme = "cyber"' $CONFIG_TOML
sudo sed -i '102a\ ' $CONFIG_TOML

echo "clone the wardriver plugin repo"
git clone $WARDRIVER_PLUGIN_REPO

echo "install wardriver plugin"
sudo cp $HOME/wardriver-pwnagotchi-plugin/wardriver.py $CUSTOM_PLUGINS_DIR
sudo cp -r $HOME/wardriver-pwnagotchi-plugin/wardriver_assets/ $CUSTOM_PLUGINS_DIR

echo "enable wardriver plugin"
sudo sed -i '86i\main.plugins.wardriver.enabled = true' $CONFIG_TOML
sudo sed -i '87i\main.plugins.wardriver.path = "/home/pi/wardriver"' $CONFIG_TOML
sudo sed -i '88i\main.plugins.wardriver.ui.enabled = true' $CONFIG_TOML
sudo sed -i '89i\main.plugins.wardriver.ui.icon = true' $CONFIG_TOML
sudo sed -i '90i\main.plugins.wardriver.ui.icon_reverse = false' $CONFIG_TOML
sudo sed -i '91i\main.plugins.wardriver.ui.position.x = 7' $CONFIG_TOML
sudo sed -i '92i\main.plugins.wardriver.ui.position.y = 95' $CONFIG_TOML
sudo sed -i '93i\main.plugins.wardriver.wigle.enabled = false' $CONFIG_TOML
sudo sed -i '94i\main.plugins.wardriver.wigle.api_key = "xyz..."' $CONFIG_TOML
sudo sed -i '95i\main.plugins.wardriver.wigle.donate = false' $CONFIG_TOML
sudo sed -i '96i\main.plugins.wardriver.whitelist = [' $CONFIG_TOML
sudo sed -i '97i\    "network-1",' $CONFIG_TOML
sudo sed -i '98i\    "network-2"' $CONFIG_TOML
sudo sed -i '99i\]' $CONFIG_TOML
sudo sed -i '100i\\# NOTE: SSIDs in main.whitelist will always be ignored' $CONFIG_TOML
sudo sed -i '100a\ ' $CONFIG_TOML

echo "replacing background images"
sudo cp $HOME/Beepergotchi/320x240e-t-g.png $THEMES_DIR/cyber/img/bg/320x240e-t-g.png

echo "replacing boot images"
sudo cp -r $HOME/Beepergotchi/boot $THEMES_DIR/cyber/img/

echo "fix memtemp.py fahrenheit calculation"
sudo sudo sed -i '/            temp = (pwnagotchi.temperature(celsius=False))/c\            temp = (pwnagotchi.temperature() * 9 / 5) + 32' $HOME/$MEMTEMP_PY

echo "configure memtemp positions and labels"
sudo sed -i '/label = "BT"/c\label = ""' $THEMES_DIR/cyber/config/config-h.toml
sudo sed -i '/position = \[ 218, 96,]/c\position = [ 205, 96,]' $THEMES_DIR/cyber/config/config-h.toml
sudo sed -i '/position = \[ 276, 170,]/c\position = [ 195, 209,]' $THEMES_DIR/cyber/config/config-h.toml
sudo sed -i '/position = \[ 217, 23,]/c\position = [ 220, 23,]' $THEMES_DIR/cyber/config/config-h.toml
sudo sed -i '/position = \[ 218, 61,]/c\position = [ 210, 61,]' $THEMES_DIR/cyber/config/config-h.toml

echo "remove battery label and position the battery status"
sudo sed -i "/            ui.add_element('bat', LabeledValue(color=BLACK, label='BAT:', value='0%',/c\            ui.add_element('bat', LabeledValue(color=BLACK, label='', value='0%'," $CUSTOM_PLUGINS_DIR/pisugar3.py
sudo sed -i "/                                               position=(ui.width() \/ 2 + 10, 0),/c\                                               position=(272, 60)," $CUSTOM_PLUGINS_DIR/pisugar3.py
sudo sed -i "/            ui._state._state\['bat'].label = \"BAT:\"/c\            ui._state._state['bat'].label = \"\"" $CUSTOM_PLUGINS_DIR/pisugar3.py

echo "add GPS date/time and position info"
sudo sed -i '13i\from dateutil import parser' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '/            lat_pos = (127, 75)/c\            lat_pos = (220, 153)' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '/            lon_pos = (122, 84)/c\            lon_pos = (220, 163)' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '/            alt_pos = (127, 94)/c\            alt_pos = (220, 173)' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '102i\            time_pos = (220, 133)' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '103i\            date_pos = (220, 143)' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '113i\            date_pos = (220, 165)' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '114i\            time_pos = (220, 175)' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '154i\        ui.add_element(' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '155i\            "date",' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '156i\            LabeledValue(' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '157i\                color=BLACK,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '158i\                label="  ",' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '159i\                value="-",' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '160i\                position=date_pos,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '161i\                label_font=fonts.Small,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '162i\                text_font=fonts.Small,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '163i\                label_spacing=label_spacing,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '164i\            ),' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '165i\        )' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '166i\        ui.add_element(' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '167i\            "time",' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '168i\            LabeledValue(' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '169i\                color=BLACK,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '170i\                label="  ",' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '171i\                value="-",' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '172i\                position=time_pos,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '173i\                label_font=fonts.Small,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '174i\                text_font=fonts.Small,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '175i\                label_spacing=label_spacing,' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '176i\            ),' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '177i\        )' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '177a\ ' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i "184i\            ui.remove_element('date')" $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i "185i\            ui.remove_element('time')" $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i "197i\            altitude_in_feet = coords['Altitude'] * 3.28084" $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i "/            ui.set(\"altitude\", f\" {coords\['Altitude']:.1f}m \")/c\            ui.set(\"altitude\", f\" {altitude_in_feet:.0f} ft \")" $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i "198a\            local_time = parser.parse(coords['Date']).astimezone()" $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '199a\            ui.set("date", local_time.strftime("%a %b %d").__str__())' $CUSTOM_PLUGINS_DIR/gpsd.py
sudo sed -i '200a\            ui.set("time", local_time.strftime("%I:%M %p").__str__())' $CUSTOM_PLUGINS_DIR/gpsd.py

echo "disable LED on Pimoroni display hat mini"
sudo mkdir -p /etc/systemd/scripts
sudo bash -c 'cat > /etc/systemd/scripts/turnOffDisplayLED.py' << EOF
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
EOF
sudo bash -c 'cat > /etc/systemd/system/turnOffDisplayLED.service' << EOF
[Unit]
Description=Dim LED on Display HAT Mini
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/systemd/scripts/turnOffDisplayLED.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable turnOffDisplayLED.service

echo "replace bt-tether.py"
sudo cp $HOME/$BT_TETHER_DIR/bt-tether.py $HOME/bt-tether-original.py
sudo cp $HOME/Beepergotchi/bt-tether.py $HOME/$BT_TETHER_DIR/

echo "script complete, you can now reboot!"
exit 0
