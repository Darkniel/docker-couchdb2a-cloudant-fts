# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

FROM debian:jessie

MAINTAINER Daniel Pinzon daniel.visualfx@gmail.com

RUN groupadd -r couchdb && useradd -d /usr/src/couchdb -g couchdb couchdb

# Get necesary dependencies
RUN apt-get update -y -qq && apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    erlang-dev \
    erlang-nox \
    git \
    haproxy \
    libcurl4-openssl-dev \
    libicu-dev \
    libmozjs185-dev \
    openssl \
    python \
    wget \
 && curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
 && echo 'deb https://deb.nodesource.com/node_4.x jessie main' > /etc/apt/sources.list.d/nodesource.list \
 && echo 'deb-src https://deb.nodesource.com/node_4.x jessie main' >> /etc/apt/sources.list.d/nodesource.list \
 && apt-get update -y -qq && apt-get install -y nodejs \
 && npm install -g grunt-cli 

 # Install Java 6
RUN curl -s -k -L -C - -o /opt/jdk-6u45-linux-x64.bin -b "oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/6u45-b06/jdk-6u45-linux-x64.bin \
&& chmod +x /opt/jdk-6u45-linux-x64.bin \
&& cd /opt \
&& ./jdk-6u45-linux-x64.bin >/dev/null <<echo q >/dev/null <<echo y \
&& rm /opt/jdk-6u45-linux-x64.bin \
&& mv /opt/jdk1.6.0_45/jre /opt/jre1.6.0_45 \
&& mv /opt/jdk1.6.0_45/lib/tools.jar /opt/jre1.6.0_45/lib/ext \
&& rm -Rf /opt/jdk1.6.0_45 \
&& ln -s /opt/jre1.6.0_45 /opt/java

# Set JAVA_HOME
ENV JAVA_HOME /opt/java

# INSTALL MAVEN 3.2.5
RUN wget http://apache.arvixe.com/maven/maven-3/3.2.5/binaries/apache-maven-3.2.5-bin.tar.gz \
    && tar -zxf apache-maven-3.2.5-bin.tar.gz \
    && cp -R apache-maven-3.2.5 /usr/local \
    && ln -s /usr/local/apache-maven-3.2.5/bin/mvn /usr/bin/mvn

# Clone CouchDB 2 Alpha
RUN cd /usr/src && git clone --depth 1 https://git-wip-us.apache.org/repos/asf/couchdb.git \
    && cd couchdb && git checkout master

# Modify files to integrate Dreyfus (cloudant full text search) to CouchDB
# https://cloudant.com/blog/enable-full-text-search-in-apache-couchdb/#.VqjAah9zg8r

RUN cd /usr/src/couchdb \
    && sed -e '/"fauxton_root": "src\/fauxton\/dist\/release",/a\\t\t\t"clouseau_name": "clouseau%d@127.0.0.1" % (idx+1),' -i dev/run \
    && sed -e 's@{meck,             "meck",             {tag, "0.8.2"}}@&,\n{dreyfus,           {url, "https://github.com/cloudant-labs/dreyfus"}, "5f113370a1273dd1bdc981ca3ea98767bca0382d"}@' -i rebar.config.script \
    && sed -e 's@setup_epi@&,\n\tdreyfus_epi@' -i rel/apps/couch_epi.config \
    && sed -e "\$a\\\n\[dreyfus\]\nname = {{clouseau_name}}" -i rel/overlay/etc/local.ini \
    && sed -e '60,70 s@snappy@&,\n\t\tdreyfus@' -e 's@{app, snappy, \[{incl_cond, include}\]}@&,\n\t{app, dreyfus, [{incl_cond, include}]}@' -i rel/reltool.config \
    && sed -e '/sandbox.isArray = isArray;/a\\t\tsandbox.index = Dreyfus.index;' -e 's@"rereduce" : Views.rereduce@&,\n\t\t"index_doc": Dreyfus.indexDoc@' -i share/server/loop.js \
    && sed -e '22,32 s@"share/server/validate.js",@&\n\t\t\t\t\t\t\t "share/server/dreyfus.js",@' -e '33,44 s@"share/server/validate.js",@&\n\t\t\t\t\t\t\t\t\t "share/server/dreyfus.js",@' -i support/build_js.escript \
    && curl https://raw.githubusercontent.com/cloudant/couchdb/c323f194328822385aa1bb2ab15b927cc604c4b7/share/server/dreyfus.js > share/server/dreyfus.js

# Build CouchDb
RUN cd /usr/src/couchdb && ./configure --disable-docs && make

# Clone Clouseau
RUN cd /usr/src \
    && git clone https://github.com/cloudant-labs/clouseau \
    && chmod +x /usr/src/clouseau && chown -R couchdb:couchdb /usr/src/clouseau


# Remove packages used only for build CouchDB
RUN apt-get purge -y \
    binutils \
    build-essential \
    cpp \
    erlang-dev \
    git \
    libicu-dev \
    make \
    nodejs \
    perl \
 && apt-get autoremove -y && apt-get clean \
 && apt-get install -y libicu52 --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* /usr/lib/node_modules src/fauxton/node_modules src/**/.git .git

# permissions
RUN chmod +x /usr/src/couchdb/dev/run && chown -R couchdb:couchdb /usr/src/couchdb

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown -R couchdb:couchdb /entrypoint.sh

USER couchdb
VOLUME ["/usr/src/couchdb/dev/lib", "/usr/src/clouseau/target"]
EXPOSE 5984 15984 25984 35984 15986 25986 35986
WORKDIR /usr/src/couchdb

# ENTRYPOINT ["/usr/src/couchdb/dev/run"]
# CMD ["--with-haproxy"]
