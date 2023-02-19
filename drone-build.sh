#!/bin/bash 

set -exuo pipefail

RELEASE="x64.release.sample"
VERSION="$1"

export PATH=/opt/depot_tools:$PATH

# https://v8.dev/docs/embed
cd /root && fetch v8 && cd v8 && gclient sync || true

cd /root/v8 && git checkout refs/tags/$VERSION 
cd /root/v8 && tools/dev/v8gen.py $RELEASE
cd /root/v8 && echo "treat_warnings_as_errors = false" >> out.gn/$RELEASE/args.gn
cd /root/v8 && ninja -C out.gn/$RELEASE v8_monolith
