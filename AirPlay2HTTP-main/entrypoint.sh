#!/bin/sh
set -e  # Exit on error

# Start dbus
dbus-daemon --system --nofork &  
sleep 5  # Allow it to initialize

# Start Avahi
avahi-daemon --no-chroot --debug &  
sleep 2  

# Start Shairport Sync  
shairport-sync &  
sleep 2  

# Start FFmpeg to process audio  
ffmpeg -nostdin -f s16le -ar 44100 -ac 2 -i /tmp/shairport-sync-output \
       -f mp3 -content_type audio/mpeg -y /tmp/stream.mp3 &  
sleep 2  

# Start Socat to serve the MP3 stream  
socat -u OPEN:/tmp/stream.mp3 TCP-LISTEN:9000,reuseaddr,fork &  
sleep 2  

# Start Nginx  
nginx &  
sleep 2  

# Keep container alive
tail -f /dev/null

