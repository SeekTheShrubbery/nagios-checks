#!/bin/bash

# Checks internal webpages bypassing the local proxy and using NTLM Authentication to check for any response codes
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
#SSL=${6:-S}

start=`date +%s`
EXPECTED_RETURN_CODE=$(curl -s -o /dev/null -w '%{http_code}' ${URL} --proxy '' --connect-timeout ${TIMEOUT} -u ${USER}:${PASSWORD} -L --ntlm --head --insecure)
end=`date +%s`

PERFDATA="time=$(expr ${end} - ${start})s"

if  [[ ${RESPONSE_CODE} ==  ${EXPECTED_RETURN_CODE} ]] ; then
  echo "HTTP OK: HTTP/1.1 ${RESPONSE_CODE} OK for ${URL}|${PERFDATA}"
  exit 0
else
  echo "HTTP CRITICAL: Did not receive HTTP/1.1 ${RESPONSE_CODE} for ${URL} (Response: ${EXPECTED_RETURN_CODE})|${PERFDATA}"
  exit 2
fi
