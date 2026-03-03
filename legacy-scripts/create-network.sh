#!/bin/bash

docker network create \
	--driver bridge \
	--attachable \
	--internal \
	--subnet=192.168.71.0/24 \
	vm7-warp
