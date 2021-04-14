#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

MQTT_IP=$(jq --raw-output '.mqtt_ip' $CONFIG_PATH)
MQTT_PORT=$(jq --raw-output '.mqtt_port' $CONFIG_PATH)
MQTT_USER=$(jq --raw-output '.mqtt_user' $CONFIG_PATH)
MQTT_PASSWORD=$(jq --raw-output '.mqtt_password' $CONFIG_PATH)
PARENT_TOPIC=$(jq --raw-output ".parent_topic" $CONFIG_PATH)
WAIT_TIME=$(jq --raw-output '.wait_time' $CONFIG_PATH)
CAMERAS=$(jq --raw-output ".cameras | length" $CONFIG_PATH)

for (( i=0; i < "$CAMERAS"; i++ )); do
  INIT[$i]=true
done

foscam_arm() {
  foscam_scene $1 $2 $3 $4 $5 $6
  sleep $WAIT_TIME
  foscam_motion_enable $1 $2 $3 1 $5 $6
  echo "Camera $7 has been >>>ARMED<<<"
}

foscam_disarm() {
  foscam_motion_enable $1 $2 $3 0 $5 $6
  sleep $WAIT_TIME
  foscam_scene $1 $2 $3 $4 $5 $6
  echo "Camera $7 has been DISARMED"
}

foscam_scene() {
  curl -k -s "$1://$2:$3/cgi-bin/CGIProxy.fcgi?cmd=ptzGotoPresetPoint&name=$4&usr=$5&pwd=$6" > /dev/null
}

foscam_motion_enable() {
  curl -k -s "$1://$2:$3/cgi-bin/CGIProxy.fcgi?cmd=setMotionDetectConfig1&isEnable=$4&linkage=14&snapInterval=1&triggerInterval=0&isMovAlarmEnable=1&isPirAlarmEnable=1&schedule0=281474976710655&schedule1=281474976710655&schedule2=281474976710655&schedule3=281474976710655&schedule4=281474976710655&schedule5=281474976710655&schedule6=281474976710655&x1=56y1=103&width1=10000&height1=10000&sensitivity1=1&valid1=1&x2=0&y2=0&width2=0&height2=0&sensitivity2=1&valid2=0&x3=0&y3=0&width3=0&height3=0&sensitivity3=1&valid3=0&x4=0y4=0&width4=0&height4=0&sensitivity4=1&valid4=0&usr=$5&pwd=$6" > /dev/null
}

foscam_motion_status() {
  while /bin/true; do
    STATUS=$(curl -k --silent "$1://$2:$3/cgi-bin/CGIProxy.fcgi?cmd=getMotionDetectConfig1&usr=$4&pwd=$5" | grep -oE "<isEnable>([0-9])" | grep -oE "([0-9])")
    OUTPUT=""

    if [ $STATUS =  "0" ]; then
      OUTPUT="Disarmed"
    fi

    if [ $STATUS =  "1" ]; then
      OUTPUT="Armed"
    fi

    mosquitto_pub -h "$MQTT_IP" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "$PARENT_TOPIC/$6/motion_status" -m "$OUTPUT" || true

    sleep 1
  done
}

foscam_events_detect() {
  while /bin/true; do
    STATUS=$(curl -k --silent "$1://$2:$3/cgi-bin/CGIProxy.fcgi?cmd=getDevState&usr=$4&pwd=$5")
    MOTION=$STATUS | grep -oE "<motionDetectAlarm>([0-9])" | grep -oE "([0-9])"
	OUTPUT=""

    if [ $MOTION = "2" ]; then
      OUTPUT="true"
	  echo "Motion detected on $6"
	elif [ $MOTION = "1" ]; then
	  OUTPUT="false"
	  echo "Motion NOT detected on $6"
	elif [ $MOTION = "0" ]; then
	  OUTPUT="disabled"
	  echo "Motion disabled on $6"
    else
      OUTPUT="ERROR"
	  echo "ERROR processing motion"
    fi

    mosquitto_pub -h "$MQTT_IP" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "$PARENT_TOPIC/$6/motion_detect" -m "$OUTPUT" || true

	SOUND=$STATUS | grep -oE "<soundAlarm>([0-9])" | grep -oE "([0-9])"
	OUTPUT=""

	if [ $SOUND = "2" ]; then
      OUTPUT="true"
	  echo "Sound detected on $6"
	elif [ $SOUND = "1" ]; then
	  OUTPUT="false"
	  echo "Sound NOT detected on $6"
	elif [ $SOUND = "0" ]; then
	  OUTPUT="disabled"
	  echo "Sound disabled on $6"
    else
      OUTPUT="ERROR"
	  echo "ERROR processing sound"
    fi

    mosquitto_pub -h "$MQTT_IP" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "$PARENT_TOPIC/$6/sound_detect" -m "$OUTPUT" || true

	IRLED=$STATUS | grep -oE "<infraLedState>([0-9])" | grep -oE "([0-9])"
	OUTPUT=""

	if [ $IRLED = "1" ]; then
	  OUTPUT="true"
	  echo "IR LED on $6"
	elif [ $IRLED = "0" ]; then
	  OUTPUT="false"
	  echo "IR LED off $6"
    else
      OUTPUT="ERROR"
	  echo "ERROR processing IR LED state"
    fi

    mosquitto_pub -h "$MQTT_IP" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "$PARENT_TOPIC/$6/ir_led_status" -m "$OUTPUT" || true

    sleep 1
  done
}

while read -r message
do

  for (( i=0; i < "$CAMERAS"; i++ )); do
    NAME=$(jq --raw-output ".cameras[$i].name" $CONFIG_PATH)
    IP=$(jq --raw-output ".cameras[$i].ip" $CONFIG_PATH)
    PORT=$(jq --raw-output ".cameras[$i].port" $CONFIG_PATH)
    PROTOCOL=$(jq --raw-output ".cameras[$i].protocol" $CONFIG_PATH)
    USERNAME=$(jq --raw-output ".cameras[$i].username" $CONFIG_PATH)
    PASSWORD=$(jq --raw-output ".cameras[$i].password" $CONFIG_PATH)
    PRESET_ON=$(jq --raw-output ".cameras[$i].preset_on" $CONFIG_PATH)
    PRESET_OFF=$(jq --raw-output ".cameras[$i].preset_off" $CONFIG_PATH)

	echo "Initializing $NAME camera"

    if [ $INIT[$i] ]; then
      foscam_motion_status $PROTOCOL $IP $PORT $USERNAME $PASSWORD $NAME &
      foscam_events_detect $PROTOCOL $IP $PORT $USERNAME $PASSWORD $NAME &
      INIT[$i]=false
    fi

    case $message in
    arm)
      foscam_arm $PROTOCOL $IP $PORT $PRESET_ON $USERNAME $PASSWORD $NAME &
      ;;
    disarm)
      foscam_disarm $PROTOCOL $IP $PORT $PRESET_OFF $USERNAME $PASSWORD $NAME &
      ;;
    esac
  done

done < <(mosquitto_sub -h "$MQTT_IP" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "$PARENT_TOPIC" -q 1)
