#!/usr/bin/env python3
"""Put TLS in front of an app that only speaks plain HTTP.

Listens with TLS on ADDRESS:PORT and forwards the decrypted stream to an app
on the node's loopback:

    python3 tls_proxy.py --listen 10.0.0.5:8443 --backend 127.0.0.1:8888 \\
        --cert cert.pem --key key.pem

Only the standard library, and nothing newer than Python 3.6.
"""
import argparse
import socket
import ssl
import sys
import threading


def pipe(src, dst):
    """Copy src to dst until src is done, then tell dst no more is coming."""
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client, backend):
    try:
        server = socket.create_connection(backend, timeout=10)
    except OSError as e:
        print("cannot reach the app: {}".format(e), file=sys.stderr)
        client.close()
        return
    server.settimeout(None)
    upstream = threading.Thread(target=pipe, args=(client, server), daemon=True)
    upstream.start()
    pipe(server, client)
    upstream.join(timeout=5)
    for s in (client, server):
        try:
            s.close()
        except OSError:
            pass


def address(text):
    host, port = text.rsplit(":", 1)
    return host, int(port)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--listen", type=address, required=True, help="ADDRESS:PORT to serve TLS on")
    parser.add_argument("--backend", type=address, required=True, help="ADDRESS:PORT of the plain-HTTP app")
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1
    context.load_cert_chain(args.cert, args.key)

    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(args.listen)
    listener.listen(64)
    while True:
        raw, peer = listener.accept()
        try:
            client = context.wrap_socket(raw, server_side=True)
        except (ssl.SSLError, OSError) as e:
            print("TLS handshake from {} failed: {}".format(peer[0], e), file=sys.stderr)
            raw.close()
            continue
        threading.Thread(target=handle, args=(client, args.backend), daemon=True).start()


if __name__ == "__main__":
    main()
