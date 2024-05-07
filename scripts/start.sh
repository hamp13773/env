#!/bin/bash

WEBROOT=/app
sed -i "s#/var/www/html#${WEBROOT}#g" /etc/supervisord.conf
cd $WEBROOT

if [ ! -z "$GIT_EMAIL" ]; then
 git config --global user.email "$GIT_EMAIL"
fi
if [ ! -z "$GIT_NAME" ]; then
 git config --global user.name "$GIT_NAME"
 git config --global push.default simple
fi
if [ ! -d "/app/.git" ]; then
 if [ ! -z "$GIT_REPO" ]; then
   rm -Rf /app/*
   if [ ! -z "$GIT_BRANCH" ]; then
     if [ -z "$GIT_USERNAME" ] && [ -z "$GIT_PERSONAL_TOKEN" ]; then
       git clone --recursive -b $GIT_BRANCH $GIT_REPO /app/
     else
       git clone --recursive -b ${GIT_BRANCH} https://${GIT_USERNAME}:${GIT_PERSONAL_TOKEN}@${GIT_REPO} /app
     fi
   else
     if [ -z "$GIT_USERNAME" ] && [ -z "$GIT_PERSONAL_TOKEN" ]; then
       git clone --recursive $GIT_REPO /app/
     else
       git clone --recursive https://${GIT_USERNAME}:${GIT_PERSONAL_TOKEN}@${GIT_REPO} /app
     fi
   fi
 fi
else
 if [ ! -z "$GIT_REPULL" ]; then
   git -C /app rm -r --quiet --cached /app
   git -C /app fetch --all -p
   git -C /app reset HEAD --quiet
   git -C /app checkout "$GIT_BRANCH"
   git -C /app pull
   git -C /app submodule update --init
 fi
fi

if [ -f "$WEBROOT/package.json" ] ; then
  if [ ! -z "$USE_YARN" ]; then
    yarn && echo "Node modules installed via YARN"
  else
    npm install && echo "Node modules installed via NPM"
  fi
fi


if [ ! -z "$HE_ENABLED" ]; then
    echo "auto he-ipv6" > /etc/network/interfaces
    echo "iface he-ipv6 inet6 v4tunnel" >> /etc/network/interfaces
    echo "         endpoint ${HE_ENDPOINT}" >> /etc/network/interfaces
    echo "         ttl 255" >> /etc/network/interfaces
    echo "         address ${HE_CLIENT}" >> /etc/network/interfaces
    echo "         netmask 64" >> /etc/network/interfaces
    echo "         gateway ${HE_SERVER}" >> /etc/network/interfaces
    echo "         up ip -6 route add default dev he-ipv6" >> /etc/network/interfaces
    echo "         up ip -6 route add local ${HE_ROUTED_BLOCK} dev lo" >> /etc/network/interfaces
    echo "         down ip -6 route del default dev he-ipv6" >> /etc/network/interfaces

    /sbin/ifup he-ipv6
    /sbin/ip -6 route add local $HE_ROUTED_BLOCK dev lo
fi

if [[ "$RUN_SCRIPTS" == "1" ]] ; then
  if [ -d "/app/scripts/" ]; then
    chmod -Rf 750 /app/scripts/*
    for i in `ls /app/scripts/`; do /app/scripts/$i ; done
  else
    echo "Can't find script directory"
  fi
fi

if [ ! -z "$NODE_START" ]; then
  echo "Starting using custom NODE_START: ${NODE_START}"
else
  echo "Starting using default NODE_START: /usr/local/bin/node /app/server.js"
  NODE_START="/usr/local/bin/node /app/server.js"
fi

$NODE_START
