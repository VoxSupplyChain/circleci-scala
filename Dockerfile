FROM docker:19.03.5-git

# The CircleCi builds will run in the Docker image built from this Dockerfile. To build a new image:
# 0. authenticate and assume role in shared account
# 1. docker build -t 931175591414.dkr.ecr.eu-west-1.amazonaws.com/circleci-scala:<VERSION> \
#    --build-arg NEXUS_READER_PASSWORD=<reader_password> .
# 2. eval "$(aws ecr get-login --region eu-west-1 --no-include-email)"
# 3. docker push 931175591414.dkr.ecr.eu-west-1.amazonaws.com/circleci-scala:<VERSION>
# 4. Update the image setting in config.yml to your new VERSION.

# You must set the Tundra Nexus reader password to be able to download the required java installation binaries
ARG NEXUS_READER_PASSWORD
RUN if [ -z "$NEXUS_READER_PASSWORD" ]; then echo "ERROR: You must set NEXUS_READER_PASSWORD as a Docker build arg."; exit 1; fi

ENV SHELL /bin/bash
ENV SBT_VERSION 1.2.8
ENV LANG=C.UTF-8

# Install AWS CLI
RUN apk upgrade --update && apk update --update && apk add --update --no-cache curl tar python3
# symlink python3 to python because check-ecs-service-deployment uses it as the interpreter
RUN ln -sf /usr/bin/python3 /usr/bin/python
RUN pip3 install --no-cache awscli
RUN apk add --update --no-cache nodejs nodejs-npm

# To handle 'not get uid/gid' on alpine linux
RUN npm config set unsafe-perm true
RUN npm install -g typescript node-sass

# Java Version and other ENV
ENV JAVA_VERSION_MAJOR=8 \
    JAVA_VERSION_MINOR=181 \
    JAVA_VERSION_BUILD=13 \
    JAVA_PACKAGE=jdk \
    JAVA_HOME=/opt/jdk \
    GLIBC_VERSION=2.23-r3

ENV PATH=/opt/jdk/bin:${PATH}

# do it in several step
RUN set -ex && \
    apk add --update libstdc++ curl ca-certificates && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION} glibc-i18n-${GLIBC_VERSION}; do curl -sSL https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    ( /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 C.UTF-8 || true ) && \
    echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib && \
    echo "Copying and Installing JAVA"

# download from Tundra Nexus (version before the Oracle licence change April, 2019)
RUN curl -SfL# -u reader:${NEXUS_READER_PASSWORD} -o /tmp/java.tar.gz \
    https://nexus.tundra-shared.com/repository/raw-private/install/jdk/jdk-8u181-linux-x64.tar.gz

RUN gunzip /tmp/java.tar.gz && \
    tar -C /opt -xf /tmp/java.tar && \
    ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/jdk && \
    ln -s /opt/jdk/bin/java /bin/java && \
    sed -i s/#networkaddress.cache.ttl=-1/networkaddress.cache.ttl=10/ $JAVA_HOME/jre/lib/security/java.security && \
    apk del glibc-i18n && \
    rm -rf /opt/jdk/*src.zip \
           /opt/jdk/lib/missioncontrol \
           /opt/jdk/lib/visualvm \
           /opt/jdk/lib/*javafx* \
           /opt/jdk/jre/plugin \
           /opt/jdk/jre/bin/javaws \
           /opt/jdk/jre/bin/jjs \
           /opt/jdk/jre/bin/orbd \
           /opt/jdk/jre/bin/pack200 \
           /opt/jdk/jre/bin/policytool \
           /opt/jdk/jre/bin/rmid \
           /opt/jdk/jre/bin/rmiregistry \
           /opt/jdk/jre/bin/servertool \
           /opt/jdk/jre/bin/tnameserv \
           /opt/jdk/jre/bin/unpack200 \
           /opt/jdk/jre/lib/javaws.jar \
           /opt/jdk/jre/lib/deploy* \
           /opt/jdk/jre/lib/desktop \
           /opt/jdk/jre/lib/*javafx* \
           /opt/jdk/jre/lib/*jfx* \
           /opt/jdk/jre/lib/amd64/libdecora_sse.so \
           /opt/jdk/jre/lib/amd64/libprism_*.so \
           /opt/jdk/jre/lib/amd64/libfxplugins.so \
           /opt/jdk/jre/lib/amd64/libglass.so \
           /opt/jdk/jre/lib/amd64/libgstreamer-lite.so \
           /opt/jdk/jre/lib/amd64/libjavafx*.so \
           /opt/jdk/jre/lib/amd64/libjfx*.so \
           /opt/jdk/jre/lib/ext/jfxrt.jar \
           /opt/jdk/jre/lib/oblique-fonts \
           /opt/jdk/jre/lib/plugin.jar \
           /tmp/* /var/cache/apk/* && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

RUN apk add --update --no-cache bash unzip sudo

# Install SBT
RUN curl -SsfL -o- "https://piccolo.link/sbt-$SBT_VERSION.tgz" \
    |  tar xzf - -C /usr/local --strip-components=1 && \
    sbt exit
