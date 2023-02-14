FROM debian:bullseye


RUN apt-get update \
     && apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		curl \
		python3 \
		pkg-config \
		procps \
		git \
     && rm -rf /var/lib/apt/lists/*

# https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up
RUN cd /opt \
	&& rm -rf /opt/depot_tools \
	&& git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git 

ENV PATH=/opt/depot_tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WORKDIR /root
RUN update_depot_tools
RUN fetch v8
