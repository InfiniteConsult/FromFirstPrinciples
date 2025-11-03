#!/bin/sh
sudo service ssh restart

CA_CERT_PATH="data/ca-cert.pem"
if [ -f "$CA_CERT_PATH" ]; then
    echo "--- Found Local CA certificate, installing to system trust store ---"
    # Copy the CA cert into the system's trust store
    sudo cp "$CA_CERT_PATH" /usr/local/share/ca-certificates/cicd-stack-ca.crt
    # Update the system's CA list
    sudo update-ca-certificates
else
    echo "--- No Local CA certificate found at $CA_CERT_PATH, skipping system trust ---"
fi

# Check for GPG key and gitconfig on the persistent data volume
if [ -e data/private.pgp ]; then
    gpg --import data/private.pgp
fi

if [ -e data/.gitconfig ]; then
    cp data/.gitconfig ~/.gitconfig
fi

# Generate a self-signed TLS certificate for JupyterLab if one doesn't exist
if [ ! -f "data/cert.pem" ] || [ ! -f "data/key.pem" ]; then
    echo "--- Generating self-signed TLS certificate for JupyterLab and Docs server ---"
    openssl req -x509 \
      -nodes \
      -newkey rsa:4096 \
      -keyout data/key.pem \
      -out data/cert.pem \
      -sha256 \
      -days 365 \
      -subj '/CN=localhost'
fi

if [ ! -d "viewer/.venv" ]; then
    echo "--- Creating viewer venv ---"
    (
        cd viewer || exit
        python3.12 -m venv .venv
        . .venv/bin/activate
        python3 -m pip install -r requirements.txt
    )
  fi

# Activate venv and start JupyterLab in a detached tmux session
. .venv_jupyter/bin/activate
tmux new -d -s jupyterlab "jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --certfile=data/cert.pem --keyfile=data/key.pem"
tmux new -d -s docs "cd ~/viewer && . .venv/bin/activate && python3 server.py"

# Execute the command passed to `docker run`, or default to bash
bash