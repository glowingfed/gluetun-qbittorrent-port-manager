#!/bin/bash

COOKIES="/tmp/cookies.txt"

check_qbt_port () {
  RESPONSE_PORT=$(curl -s -b $COOKIES ${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/app/preferences | sed -n 's/.*"listen_port":\([0-9]*\).*/\1/p')
}

update_port () {
  PORT=$(cat $PORT_FORWARDED)
  TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
  rm -f $COOKIES
  curl -s -c $COOKIES --data "username=$QBITTORRENT_USER&password=$QBITTORRENT_PASS" ${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/auth/login > /dev/null
  check_qbt_port

  if [[ "$RESPONSE_PORT" == "$PORT" ]]
  then
   echo "$TIMESTAMP qbitorrent port is up to date. gluetun: $PORT, qbittorrent: $RESPONSE_PORT"
  else
   echo "$TIMESTAMP Current qbittorrent port is $RESPONSE_PORT. Updating qbittorrent to port $PORT"
   curl -s -b $COOKIES --data 'json={"listen_port": "'"$PORT"'"}' ${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/app/setPreferences > /dev/null
   check_qbt_port
   if [[ "$RESPONSE_PORT" == "$PORT" ]]
   then
    echo "$TIMESTAMP Updated qbittorrent to port $PORT. Current qbittorrent port is $RESPONSE_PORT"
   else
    echo "$TIMESTAMP Failed to update qbittorrent to port $PORT. Current qbittorrent port is $RESPONSE_PORT"
   fi
  fi

  rm -f $COOKIES

}

while true; do
  if [ -f $PORT_FORWARDED ]; then
    update_port
    inotifywait -mq -t ${PORT_UPDATE_TIMEOUT:-0} -e close_write $PORT_FORWARDED | while read change; do
      update_port
    done
  else
    echo "Couldn't find file $PORT_FORWARDED"
    echo "Trying again in 10 seconds"
    sleep 10
  fi
done
