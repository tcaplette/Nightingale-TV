#!/bin/bash
# Docker HEALTHCHECK: GET /health on the setup port answers 200 once the
# household has started. Plain bash, so the image needs no curl.
exec 3<>"/dev/tcp/127.0.0.1/${NTV_SETUP_PORT:-8484}" || exit 1
printf 'GET /health HTTP/1.0\r\nHost: localhost\r\n\r\n' >&3
read -r -t 4 _ code _ <&3 || exit 1
[ "$code" = 200 ]
