#!/bin/bash
#SBATCH --time=1:00:00
export JUPYTER_TOKEN="$(cat ~/.jupyter-tls/token)"
jupyter lab --no-browser --ip="$(hostname -i)" --port=28417 \
    --certfile="$HOME/.jupyter-tls/cert.pem" --keyfile="$HOME/.jupyter-tls/key.pem" \
    --ServerApp.port_retries=0
