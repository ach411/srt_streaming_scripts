#!/bin/bash
# daemon script: to be started by systemd service

set -euo pipefail

IFS=$'\t\b'

# Possible args
FFMPEG_PATH="${1:-/home/srt/bin/ffmpeg}"
VIDEO_FOLDER_PATH="${2:-/srv/videos}"
DEFAULT_VIDEO_FILE_PATH="${3:-/home/srt/Turtle_GOPR6239_1_2Mbps_1280x720.mov}"
SRT_URL="${4:-srt://channellink.vitec.com:7564}"
SRT_LOG_PATH="${5:-/home/srt/srt.log}"
PIPE_FILE1="${6:-/tmp/srt_daemon_pipe1}"
PIPE_FILE2="${7:-/tmp/srt_daemon_pipe2}"

# since ffmpeg is quite unstable (e.g. will stop if network is disconnected for a short time)
loop_over_ffmpeg()
{
    set +e
    while true ; do
        ${FFMPEG_PATH} -loglevel warning -stream_loop -1 -re -i ${VIDEO_FILE_PATH} -codec copy -f mpegts ${SRT_URL} 2>> ${SRT_LOG_PATH}
    done
    set -e
}

main()
{
    # create flip-flop named pipes to communicate with user interface process
    if ! [ -p ${PIPE_FILE1} ] ; then
        mkfifo ${PIPE_FILE1}
    fi
    if ! [ -p ${PIPE_FILE2} ] ; then
        mkfifo ${PIPE_FILE2}
    fi

    # send the info to the user interface process
    echo ${FFMPEG_PATH} > ${PIPE_FILE1}
    echo ${VIDEO_FOLDER_PATH} > ${PIPE_FILE2}
    echo ${DEFAULT_VIDEO_FILE_PATH} > ${PIPE_FILE1}
    echo ${SRT_URL} > ${PIPE_FILE2}
    echo ${SRT_LOG_PATH} > ${PIPE_FILE1}

    while true ; do

        # read info from the user interface process
        read < ${PIPE_FILE2} VIDEO_FILE_PATH
        read < ${PIPE_FILE1} SRT_URL

        sleep 1

        echo "### ffmpeg launched at " $(date) > ${SRT_LOG_PATH}

        coproc FFMPEG_LOOP_PROC ( loop_over_ffmpeg )

        echo ${FFMPEG_LOOP_PROC_PID} > ${PIPE_FILE2}

        # wait until the child process is finished
        wait

        echo "### ffmpeg stopped at " $(date) >> ${SRT_LOG_PATH}

        # tell the user interface process that loop_over_ffmpeg has closed
        echo "ffmpeg has closed" > ${PIPE_FILE1}
    done

}

main "$@"

