#!/bin/bash

# ==============================
# CONFIG (EDIT HERE)
# ==============================

NODE_NAME=$1
NODE_IP=$2

CLUSTER_TOKEN="percona_cluster"

NODE1_NAME="dvs-foms-eoms-postgres01"
NODE1_IP="172.24.13.131"

NODE2_NAME="dvs-foms-eoms-postgres02"
NODE2_IP="172.24.13.132"

NODE3_NAME="dvs-foms-eoms-postgres03"
NODE3_IP="172.24.13.133"

DATA_DIR="/var/lib/etcd"

# ==============================
# VALIDATE INPUT
# ==============================

if [ -z "$NODE_NAME" ] || [ -z "$NODE_IP" ]; then
  echo "Usage: $0 <NODE_NAME> <NODE_IP>"
  exit 1
fi

# ==============================
# GENERATE INITIAL CLUSTER STRING
# ==============================

INITIAL_CLUSTER="${NODE1_NAME}=http://${NODE1_IP}:2380,${NODE2_NAME}=http://${NODE2_IP}:2380,${NODE3_NAME}=http://${NODE3_IP}:2380"

# ==============================
# DETERMINE CLUSTER STATE
# ==============================

if [ "$NODE_NAME" == "$NODE1_NAME" ]; then
  CLUSTER_STATE="new"
else
  CLUSTER_STATE="existing"
fi

# ==============================
# STOP ETCD
# ==============================

echo "Stopping etcd..."
systemctl stop etcd

# ==============================
# CLEAN OLD DATA (IMPORTANT)
# ==============================

echo "Cleaning old data..."
rm -rf ${DATA_DIR}/*

# ==============================
# WRITE CONFIG
# ==============================

echo "Writing config..."

cat > /etc/etcd/etcd.conf.yaml <<EOF
name: '${NODE_NAME}'

initial-cluster-token: ${CLUSTER_TOKEN}
initial-cluster-state: ${CLUSTER_STATE}
initial-cluster: ${INITIAL_CLUSTER}

data-dir: ${DATA_DIR}

initial-advertise-peer-urls: http://${NODE_IP}:2380
listen-peer-urls: http://${NODE_IP}:2380

advertise-client-urls: http://${NODE_IP}:2379
listen-client-urls: http://${NODE_IP}:2379,http://127.0.0.1:2379
EOF

# ==============================
# START ETCD
# ==============================

echo "Starting etcd..."
systemctl daemon-reexec
systemctl restart etcd
systemctl enable etcd

sleep 3

# ==============================
# CHECK STATUS
# ==============================

echo "Checking etcd status..."
systemctl status etcd --no-pager

echo "Done."
