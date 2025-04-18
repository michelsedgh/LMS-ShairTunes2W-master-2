# AirPlay2HTTP

A lightweight Docker container that turns AirPlay into an HTTP MP3 audio stream. This container is built on **Alpine Linux** and includes **shairport-sync**, **FFmpeg**, and **Nginx**.

This project was created to stream audio to a Toniebox. Special thanks to Team RevvoX for developing [TeddyCloud](https://github.com/toniebox-reverse-engineering/teddycloud), which enables audio streaming (and much more) on Tonieboxes.

## Building the Docker Image

To build the Docker image from the provided `Dockerfile`, run the following command in the directory containing the `Dockerfile`:

```sh
docker build -t airplay2http .
```

## Configuring the AirPlay Receiver Name

To set the name of the AirPlay receiver, modify `shairport-sync.conf` inside the container. You can also modify this configuration before building the image to bake in your preferred settings. The default configuration is:

```c
general =
{
    name: "Toniebox";
    output_backend: "pipe";
};

pipe =
{
    name: "/tmp/shairport-sync-output";
    format: "44100:16:2";  // CD-quality stereo
};
```

To change the name, update the `name` field under `general`:

```c
    name: "My AirPlay Receiver";
```

## Accessing the HTTP Stream

Once the container is running, you can access the AirPlay stream at:

```
http://<container-ip>:8000/stream
```

Replace `<container-ip>` with the actual IP address of the Docker container.

## Networking Requirement

To properly advertise the AirPlay receiver, the container must have **network access via a Docker macvlan**. Ensure your container is started with a macvlan network to allow correct AirPlay discovery.

Example Docker network setup:

```sh
docker network create -d macvlan \
    --subnet=192.168.1.0/24 \
    --gateway=192.168.1.1 \
    -o parent=eth0 airplay_net
```

Then start the container with:

```sh
docker run --rm --network airplay_net --name airplay2http airplay2http
```

Now, the AirPlay receiver should be discoverable, and the stream should be accessible at `http://<container-ip>:8000/stream`.

---

Enjoy streaming your AirPlay audio over HTTP! 🎵

