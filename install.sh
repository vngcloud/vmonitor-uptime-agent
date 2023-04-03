#!/bin/bash

BASE_URL="https://github.com/vngcloud/vmonitor-uptime-agent/releases/download"
if [ ! $API_KEY ]; then
  printf "\033[31mAPI key not available in API_KEY environment variable.\033[0m\n"
  exit 1;
fi

if [ ! $LOCATION_ID ]; then
  printf "\033[31mLocation ID not available in LOCATION_ID environment variable.\033[0m\n"
  exit 1;
fi

if [ ! $VMONITOR_SITE ]; then
  printf "\033[31mSITE not available in VMONITOR_SITE environment variable.\033[0m\n"
  printf "\033[31mDefault site is monitoring-agent.vngcloud.vn\033[0m\n"
  VMONITOR_SITE=monitoring-agent.vngcloud.vn
fi

KNOWN_DISTRIBUTION="(Debian|Ubuntu|RedHat|CentOS|openSUSE|Amazon|Arista|SUSE)"
DISTRIBUTION=$(lsb_release -d 2>/dev/null | grep -Eo $KNOWN_DISTRIBUTION  || grep -Eo $KNOWN_DISTRIBUTION /etc/issue 2>/dev/null || grep -Eo $KNOWN_DISTRIBUTION /etc/Eos-release 2>/dev/null || grep -m1 -Eo $KNOWN_DISTRIBUTION /etc/os-release 2>/dev/null || uname -s)

if [ $DISTRIBUTION = "Darwin" ]; then
  printf "\033[31mThis script does not support installing on the Mac."
  exit 1;
elif [ -f /etc/debian_version -o "$DISTRIBUTION" == "Debian" -o "$DISTRIBUTION" == "Ubuntu" ]; then
    OS="Debian"
elif [ -f /etc/redhat-release -o "$DISTRIBUTION" == "RedHat" -o "$DISTRIBUTION" == "CentOS" -o "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
# Some newer distros like Amazon may not have a redhat-release file
elif [ -f /etc/system-release -o "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
# Arista is based off of Fedora14/18 but do not have /etc/redhat-release
elif [ -f /etc/Eos-release -o "$DISTRIBUTION" == "Arista" ]; then
    OS="RedHat"
# openSUSE and SUSE use /etc/SuSE-release
elif [ -f /etc/SuSE-release -o "$DISTRIBUTION" == "SUSE" -o "$DISTRIBUTION" == "openSUSE" ]; then
    OS="SUSE"
fi

# Root user detection
if [[ $(echo "$UID") -ne 0 ]]; then
    sudo_cmd=''
    printf "\n\033[31mRun cmd as root.\033[0m\n"
    exit 1;
fi


# Install the necessary package sources
if [ $OS = "RedHat" ]; then
    echo -e "\033[34m\n* Installing RPM sources for vMonitor\n\033[0m"

    UNAME_M=$(uname -m)
    if [ "$UNAME_M"  == "i686" -o "$UNAME_M"  == "i386" -o "$UNAME_M"  == "x86" ]; then
        ARCHI="i386"
    else
        ARCHI="x86_64"
    fi

    printf "\033[34m* Installing the vMonitor Uptime Agent package\n\033[0m\n"

    PACKAGE_NAME="vmonitor-uptime-agent-nightly.${ARCHI}.rpm"
    URI="$BASE_URL/${VERSION}/${PACKAGE_NAME}"
    echo $URI
    curl -L $URI -o /tmp/$PACKAGE_NAME

    $sudo_cmd rpm -i /tmp/$PACKAGE_NAME --force

elif [ $OS = "Debian" ]; then
    printf "\033[34m\n* Installing the vMonitor Uptime Agent package\n\033[0m\n"
    ARCHI=$(dpkg --print-architecture)
  
    PACKAGE_NAME="vmonitor-uptime-agent_nightly_${ARCHI}.deb"
    URI="$BASE_URL/${VERSION}/${PACKAGE_NAME}"
    echo $URI
    curl -L $URI -o /tmp/$PACKAGE_NAME
    $sudo_cmd dpkg -i /tmp/$PACKAGE_NAME

else
    printf "\033[31mYour OS or distribution are not supported by this install script.
Please follow the instructions on the Agent setup page:
    https://app.vngcloud.vn/account/settings#agent\033[0m\n"
    exit;
fi

# Set the configuration
printf "\033[34m\n* Adding your Agent configuration: /etc/vmonitor-uptime-agent/vmonitor-uptime-agent.yaml\n\033[0m\n"


$sudo_cmd cat > /etc/vmonitor-uptime-agent/vmonitor-uptime-agent.yaml<< EOF
uptime:
  host: $VMONITOR_SITE
  websocketPath: /vmonitor-uptime-manager/wss/uptime-test
  queuePrefix: /wss/queue/uptime-test/
  responseDest: /wss/app/uptime-test
  pingPongDest: /wss/app/ping-pong

agent:
  apiKey: $API_KEY

location:
  id: $LOCATION_ID
  
http:
  headerNameMaxLength: 1500
  headerValueMaxLength: 2000
  paramNameMaxLength: 1500
  paramValueMaxLength: 1500
  bodyMaxLength: 10000
  
ipTable:
  block:
    enabled: false
    cidr:
      - 127.0.0.1
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
      - 224.0.0.0/4
  allow:
    enabled: false
    cidr:
      - 127.0.0.1
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
      - 224.0.0.0/4
EOF
# restart agent
printf "\033[34m* Starting the Agent...\n\033[0m\n"
$sudo_cmd service vmonitor-uptime-agent enable
$sudo_cmd service vmonitor-uptime-agent restart

# Wait for metrics
printf "\033[32m
Your Agent has started up for the first time.
at:
    https://vmonitor.vngcloud.vn/infrastructure\033[0m
Waiting for uptime check..."

#vmonitor-uptime-agent --once

printf "\033[32m
Your Agent is running and functioning properly. It will continue to run in the
background and submit metrics to vMonitor.
If you ever want to stop the Agent, run:
    sudo service vmonitor-uptime-agent stop
And to run it again run:
    sudo service vmonitor-uptime-agent start
\033[0m"
