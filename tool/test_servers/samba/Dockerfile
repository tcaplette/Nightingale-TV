# Samba shares and a WS-Discovery responder for SMB tests (see entrypoint.sh).
FROM alpine:3.22
RUN apk add --no-cache samba samba-common-tools wsdd tini
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
EXPOSE 1445 1446 1447 137/udp
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
