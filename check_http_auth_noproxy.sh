#!/bin/bash

# Checks internal webpages bypassing the local proxy
# USAGE: check_http_auth_noproxy.sh URL USERNAME PASSWORD EXPECTED_HTTP_CODE TIMEOUT
# URL: URL to the site
# USERNAME: Authentication User for web site
# PASSWORD: Password to the Auth User
# EXPECTED_HTTP_CODE: HTTP Response code to expect. Default: 200
# TIMEOUT: Timeout. Default: 10
# Created by: pashol 2015/09/22

URL=$1
USER=$2
PASSWORD=$3
RESPONSE_CODE=${4:-200}
TIMEOUT=${5:-10}

case $RESPONSE_CODE in
401)
  EXPECTED_RETURN_CODE=6
  ;;
200)
  EXPECTED_RETURN_CODE=0
  ;;
*)
  EXPECTED_RETURN_CODE=0
  ;;
esac

start=`date +%s`
wget -t 1 --timeout ${TIMEOUT} -O /dev/null -o /dev/null --user=${USER} --password=${PASSWORD} --no-proxy ${URL}
WGET_RETURN_CODE=$?
end=`date +%s`

PERFDATA="time=$(expr ${end} - ${start})s"

if [ ${WGET_RETURN_CODE} -eq ${EXPECTED_RETURN_CODE} ] ; then
  echo "HTTP OK: HTTP/1.1 ${RESPONSE_CODE} OK for ${URL}|${PERFDATA}"
  exit 0
else
  echo "HTTP CRITICAL: Did not receive HTTP/1.1 ${RESPONSE_CODE} for ${URL}|${PERFDATA}"
  exit 2
fi
