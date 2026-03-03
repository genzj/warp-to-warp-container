#!/bin/zsh -ex

cd ~/warp-to-warp/

source env

function attach() {
  local filter="$1"
  local network="$2"
  local via="$3"
  for id in $(docker ps -f=label="$filter" --format="{{ .ID }}"); do
    echo "attaching to $network: $(docker inspect -f '{{.Name}}' $id)"
    docker inspect --format '{{json .Containers}}' "$network"  | grep -q "$id"  || \
      docker network connect "$network" "$id"
    pid=$(docker inspect -f '{{.State.Pid}}' "$id")
    sudo mkdir -p /var/run/netns
    sudo ln -sf /proc/$pid/ns/net /var/run/netns/$pid

    for peer in $WARP_PEER_PRIVATE_NETWORKS; do
      sudo ip netns exec $pid ip route del "$peer" || true
      sudo ip netns exec $pid ip route add "$peer" via "$via"
    done
    sudo ip netns exec $pid ip route show
  done
}

() {
  for c in $ATTACHING_CONTAINER_FILTERS; do
    attach "$c" "$WARP_NETWORK_NAME" "$WARP_CONTAINER_IP_ADDR"
  done
}
