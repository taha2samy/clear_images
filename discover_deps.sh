#!/bin/sh
set -e

echo "--- Installing tools (including 'tree') ---" >&2
apk add --no-cache build-base wget openssl-dev pcre-dev zlib-dev gawk tree
wget -qO /usr/bin/lddtree https://raw.githubusercontent.com/ncopa/lddtree/master/lddtree.sh && chmod +x /usr/bin/lddtree

NGINX_VERSION=1.25.3
echo "\n--- Building and INSTALLING Nginx v${NGINX_VERSION} ---" >&2
wget -qO nginx.tar.gz "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
tar -xzf nginx.tar.gz
cd nginx-${NGINX_VERSION}

./configure --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf
make -j "$(nproc)"
make install

echo "\n--- DISCOVERY RESULTS ---" >&2

echo "\n\n==========================================================="
echo "### SECTION 1: NGINX INSTALLED FILES (LIST) ###"
echo "==========================================================="
find /etc/nginx /usr/sbin/nginx /usr/local/nginx/html -type f 2>/dev/null


echo "\n\n==========================================================="
echo "### SECTION 2: NGINX INSTALLED FILES (FOCUSED TREE VIEW) ###"
echo "==========================================================="
tree /etc/nginx /usr/sbin /usr/local/nginx/html


echo "\n\n==========================================================="
echo "### SECTION 3: REQUIRED SHARED LIBRARIES ###"
echo "==========================================================="
( \
    lddtree -l /usr/sbin/nginx; \
    ldd -r /usr/sbin/nginx | gawk 'NF==4{print $3}'; \
) | grep '^/' | sort -u


echo "\n\n==========================================================="
echo "### SECTION 4: FULL SYSTEM TREE ###"
echo "==========================================================="
tree /