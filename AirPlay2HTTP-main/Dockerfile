# Base image
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    shairport-sync \
    alsa-utils \
    libmad \
    avahi \
    dbus \
    ffmpeg \
    nginx \
    socat

# Copy configuration files (to be created below)
COPY entrypoint.sh /entrypoint.sh
COPY shairport-sync.conf /etc/shairport-sync.conf
COPY avahi-daemon.conf /etc/avahi/avahi-daemon.conf
COPY nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /var/run/dbus && chmod 755 /var/run/dbus
RUN mkfifo /tmp/stream.mp3

# Command to run both services
CMD ["/entrypoint.sh"]
