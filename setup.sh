#!/bin/bash

NVDS_VERSION=6.0
CUDA_VER=11.4
PAHO_MQTT_VERSION=v1.3.10
DS_LIB=/opt/nvidia/deepstream/deepstream/lib
DS_SAMPLE=/opt/nvidia/deepstream/deepstream/sources/apps/sample_apps
APP_INSTALL=0
APP_CONFIG=0
APP_RTSP=0
SINK0=
MQTT_HOST=
MQTT_PAYLOAD=
MQTT_PORT=
MQTT_TOPIC=
SRC_ID=
SRC_ENABLE=
SRC_TYPE=
SRC_URI=
SRC_NUM=
SRC_CAM_WIDTH=
SRC_CAM_HEIGHT=
SRC_CAM_FPS_N=
SRC_CAM_FPS_D=
SRC_CAM_V4L2_DEV_NODE=
DISPLAY_ROWS=
DISPLAY_COLUMNS=

USAGE="$(basename "$0") \$ARGS

where \$ARGS:
    -a|--mqtt_payload (0)Deepstream schema (1)Minimal (256)Reserved (257)Custom
    -f|--config       sample_apps configure
    -h|--help         show this help text
    -m|--mqtt_host    MQTT broker IP address
    -o|--output       Graphic display type - 1=FakeSink 2=EglSink 3=File
    -p|--mqtt_port    MQTT broker port number
    -r|--rtsp         RTSP streaming
    -s|--sample       sample_apps folder name, Ex. deepstream-test5
    -t|--mqtt_topic   MQTT broker topic
    -u|--src_id       source id
       --src_enable   source enable or disable
       --src_type     Type of source; other properties of the source
                      1=Camera(V4L2) 2=URI 3=MultiURI 4=RTSP 5=Camera(CSI)
       --src_num      Number of sources. Valid only when type=3.
       --src_uri      URI to the encoded stream. The URI can be a file, an HTTP URI,
                      or an RTSP live source. Valid when type=2 or 3. With MultiURI,
                      the %d format specifier can also be used to specify multiple sources.
                      The application iterates from 0 to num-sources 1 to generate the actual URIs.
                      Ex. file://../../../../../samples/streams/sample_1080p_h264.mp4
       --src_cam_width         Width of frames to be requested from the camera, in pixels. Valid when type=1 or 5. Ex. 640
       --src_cam_height        Height of frames to be requested from the camera, in pixels. Valid when type=1 or 5. Ex. 480
       --src_cam_fps_n         Numerator part of a fraction specifying the frame rate requested by the camera, in frames/sec. Valid when the type=1 or 5. Ex. 30
       --src_cam_fps_d         Denominator part of a fraction specifying the frame rate requested from the camera, in frames/sec. Valid when type=1 or 5. Ex. 1
       --src_cam_v4l2_dev_node Number of the V4L2 device node. For example, /dev/video<num> for the open source V4L2 camera capture path. Ex. 0
    --display_rows    Number of rows in the tiled 2D array.
    --display_columns Number of columns in the tiled 2D array.
"

test5_config_sink3="[sink3]\n
enable=1\n
#Type - 1=FakeSink 2=EglSink 3=File 4=RTSPStreaming\n
type=4\n
#1=h264 2=h265\n
codec=1\n
sync=0\n
bitrate=4000000\n
# set below properties in case of RTSPStreaming\n
rtsp-port=8554\n
udp-port=5400\n\n"

test5_config_sink3_v2="[sink3]
enable=1
#Type - 1=FakeSink 2=EglSink 3=File 4=RTSPStreaming
type=4
#1=h264 2=h265
codec=1
sync=0
bitrate=4000000
# set below properties in case of RTSPStreaming
rtsp-port=8554
udp-port=5400\n"

function check_arg_2 () {

	local w c
	w=$1
	c=${w:0:1}
	if [[ -z "$w" ]] || [[ "$c" = '-' ]]; then
		echo "Argument error!!"
		return 1
	fi
	return 0
}

function paho_mqtt_install () {

	echo "###############################################"
	echo "### Install eclipse/paho.mqtt.c version 1.3.10"
	echo "###############################################"
	git clone --depth 1 --branch ${PAHO_MQTT_VERSION} https://github.com/eclipse/paho.mqtt.c paho.mqtt.c
	sudo apt-get install libssl-dev -y
	pushd paho.mqtt.c
	make
	sudo make install
	popd

}

# -o|--output      Graphic display type - 1=FakeSink 2=EglSink 3=File\n
function config_sink0 () {

	local p

	[ -z "${SINK0}" ] && return

	p=`sed -n '/sink0/=' ${DS_APP}/configs/${CONF}`
	if [ -n "${p}" ]; then
		sudo sed -i -e "${p},$((${p}+3)) s/^type=[[:digit:]]\+/type=${SINK0}/g" ${DS_APP}/configs/${CONF}
		if [ -n "${SINK0}" -a "${SINK0}" -eq 2 ]; then
			echo "Please remember to set shell env var DISPLAY=:1 before running!!"
		fi
	fi
}

function config_sink1_enable_MsgConvBroker () {

	local p

	p=`sed -n '/sink1/=' ${DS_APP}/configs/${CONF}`
	if [ -n "${p}" ]; then
		sudo sed -i -e "${p},$((${p}+3)) s/^enable=[[:digit:]]\+/enable=1/g" ${DS_APP}/configs/${CONF}
	fi

	p=
	p=`sed -n '/MsgConvBroker/=' ${DS_APP}/configs/${CONF}`
	if [ -n "${p}" ]; then
		sudo sed -i -e "${p},$((${p}+3)) s/^type=[[:digit:]]\+/type=6/g" ${DS_APP}/configs/${CONF}
	fi

}

function config_mqtt () {

	local s s2 s21 s22 s23

	sudo sed -i "/^msg-broker-proto-lib=/c\msg-broker-proto-lib=${DS_LIB}/libnvds_mqtt_proto.so" ${DS_APP}/configs/${CONF}
	# msg-broker-conn-str=127.0.0.1;1883;edgex/AnalyticsData
	s=`grep msg-broker-conn-str= ${DS_APP}/configs/${CONF}`
	if [ -n "${s}" ]; then
		s2=`echo $s | cut -d= -f2`
	fi
	if [ -n "${s2}" ]; then
		s21=`echo $s2 | cut -d\; -f1`
		s22=`echo $s2 | cut -d\; -f2`
		s23=`echo $s2 | cut -d\; -f3`
	fi
	# echo "s21=$s21 s22=$s22 s23=$s23"
	if [ -n "${MQTT_HOST}" ]; then
		config_sink1_enable_MsgConvBroker
		s21=$MQTT_HOST
	fi
	if [ -n "${MQTT_PORT}" ]; then
		s22=$MQTT_PORT
	fi
	if [ -n "${MQTT_TOPIC}" ]; then
		s23=$MQTT_TOPIC
	fi
	# echo "s21=$s21 s22=$s22 s23=$s23"
	sudo sed -i "/^msg-broker-conn-str=/c\msg-broker-conn-str=${s21};${s22};${s23}" ${DS_APP}/configs/${CONF}

	s=`grep topic= ${DS_APP}/configs/${CONF}`
	if [ -n "${s}" ]; then
		s2=`echo $s | cut -d= -f2`
	fi

	if [ -n "${MQTT_TOPIC}" ]; then
		s2=$MQTT_TOPIC
	fi
	# echo "s2=$s2"
	sudo sed -i "/^topic=/c\topic=${s2}" ${DS_APP}/configs/${CONF}

}

function config_msgconv () {

	local p

	[ -z "${MQTT_PAYLOAD}" ] && return

	p=`sed -n '/sink1/=' ${DS_APP}/configs/${CONF}`
	if [ -n "${p}" ]; then
		sudo sed -i -e "${p},$((${p}+9)) s/^msg-conv-payload-type=[[:digit:]]\+/msg-conv-payload-type=${MQTT_PAYLOAD}/" ${DS_APP}/configs/${CONF}
		config_sink1_enable_MsgConvBroker
	fi

}

function config_rtsp () {

	local p pp ppp c

	[ -z "${APP_RTSP}" ] && return

	p=`sed -n '/sink3/=' ${DS_APP}/configs/${CONF}`
	# echo "APP_RTSP=${APP_RTSP}"
	# echo "p=${p}"
	if [ "${APP_RTSP}" -eq 1 ]; then
		if [ -z "${p}" ]; then
			pp=`sed -n '/sink2/=' ${DS_APP}/configs/${CONF}`
			# echo "pp=${pp}"
			c=`wc -l ${DS_APP}/configs/${CONF} | cut -d' ' -f1`
			# echo "c=${c}"
			ppp=`sed -n -e "${pp},${c}p" ${DS_APP}/configs/${CONF} | sed -n '/[^[:blank:]]/d;=;q'`
			# echo "ppp=${ppp}"
			awk -v line="$((${pp}+${ppp}-1))" -v text="${test5_config_sink3_v2}" '{print} NR==line{print text}' ${DS_APP}/configs/${CONF} > /tmp/${CONF}
			sudo cp /tmp/${CONF} ${DS_APP}/configs/${CONF}
			# echo -e $test5_config_sink3 >> ${DS_APP}/configs/${CONF}
		fi
	else
		if [ -n "${p}" ]; then
			sudo sed -i "${p},$((${p}+12))d" ${DS_APP}/configs/${CONF}
		fi
	fi

}

function config_source () {

	local n line flag

	[ -z "$SRC_ID" ] && return
	[ -z "$SRC_ENABLE" ] && return
	[ -z "$SRC_TYPE" ] && return
	[ -z "$SRC_NUM" ] && return

	test5_config_source="[source${SRC_ID}]
enable=${SRC_ENABLE}
#Type - 1=Camera(V4L2) 2=URI 3=MultiURI 4=RTSP 5=Camera(CSI)
type=${SRC_TYPE}
num-sources=${SRC_NUM}
uri=${SRC_URI}
camera-width=${SRC_CAM_WIDTH}
camera-height=${SRC_CAM_HEIGHT}
camera-fps-n=${SRC_CAM_FPS_N}
camera-fps-d=${SRC_CAM_FPS_D}
camera-v4l2-dev-node=${SRC_CAM_V4L2_DEV_NODE}
gpu-id=0
nvbuf-memory-type=0"

	# n=`grep -E "\[source[[:digit:]]\]" ${DS_APP}/configs/${CONF} | wc -l`
	n=`grep -E "\[source${SRC_ID}\]" ${DS_APP}/configs/${CONF} | wc -l`

	rm -f ${DS_APP}/configs/${CONF}.tmp 2>&1 > /dev/null
	flag=0
	if [ -n "${n}" ]; then
		cat ${DS_APP}/configs/${CONF} | while read line
		do
			if [[ $line == "[source${SRC_ID}]"* ]]; then
				flag=1
				echo "${test5_config_source}" | sed 's/uri=$/#uri=/' \
					| sed 's/camera-width=$/#camera-width=/' \
					| sed 's/camera-height=$/#camera-height=/' \
					| sed 's/camera-fps-n=$/#camera-fps-n=/' \
					| sed 's/camera-fps-d=$/#camera-fps-d=/' \
					| sed 's/camera-v4l2-dev-node=$/#camera-v4l2-dev-node=/' \
					      >> ${DS_APP}/configs/${CONF}.tmp
			elif [ "$flag" -eq 1 ]; then
				if [ -z "$line" ]; then
					flag=0
					echo "" >> ${DS_APP}/configs/${CONF}.tmp
				fi
			else
				echo "${line}" >> ${DS_APP}/configs/${CONF}.tmp
			fi
		done
	else
		cat ${DS_APP}/configs/${CONF} | while read line
		do
			# [ -z "$line" ] && continue
			echo "${line}" >> ${DS_APP}/configs/${CONF}.tmp
		done
	fi

	cp ${DS_APP}/configs/${CONF}.tmp ${DS_APP}/configs/${CONF}
}

function config_display () {

	local p flag

	flag=0

	if [ -n "$DISPLAY_ROWS" ]; then
		flag=1
		sed -i "s/rows=[[:digit:]]\+/rows=${DISPLAY_ROWS}/" ${DS_APP}/configs/${CONF}
	fi

	if [ -n "$DISPLAY_COLUMNS" ]; then
		flag=1
		sed -i "s/columns=[[:digit:]]\+/columns=${DISPLAY_COLUMNS}/" ${DS_APP}/configs/${CONF}
	fi

	if [ "$flag" -eq 1 ]; then
		p=`sed -n '/tiled-display/=' ${DS_APP}/configs/${CONF}`
		[ -n "${p}" ] && sudo sed -i -e "${p},$((${p}+3)) s/^enable=[[:digit:]]\+/enable=1/g" ${DS_APP}/configs/${CONF}
	fi

}

if [ "$#" -eq 0 ]; then
	# printf "%s" "$USAGE"
	echo "$U"
	# echo -e "$USAGE"
	exit 0
fi

while [[ $# -gt 0 ]]; do
	case $1 in
		-s|--sample)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			APP="$2"
			shift # past argument
			shift # past value
			;;
		-i|--install)
			APP_INSTALL=1
			shift # past argument
			;;
		-f|--config)
			APP_CONFIG=1
			shift # past argument
			;;
		-o|--output)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SINK0="$2"
			shift # past argument
			shift # past value
			;;
		-m|--mqtt_host)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			MQTT_HOST="$2"
			shift # past argument
			shift # past value
			;;
		-p|--mqtt_port)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			MQTT_PORT="$2"
			shift # past argument
			shift # past value
			;;
		-t|--mqtt_topic)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			MQTT_TOPIC="$2"
			shift # past argument
			shift # past value
			;;
		-a|--mqtt_payload)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			MQTT_PAYLOAD="$2"
			shift # past argument
			shift # past value
			;;
		-r|--rtsp)
			APP_RTSP=1
			shift # past argument
			;;
		-u|--src_id)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_ID="$2"
			shift # past argument
			shift # past value
			;;
		--src_enable)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_ENABLE="$2"
			shift # past argument
			shift # past value
			;;
		--src_type)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_TYPE="$2"
			shift # past argument
			shift # past value
			;;
		--src_num)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_NUM="$2"
			shift # past argument
			shift # past value
			;;
		--src_uri)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_URI="$2"
			shift # past argument
			shift # past value
			;;
		--src_cam_width)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_CAM_WIDTH="$2"
			shift # past argument
			shift # past value
			;;
		--src_cam_height)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_CAM_HEIGHT="$2"
			shift # past argument
			shift # past value
			;;
		--src_cam_fps_n)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_CAM_FPS_N="$2"
			shift # past argument
			shift # past value
			;;
		--src_cam_fps_d)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_CAM_FPS_D="$2"
			shift # past argument
			shift # past value
			;;
		--src_cam_v4l2_dev_node)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			SRC_CAM_V4L2_DEV_NODE="$2"
			shift # past argument
			shift # past value
			;;
		--display_rows)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			DISPLAY_ROWS="$2"
			shift # past argument
			shift # past value
			;;
		--display_columns)
			check_arg_2 "$2" && [ "$?" -eq 1 ] && exit 1
			DISPLAY_COLUMNS="$2"
			shift # past argument
			shift # past value
			;;
		-h|--help)
			echo -e $USAGE
			exit 0
			;;
		*)
			echo "Unknown option $1"
			exit 1
			;;
	esac
done

if [ -n "$APP" ]; then
	DS_APP=${DS_SAMPLE}/${APP}
	if [ ! -d "${DS_APP}" ]; then
		echo "No exist app ${DS_APP}"
		exit 1
	fi
fi

if [ -n "${DS_APP}" ]; then
	if [ "${APP}" = "deepstream-test5" ]; then
		if [ "${APP_INSTALL}" -eq 1 ]; then
			paho_mqtt_install

			echo "###############################################"
			echo "### Make deepstream sample ${APP}"
			echo "###############################################"
			sudo apt-get install libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev libgstrtspserver-1.0-dev libx11-dev libjson-glib-dev -y
			pushd ${DS_APP}
			sudo sed -i "/^CUDA_VER/c\CUDA_VER?=${CUDA_VER}" Makefile
			make
			popd

			echo "###############################################"
			echo "### Install libs mqtt adaptor and msgconv to ${DS_LIB}"
			echo "###############################################"
			sudo cp lib/libnvds_mqtt_proto_${NVDS_VERSION}.so ${DS_LIB}
			sudo ln -sf libnvds_mqtt_proto_${NVDS_VERSION}.so ${DS_LIB}/libnvds_mqtt_proto.so
		fi
		if [ "${APP_CONFIG}" -eq 1 ]; then
			CONF=test5_config_file_src_infer.txt
			echo "###############################################"
			echo "### Configure ${APP} ${CONF}"
			echo "###############################################"
			sudo cp ${DS_APP}/configs/${CONF} ${DS_APP}/configs/${CONF}.bak

			config_sink0
			config_mqtt
			config_msgconv
			config_rtsp
			config_source
			config_display
			echo "Configure done. Please run test5 with below command:"
			echo "sudo ./deepstream-test5-app -c configs/test5_config_file_src_infer.txt"
		fi
	else
		echo "Not support ${APP} now!!"
		exit 1
	fi
fi
