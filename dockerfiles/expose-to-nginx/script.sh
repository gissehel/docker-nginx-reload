export DEBIAN_FRONTEND=noninteractive

NGINX_DIR="/etc/nginx"
CONTROL_DIR="${NGINX_DIR}/control"
FIFO_FILE="${CONTROL_DIR}/nginx-fifo"
LOG_DIR="/var/log/nginx"
START_SCRIPT="/usr/local/bin/nginx-expose"
CONF_DIR="${NGINX_DIR}/conf.d"
TEMPLATE_CONF_MAIN="/opt/template-conf-main"
TEMPLATE_CONF_UPSTREAM="/opt/template-conf-upstream"
NEWUSER_SCRIPT="/newuser"

cat <<__END__ >"${TEMPLATE_CONF_MAIN}"
server {
  listen 80;
  listen 443;
  server_name {{names}};
  access_log /var/log/nginx/access-{{name}}.log combined;
  location {{httppath}} {
    proxy_pass http://{{name}};
    proxy_pass_header Server;
    proxy_redirect off;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Scheme \$scheme;
    proxy_set_header REMOTE_ADDR \$remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    auth_basic "Access ?"; auth_basic_user_file {{authfile}};
  }
}
__END__

cat <<__END__ >"${TEMPLATE_CONF_UPSTREAM}"
upstream {{name}} {
  server {{host}}:{{port}};
}
__END__

cat <<__END__ >"${START_SCRIPT}"
#!/usr/bin/env bash
LOG_NAME="${LOG_DIR}/nexpose-\$NAME.log"
CONF_NAME="${CONF_DIR}/\$NAME.conf"
UP_NAME="${CONF_DIR}/\$NAME-upstream.conf"

function xlog {
  echo "\$(date +'%Y-%m-%d %H:%M:%S') \$1" >> "\$LOG_NAME"
}

xlog "started"
# xlog "\$(set)"
PORT_VAR="SLOT_PORT_\${PORT}_TCP_PORT"
HOST_VAR="SLOT_PORT_\${PORT}_TCP_ADDR"
PORT_REDIR="\${!PORT_VAR}"
HOST_REDIR="\${!HOST_VAR}"
xlog "PORT_VAR=\$PORT_VAR"
xlog "HOST_VAR=\$HOST_VAR"
xlog "PORT_REDIR=\$PORT_REDIR"
xlog "HOST_REDIR=\$HOST_REDIR"

if [ -z "\$AUTHFILE" ] ; then
    SEDARG="s/^.*{{authfile}}.*$//;"
else
    SEDARG="s/{{authfile}}/\$AUTHFILE/;"
fi

if [ -z "\$HTTPPATH" ] ; then
    HTTPPATH="/"
fi

if [ -z "\$NOOVERWRITE" -o ! -f "\$CONF_NAME" ] ; then
cat "${TEMPLATE_CONF_MAIN}" | sed "s/{{names}}/\$NAMES/; s/{{name}}/\$NAME/; s/{{port}}/\$PORT_REDIR/; s/{{host}}/\$HOST_REDIR/; s@{{httppath}}@\$HTTPPATH@; \$SEDARG" > "\$CONF_NAME"
fi
cat "${TEMPLATE_CONF_UPSTREAM}"   | sed "s/{{names}}/\$NAMES/; s/{{name}}/\$NAME/; s/{{port}}/\$PORT_REDIR/; s/{{host}}/\$HOST_REDIR/; s@{{httppath}}@\$HTTPPATH@; \$SEDARG" > "\$UP_NAME"
xlog "ended"

echo "\$NAME" > "${FIFO_FILE}"
__END__

cat <<__END__ > "${NEWUSER_SCRIPT}"
#!/usr/bin/env bash
if [ -z "${NGINX_DIR}/\$AUTHFILE" ] ; then
    echo "You must define an environement AUTHFILE" >/dev/stderr
else
    echo -n "User? "
    read USER
    touch "${NGINX_DIR}/\$AUTHFILE"
    htpasswd -m "${NGINX_DIR}/\$AUTHFILE" "\$USER"
fi
read
__END__
chmod +x "${NEWUSER_SCRIPT}"


apt-key adv --keyserver pgp.mit.edu --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62
apt-get update -qq
apt-get install -qqy apache2-utils

echo ""
