#!/bin/bash

extract_kernel_parameter_value() {
  input_data="$(cat)"
  key="$1"
  standard_matcher="([a-zA-Z0-9/\\@#\$%^&\!*\(\)'\"=:,._-]+)"
  quoted_matcher="\"([a-zA-Z0-9/\\@#\$%^&\!*\(\)',=: ._-]+)\""
  [ $# -gt 1 ] && standard_matcher="$2" && quoted_matcher="$2"
  value="$(printf '%s' "$input_data" | sed -rn "s/.* ?${key}=${standard_matcher} ?(.*)+?/\1/p")"
  if echo "$value" | grep -Eq '^"'; then
    value="$(printf "%s\n" "$input_data" | sed -rn "s/.* ?${key}=${quoted_matcher} ?(.*)+?/\1/p")"
  fi
  printf "%s\n" "$value"
}

get_kernel_parameter() {
  parameter_value=$(cat /proc/cmdline | extract_kernel_parameter_value "$@")
  if [ -z "$parameter_value" ]; then
    return 1
  else
    printf "%s\n" "$parameter_value"
  fi
}

has_cmd_word() {
  for k in "$@"; do
    if cat /proc/cmdline | grep -Eq " ${k}(=.*)? |^${k}(=.*)? | ${k}(=.*)?\$"; then
      return 0
    fi
  done
  return 1
}

# if we don't see blyss_docker_img, exit
if ! has_cmd_word blyss_docker_img; then
  echo "No blyss_docker_img parameter supplied, exiting"
  exit 1
fi


# SHIM_DOCKER_IMG=$(cat /proc/cmdline | grep -o '\bblyss_shim_docker_img=[^ ]*' | sed -nr 's/blyss_shim_docker_img=(.+)/\1/p')

APP_DOCKER_IMG=$(get_kernel_parameter blyss_docker_img)
UI_DOCKER_IMG=$(get_kernel_parameter blyss_ui_docker_img)
SHIM_DOCKER_IMG=$(get_kernel_parameter blyss_shim_docker_img)

# If app not supplied, use default
APP_DOCKER_IMG=${APP_DOCKER_IMG:-nginx@sha256:0d60ba9498d4491525334696a736b4c19b56231b972061fab2f536d48ebfd7ce}
UI_DOCKER_IMG=${UI_DOCKER_IMG:-ghcr.io/mckaywrigley/chatbot-ui@sha256:8c60abae8a34fd43f7015c124e0b972839e0efb35c06cd31cd1ec1ed9a57ceeb}

# Run the shim
# Ports are: host[80/443] -> [80/443]shim -> host[8080] -> [8000]app
docker network create --driver bridge bridge-network
/usr/bin/docker run -d --name shim --rm --runtime=nvidia --gpus all --privileged \
  --network bridge-network \
  -p 80:80 -p 443:443 \
  $SHIM_DOCKER_IMG

# Wait until server is up
sleep 5
until $(curl --output /dev/null --silent --head --fail http://localhost:80); do
    echo "Waiting for shim to start..."
    sleep 2
done

# Run the UI
/usr/bin/docker run -d --name ui --rm \
  --network bridge-network \
  $UI_DOCKER_IMG 

# Run the app
/usr/bin/docker run --name app --rm --runtime=nvidia --gpus all --privileged \
  --network bridge-network \
  $APP_DOCKER_IMG 