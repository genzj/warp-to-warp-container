# Local build helpers for the WARP connector and Docker events handler images.
# Requires docker with buildx.
#
# `make build` builds for the host architecture only and loads the result into the
# local image store. That is the fast path for day-to-day development.
#
# `make build-cross` builds every platform we publish, which needs QEMU emulation
# for the foreign architecture and so is considerably slower. Use it to verify a
# change builds everywhere before tagging a release. Run `make binfmt builder`
# once before the first foreign-architecture build.

WARP_IMAGE      ?= warpconnectordocker:latest
DEHANDLER_IMAGE ?= dehandler:latest
PLATFORMS       ?= linux/amd64,linux/arm64
BUILDER         ?= w2w-builder

WARP_CONTEXT      := .
DEHANDLER_CONTEXT := ./docker-events

BUILD := docker buildx build

.PHONY: build build-warp build-dehandler build-amd64 build-arm64 build-cross \
        binfmt builder clean help

help:
	@echo "build           build both images for the host architecture (--load)"
	@echo "build-warp      build only the WARP connector for the host architecture"
	@echo "build-dehandler build only the events handler for the host architecture"
	@echo "build-amd64     build both images for linux/amd64 (--load)"
	@echo "build-arm64     build both images for linux/arm64 (--load)"
	@echo "build-cross     build both images for $(PLATFORMS) (cache only)"
	@echo "binfmt          install QEMU emulators, needed once for foreign-arch builds"
	@echo "builder         create the '$(BUILDER)' buildx builder used by build-cross"
	@echo "clean           remove the locally built images and the buildx builder"

# --- host architecture: no --platform, so buildx picks the native one ---

build: build-warp build-dehandler

build-warp:
	$(BUILD) --load -t $(WARP_IMAGE) $(WARP_CONTEXT)

build-dehandler:
	$(BUILD) --load -t $(DEHANDLER_IMAGE) $(DEHANDLER_CONTEXT)

# --- a single foreign architecture: emulated, but still loadable ---

build-amd64:
	$(BUILD) --platform linux/amd64 --load -t $(WARP_IMAGE) $(WARP_CONTEXT)
	$(BUILD) --platform linux/amd64 --load -t $(DEHANDLER_IMAGE) $(DEHANDLER_CONTEXT)

build-arm64:
	$(BUILD) --platform linux/arm64 --load -t $(WARP_IMAGE) $(WARP_CONTEXT)
	$(BUILD) --platform linux/arm64 --load -t $(DEHANDLER_IMAGE) $(DEHANDLER_CONTEXT)

# --- every published platform at once ---
# A multi-platform result cannot be loaded into the docker image store, so this
# only warms the build cache.

build-cross:
	$(BUILD) --builder $(BUILDER) --platform $(PLATFORMS) --output type=cacheonly \
		-t $(WARP_IMAGE) $(WARP_CONTEXT)
	$(BUILD) --builder $(BUILDER) --platform $(PLATFORMS) --output type=cacheonly \
		-t $(DEHANDLER_IMAGE) $(DEHANDLER_CONTEXT)

# --- one-off setup ---

binfmt:
	docker run --privileged --rm tonistiigi/binfmt --install amd64,arm64

builder:
	docker buildx inspect $(BUILDER) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDER) --driver docker-container

clean:
	-docker image rm $(WARP_IMAGE) $(DEHANDLER_IMAGE)
	-docker buildx rm $(BUILDER)
