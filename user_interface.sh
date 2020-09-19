#!/bin/bash
# User interface script: to be started after login (for instance, from .bashrc file)

set -euo pipefail

IFS=$'\t\b'

#only variables that are control from this script
PRESS_ANY_KEY_ENABLED="${PRESS_ANY_KEY_ENABLED:-yes}"
PIPE_FILE1="${PIPE_FILE1:-/tmp/srt_daemon_pipe1}"
PIPE_FILE2="${PIPE_FILE2:-/tmp/srt_daemon_pipe2}"

trap '' SIGINT
trap '' SIGSTOP

# Global variables
FFMPEG_PATH=""
VIDEO_FOLDER_PATH=""
DEFAULT_VIDEO_FILE_PATH=""
SRT_URL=""
SRT_LOG_PATH=""

declare -A LIST_FILES

press_any_key()
{
	if [ "${PRESS_ANY_KEY_ENABLED}" = "yes" ] ; then
		echo -n "Press any key to continue"
		read -s -n 1
		echo -e "\r                          "
		echo -ne "\r"
	fi
}

display_list_files()
{
	local counter=0
	for file in $(ls ${VIDEO_FOLDER_PATH})
	do
		counter=$((counter+1))
		echo "${counter} - ${file}"
		LIST_FILES[${counter}]="${VIDEO_FOLDER_PATH}/${file}"
	done
}

choose_file_to_stream()
{
	local choice
    local default_file_base=$(basename ${DEFAULT_VIDEO_FILE_PATH})

	# while [ -z $choice ] || [ $choice -gt ${#LIST_FILES[@]} ]
    while true ; do
		clear
		echo "### Please choose file # to play"
		echo "0 - Default (${default_file_base})"
		LIST_FILES[0]=${DEFAULT_VIDEO_FILE_PATH}
		display_list_files
		read choice
        if [ -n $choice ] && [ $choice -le ${#LIST_FILES[@]} ] ; then
            break
        fi
	done

	echo ${LIST_FILES[${choice}]} > ${PIPE_FILE2}
}

is_url_valid()
{
	if echo "${1}" | grep -i '^srt://[--._[:alnum:]]\+:[[:digit:]]\+$' > /dev/null ; then
        return 0
    else
        return 1
    fi
}

read_stream_url()
{
    local user_url=""
    while true ; do
        clear
        echo "### Enter srt URL (press enter for default: ${SRT_URL})"
        read user_url
        if [ -n "${user_url}" ] ; then
            is_url_valid "${user_url}" && SRT_URL="${user_url}" && break
        else
            is_url_valid "${SRT_URL}" && break
        fi
    done

    echo "${SRT_URL}" > ${PIPE_FILE1}
}

main()
{

    # get the info from the daemon process
    read < ${PIPE_FILE1} FFMPEG_PATH
    read < ${PIPE_FILE2} VIDEO_FOLDER_PATH
    read < ${PIPE_FILE1} DEFAULT_VIDEO_FILE_PATH
    read < ${PIPE_FILE2} SRT_URL
    read < ${PIPE_FILE1} SRT_LOG_PATH

    while true; do

        clear

        echo "### Welcome to the SRT Streaming live ISO"
        echo "### You can either choose to upload a video file or use default file (Turtles)"
        echo "### To upload the video, open an explorer to \\\SRT-STREAMING-L"
        echo "### and copy the video in 'videos' folder"
        echo "### You can also use one of these IP addresses detected"
        /sbin/ifconfig 2> /dev/null | grep 'inet' | awk '{print $2}'
        echo "### Warning: This live ISO does NOT transcode the video"
        echo "###          It will just encapsulate the codec to mpegts and srt"
        echo "###          make sure the video has reasonable bitrate"
        echo
        press_any_key

        choose_file_to_stream

        read_stream_url

        echo "starting streaming... Press CTRL+C to stop streaming"

        read < ${PIPE_FILE2} pid_ffmpeg_loop

        # kill both ffmpeg and its loop processes
        trap "kill ${pid_ffmpeg_loop}; killall ffmpeg" SIGINT

        read < ${PIPE_FILE1} dummy_value

        trap '' SIGINT

        cat ${SRT_LOG_PATH}

        press_any_key
    done

}

main "$@"
