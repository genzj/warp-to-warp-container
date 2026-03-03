#!/bin/zsh -ex

source env


# Create the container and join the xxx-warp network
docker run \
    --name "$WARP_CONTAINER_NAME" \
    --rm \
    --detach \
    -v ./mdm.xml:/var/lib/cloudflare-warp/mdm.xml \
    --device /dev/net/tun \
    --cap-add NET_ADMIN \
    warpconnectordocker:latest

# Connect the container to the default network
docker network connect \
    --ip "$WARP_CONTAINER_IP_ADDR" \
    "$WARP_NETWORK_NAME" "$WARP_CONTAINER_NAME"

docker logs -f --since 1m "$WARP_CONTAINER_NAME"

