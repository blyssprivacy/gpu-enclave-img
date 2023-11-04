#!/bin/bash
DOCKER_IMG=$(cat /proc/cmdline | grep -o '\bblyss_docker_img=[^ ]*')

# if not supplied, use default
DOCKER_IMG=${DOCKER_IMG:-nginx@sha256:0d60ba9498d4491525334696a736b4c19b56231b972061fab2f536d48ebfd7ce}

/usr/bin/docker run --name main -p 8080:80 --rm --runtime=nvidia --gpus all $DOCKER_IMG