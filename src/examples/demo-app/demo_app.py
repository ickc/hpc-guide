#!/usr/bin/env python3
"""A stand-in for Jupyter, RStudio, TensorBoard, ... in the examples.

It is a tiny web app that says which node it is running on. Like Jupyter, it
can require a token: if APP_TOKEN is set, a request must carry ?token=<it>,
otherwise it gets a 403.

    python3 demo_app.py --host 127.0.0.1 --port 8888

Only the standard library, and nothing newer than Python 3.6, so it runs with
whatever python3 a compute node has.
"""
import argparse
import os
import socket
import socketserver
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

TOKEN = os.environ.get("APP_TOKEN", "")
NODE = socket.gethostname()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        token = parse_qs(urlparse(self.path).query).get("token", [""])[0]
        if TOKEN and token != TOKEN:
            self.reply(403, "<h1>403</h1><p>Wrong or missing token.</p>")
        else:
            self.reply(200, "<h1>It works</h1><p>Served from <b>{}</b>.</p>".format(NODE))

    def reply(self, status, html):
        body = ("<!doctype html><meta charset=utf-8><title>demo app</title>" + html).encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Server(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    Server((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
