#!/bin/bash
mkdir -p ~/.jupyter-tls
chmod 700 ~/.jupyter-tls
cd ~/.jupyter-tls
(
    umask 077
    openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
        -keyout key.pem -out cert.pem \
        -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
        -addext "extendedKeyUsage=serverAuth"
    openssl rand -hex 24 > token
)
