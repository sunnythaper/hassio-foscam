# hassio-foscam

I have a few [Foscam R2s](http://amzn.to/2rtIE4G) and needed a way for them to interface with the new [Hass.io](https://home-assistant.io/hassio) image of [Home Assistant](https://home-assistant.io/) because the shell script based [Home Assistant Foscam Example](https://home-assistant.io/cookbook/foscam_away_mode_PTZ/) no longer worked due to curl being left out of Hass.io. What I ended up coming up with was this Hass.io add-on that triggers specific curl commands via a MQTT trigger.

Features:

* Ability to add multiple cameras
* Extremely fast motion detection status updates
* Simultaneous camera arm/disarm command execution (seriously looks so cool)
* Completely configurable via the Hass.io add-on panel within Home Assistant
* Ability to use "http" or "https" and to set a custom port
* Pan/Tilt/Zoom controls called via camera presets (currently only supports 2)

May add:

* FTP integration to allow for Hass.io configuration of destination for captures
* SSL Certificate support for increased security (currently only running locally myself so this is not yet a concern)
* Multiple preset control
* Additional API functionality available via Foscam's CGI-BIN API

Example
-------

I will go ahead and assume you already know how to add Hass.io add-ons for this example. The [Hass.io Documentation](https://home-assistant.io/hassio) gives a great run down if you are unfamiliar, much better than anything I would write and probably more up to date ;) Please continue this example after you have the add-on installed but not yet running.

Alright, so in our example we will configure two Foscam cameras with different login settings for each camera. We will arm these via a Home Assistant MQTT switch. We will check their progress via 4 MQTT sensors (arm status and motion detection for each of the 2 cameras). And finally we will have a beer.

Add-on Configuration
--------------------

To begin, we will first configure our settings for our camera setup. This is done within the Hass.io add-on panel via a JSON object.

```
{
  "mqtt_ip": "192.168.1.5",
  "mqtt_user": "testymctestorson",
  "mqtt_password": "testarino123",
  "mqtt_port": "1883",
  "parent_topic": "cameras/foscam",
  "wait_time": 6,
  "cameras": [
    {
      "protocol": "https",
      "ip": "192.168.1.43",
      "username": "testletmctestorson",
      "password": "testamundo544",
      "port": "443",
      "name": "porch",
      "preset_off": "Off",
      "preset_on": "On"
    },
    {
      "protocol": "https",
      "ip": "192.168.1.213",
      "username": "tessiemctestorson",
      "password": "testabammabobamma",
      "port": "443",
      "name": "backyard",
      "preset_off": "Off",
      "preset_on": "BackGate"
    }
  ]
}
```

Settings:
---------

**mqtt_ip:** The ip or hostname of the MQTT instance where you would like the data to go

**mqtt_user:** The username for your MQTT instance

**mqtt_password:** The password to the mqtt_user for your MQTT instance

**mqtt_port:** Typical setups use ports 1883 or 8883

**parent_topic:** This will be the first part of the MQTT topic that this script produces. More info below

**wait_time:** With the pan, tilt, and zoom changes we need to make between scenes, an appropriate wait time must be set otherwise motion detection will go off while camera is moving into position. Setting is in seconds (6 equates to 6 seconds of waiting after scene change is triggered)

**protocol:** Depending on your Foscam setup, this will either be "http" or "https"

**ip:** The ip or hostname of the Foscam camera you wish to control

**username:** The username for the Foscam camera you wish to control

**password:** The password for the Foscam camera you wish to control

**port:** The port for the camera you wish to control. Typically 80 (http) or 443 (https)

**name:** This will be the second part of the MQTT topic that this script produces. More info below

**preset_off:** You will need to create a preset on your Foscam camera of where you would like the camera to be positioned when DISARMED in Home Assistant

**preset_on:** You will need to create a preset on your Foscam camera of where you would like the camera to be positioned when ARMED in Home Assistant

MQTT Topics:
------------

This script will create a few topics in order to keep track of our arm status, motion detection status, and a topic to send an arm/disarm command. The topics are based off the following format:

```
parent_topic\name\setting
```

With the above example, we should see the following MQTT topics:

```
cameras/foscam # Used to send arm/disarm command
cameras/foscam/porch/motion_status # Will display either Armed or Disarmed based off a curl call to the camera
cameras/foscam/porch/motion_detect # Will display either None or Detected based off a curl call to the camera
cameras/foscam/backyard/motion_status
cameras/foscam/backyard/motion_detect
```

Home Assistant MQTT Switch
--------------------------

Now that we have the add-on setup properly, we must now add a switch within Home Assistant to trigger the script to arm/disarm. We can accomplish this by setting up an MQTT switch in our configuration.yaml file.

```
- platform: mqtt
  name: Camera Monitoring
  command_topic: cameras/foscam
  state_topic: cameras/foscam
  payload_on: arm
  payload_off: disarm
```

Now we should be able to place switch.camera_monitoring into our groups.yaml file and see our cameras do a syncronized dance.

Home Assistant MQTT Sensors
---------------------------

Now that we have the master on/off switch setup, we want to see if the switch has indeed worked for each camera and if it has, we want to be alerted of motion events! In your configuration.yaml file, enter the following to setup all our sensors.

```
- platform: mqtt
  name: Porch Status
  state_topic: "cameras/foscam/porch/motion_status"
- platform: mqtt
  name: Porch Motion
  state_topic: "cameras/foscam/porch/motion_detect"
- platform: mqtt
  name: Backyard Status
  state_topic: "cameras/foscam/backyard/motion_status"
- platform: mqtt
  name: Backyard Motion
  state_topic: "cameras/foscam/backyard/motion_detect"
```

Now we should be able to place sensor.porch_status, sensor.porch_motion, sensor.backyard_status, and sensor.backyard_motion into our groups.yaml file and get some feedback from our cameras in Home Assistant!

Bugs or Feature Requests
------------------------

This was my first Github project ever and I'm not a programmer by trade. This was simply to fill a need in my Home Assistant setup and I hope it helps others as well. If you want to see something changed, please open up an issue. I'll be checking them and anything I can change/do I will!
