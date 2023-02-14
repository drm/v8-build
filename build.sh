#!/bin/bash 

set -euxo pipefail

VERSION="$1" 
shift

IMAGE="${IMAGE:-"v8-build"}"
CONTAINER="${CONTAINER:-v8-build}"
FORCE="${FORCE:-}"

build--base() {
	if ! docker image inspect $IMAGE:base > /dev/null 2>&1 || [ "$FORCE" != "" ]; then
		docker build -t "$IMAGE:base" .
	fi
}


build--setup() {
	docker rm -f $CONTAINER || true
	docker run \
		-i \
		--name=$CONTAINER \
		--entrypoint=/bin/bash \
		$IMAGE:base <<-EOF
			set -exuo pipefail

			export PATH=/opt/depot_tools:$PATH
		
			# https://v8.dev/docs/embed
			cd /root && fetch v8 && cd v8 && gclient sync 
			cd /root/v8 && tools/dev/v8gen.py x64.release.sample
			cd /root/v8 && git checkout refs/tags/$VERSION 
		EOF
	docker commit $CONTAINER $IMAGE:setup
	docker rm $CONTAINER
}

build--build() {
	local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	mkdir -p "$root/out"

	docker image rm -f $CONTAINER || true
	docker run \
		-i \
		-v "$root/out:/root/out" \
		--name=$CONTAINER \
		--entrypoint=/bin/bash \
		$IMAGE:setup <<-EOF
			set -exuo pipefail

			export PATH=/opt/depot_tools:$PATH
		
			cd /root/v8 && ninja -C out.gn/x64.release.sample v8_monolith
			
			cp -v /root/v8/out.gn/x64.release.sample/icudtl.dat /root/out
			cp -v /root/v8/out.gn/x64.release.sample/obj/libv8_monolith.a /root/out/libv8_monolith.$VERSION.a
		EOF
	docker commit $CONTAINER $IMAGE:build
	docker rm $CONTAINER
}

if [ $# -gt 0 ]; then
	for a in $@; do
		build--$a;
	done
else
	build--base
	build--setup
	build--build
fi
