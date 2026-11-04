# Build-only Noble environment. No browser/runtime sandbox is disabled.
# This digest is the official Ubuntu24.04 image inspected for this SDK profile.
FROM ubuntu@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55
ENV DEBIAN_FRONTEND=noninteractive
ARG RAFT_HTML_SDK_BUILD_ID=unlabelled
ARG RAFT_HTML_SDK_ENFORCE_LIMITS=0
LABEL org.raft.html-sdk.build=$RAFT_HTML_SDK_BUILD_ID
SHELL ["/usr/bin/nice", "-n", "15", "/bin/sh", "-c"]
COPY build_resources.sh /opt/raft-html-sdk-recipe/build_resources.sh
RUN /bin/sh /opt/raft-html-sdk-recipe/build_resources.sh \
 && mkdir -p /opt/raft-html-sdk-debs/partial \
 && apt-get update \
 && apt-get -y -o Dir::Cache::archives=/opt/raft-html-sdk-debs upgrade --no-install-recommends \
 && apt-get -y -o Dir::Cache::archives=/opt/raft-html-sdk-debs install --no-install-recommends \
    ca-certificates gpgv python3 cmake ninja-build pkg-config build-essential clang-18 lld-18 patchelf \
    libgcc-13-dev=13.3.0-6ubuntu2~24.04.1 gperf bison flex ruby unifdef python3-jinja2 \
    libglib2.0-dev libharfbuzz-dev libicu-dev libepoxy-dev libgcrypt20-dev libsoup-3.0-dev \
    libtasn1-6-dev libxkbcommon-dev libxml2-dev libxslt1-dev libpng-dev libsqlite3-dev \
    libwebp-dev libfontconfig-dev libfreetype-dev libwoff-dev libenchant-2-dev libhyphen-dev \
    libjxl-dev libavif-dev liblcms2-dev flite1-dev libseccomp-dev bubblewrap xdg-dbus-proxy \
    libatk-bridge2.0-dev libsecret-1-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    wayland-protocols libwayland-dev libsystemd-dev libegl1-mesa-dev libgles2-mesa-dev \
    libgbm-dev libdrm-dev nlohmann-json3-dev=3.11.3-1 \
 && apt-get -y -o Dir::Cache::archives=/opt/raft-html-sdk-debs --download-only --reinstall install $(dpkg-query -W -f='${binary:Package}=${Version} ') \
 && dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' > /opt/raft-html-sdk-packages.tsv \
 && sha256sum /opt/raft-html-sdk-debs/*.deb > /opt/raft-html-sdk-archives.sha256
# Fixed compatible libwpe archives are fetched and hash-checked, never installed over Ubuntu.
COPY fetch_libwpe.py libwpe-pins.json /opt/raft-html-sdk-recipe/
RUN python3 /opt/raft-html-sdk-recipe/fetch_libwpe.py /opt/raft-html-sdk-debs
# Preserve signed APT lists, downloaded packages and notices as provenance inputs.
# The unprivileged worker selects only fixed engine/resource targets.
