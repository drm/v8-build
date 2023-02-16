#!/bin/bash 

set -euo pipefail

VERSION="${1:-}" 
if [ "$VERSION" == "" ] || [ "$(git ls-remote https://github.com/v8/v8 refs/tags/$VERSION)" == "" ]; then
	set +x
	if [ "$VERSION" == "" ]; then
		echo "Missing version."
	else
		echo "Invalid version '$VERSION'"
	fi
	echo "Please find a version tag to build. Here's a few suggestions:"
	echo ""
	git ls-remote --sort='v:refname' --tags  https://github.com/v8/v8 \
		| awk -F "/" '{print $NF}' \
		| sort -Vr \
		| awk -F "." 'int($1) >= 8 && a[$1]++ < 5' \
		| sort -V
	exit 1
fi
shift

RELEASE="${RELEASE:-x64.release.sample}"
IMAGE="${IMAGE:-"v8-build"}"
CONTAINER="${CONTAINER:-v8-build}"
FORCE="${FORCE:-}"
ARTIFACTS="${ARTIFACTS:-"icudtl.dat obj/libv8_monolith.a obj/libv8_libbase.a obj/libv8_libplatform.a"}"

_onexit() {
	docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}

trap _onexit EXIT INT TERM


build--clean() {
	echo "This will remove the base images, which will lengthen the build time significantly."
	read -p "Are you sure? [y/N] " answer
	if [ "$answer" != "${answer#[Yy]}" ]; then
		docker rm -f $CONTAINER 2>&1 | grep -iv 'no such container' || true
		docker image rm -f $IMAGE:base $IMAGE:setup $IMAGE:$VERSION 2>&1 | grep -iv 'no such image' || true
	else
		echo "Canceled."
		exit;
	fi;
}


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
		--sig-proxy=false \
		--entrypoint=/bin/bash \
		$IMAGE:base <<-EOF
			set -exuo pipefail

			export PATH=/opt/depot_tools:$PATH
		
			# https://v8.dev/docs/embed
			cd /root && fetch v8 && cd v8 && gclient sync || true
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
		--sig-proxy=false \
		--entrypoint=/bin/bash \
		$IMAGE:setup <<-EOF
			set -exuo pipefail

			export PATH=/opt/depot_tools:$PATH
		
			cd /root/v8 && git checkout refs/tags/$VERSION 
			cd /root/v8 && tools/dev/v8gen.py $RELEASE
			cd /root/v8 && echo "treat_warnings_as_errors = false" >> out.gn/$RELEASE/args.gn
			cd /root/v8 && ninja -C out.gn/$RELEASE v8_monolith
			
			rm -rf /root/out/$VERSION && mkdir -p /root/out/$VERSION
			
			for f in $ARTIFACTS; do
				cp -v /root/v8/out.gn/$RELEASE/\$f
			done;
			cp -rv /root/v8/include /root/out/$VERSION/include
		EOF
	docker commit $CONTAINER $IMAGE:$VERSION
	docker rm $CONTAINER
	echo ""
	echo "Tagged container as $IMAGE:$VERSION, artifacts are in $root/out/$VERSION:"
	ls -l "$root/out/$VERSION"
	echo ""
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
