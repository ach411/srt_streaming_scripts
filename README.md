# srt_streaming_scripts
Scripts that use FFMPEG to stream SRT

FFMPEG needs to be built with --enable-libsrt in order to use the 'srt://' URL

srt_daemon.sh runs in the background and launches FFMPEG
user_interface.sh provides a very basic interface
srt-streaming.service is the systemd unit file: copy into /etc/systemd/system/ folder
