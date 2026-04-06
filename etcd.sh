#!/bin/bash

set -e

# CONFIG (EDIT HERE)

CLUSTER_TOKEN="cluster"
DATA_DIR="/var/lib/etcd"

# DEFINE CLUSTER HERE (NAME=IP)
NODES=(
  "server-1=172.24.13.131"
  "server-2=172.24.13.132"
  "server-3=172.24.13.133"
  # add thêm hosts nếu có nhiều hơn 3 node
  # set hosts, conf static ip trên các node thủ công
)

# ==============================
# INPUT
# ==============================

NODE_NAME=$1
NODE_IP=$2

if [ -z "$NODE_NAME" ] || [ -z "$NODE_IP" ]; then
  echo "Usage: $0 <NODE_NAME> <NODE_IP>"
  exit 1
fi

# ==============================
# WARNINGS
# ==============================

NODE_COUNT=${#NODES[@]}

if (( NODE_COUNT % 2 == 0 )); then
  echo "WARNING: etcd cluster should have odd number of nodes (current: $NODE_COUNT)"
fi

# ==============================
# BUILD INITIAL CLUSTER STRING
# ==============================

INITIAL_CLUSTER=""

for node in "${NODES[@]}"; do
  NAME=$(echo $node | cut -d'=' -f1)
  IP=$(echo $node | cut -d'=' -f2)

  if [ -z "$INITIAL_CLUSTER" ]; then
    INITIAL_CLUSTER="${NAME}=http://${IP}:2380"
  else
    INITIAL_CLUSTER="${INITIAL_CLUSTER},${NAME}=http://${IP}:2380"
  fi
done

# ==============================
# DETERMINE FIRST NODE
# ==============================

FIRST_NODE=$(echo ${NODES[0]} | cut -d'=' -f1)

CLUSTER_STATE="existing"
if [ "$NODE_NAME" == "$FIRST_NODE" ]; then
  CLUSTER_STATE="new"
fi

# ==============================
# SHOW CONFIG
# ==============================

echo "===================================="
echo "Node Name:        $NODE_NAME"
echo "Node IP:          $NODE_IP"
echo "Cluster State:    $CLUSTER_STATE"
echo "Cluster Token:    $CLUSTER_TOKEN"
echo "Initial Cluster:  $INITIAL_CLUSTER"
echo "===================================="


# ==============================
# UFW ALLOW
# ==============================

echo "Configuring UFW firewall..."
ufw allow 2379/tcp
ufw allow 2380/tcp
ufw reload || true

# ==============================
# STOP ETCD
# ==============================

echo "Stopping etcd..."
systemctl stop etcd || true

# ==============================
# CLEAN DATA
# ==============================

echo "Cleaning data-dir..."
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
# HEALTH CHECK
# ==============================

echo "Checking local endpoint..."
if ! curl -s http://127.0.0.1:2379/health | grep -q "true"; then
  echo "etcd is NOT healthy"
  exit 1
fi

echo "etcd is healthy"

# ==============================
# MEMBER LIST (ONLY FROM FIRST NODE)
# ==============================

if [ "$NODE_NAME" == "$FIRST_NODE" ]; then
  echo "Cluster members:"
  etcdctl --endpoints=http://127.0.0.1:2379 member list || true
else
  echo "Run member add from FIRST node ($FIRST_NODE)"
fi

echo " Done."
