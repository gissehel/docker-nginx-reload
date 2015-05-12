export DEBIAN_FRONTEND=noninteractive

CONTROL_DIR="/etc/nginx/control"
FIFO_FILE="$CONTROL_DIR/nginx-fifo"
START_FILE="/usr/local/bin/start-nginx"
WATCH_SCRIPT="/usr/local/bin/watch-fifo"
FIFO_LOG="/var/log/nginx/nginx-fifo-script.log"

cat <<__END__ >"${START_FILE}"
#!/usr/bin/env bash
rm -rf "${FIFO_FILE}"
sleep 2
mkfifo "${FIFO_FILE}"
nice /bin/bash "${WATCH_SCRIPT}" &
nginx -g "daemon off;"
__END__

chmod +x "${START_FILE}"

cat <<__END__ > "${WATCH_SCRIPT}"
#!/usr/bin/env bash
while [ true ] ; do
    cat "${FIFO_FILE}" | while read command; do
        kill -HUP \$(cat /run/nginx.pid)
        echo "\$(date '+%Y-%m-%d %H:%M:%S') reload ( \$command )" >> "${FIFO_LOG}"
    done;
    sleep 5
done;
__END__

chmod +x "${WATCH_SCRIPT}"

rm -f /tmp/script.sh

