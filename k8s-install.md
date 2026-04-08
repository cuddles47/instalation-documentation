# Kubernetes Installation Guide

## Install RKE2 k8s Cluster

### Pre-install

**Docs:** https://docs.rke2.io/install/requirements

#### 1. Đồng bộ thời gian
*(Thực hiện trên tất cả các node master + worker)*

```bash
# Ép múi giờ hệ thống về Việt Nam (GMT+7)
timedatectl set-timezone Asia/Ho_Chi_Minh

# Cài đặt Chrony (Trình đồng bộ thời gian chuẩn Enterprise)
apt-get update && apt-get install -y chrony
# Nếu lỗi thì chạy lệnh dưới
apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update && apt-get install -y chrony

# Kích hoạt dịch vụ chạy ngầm và cho phép khởi động cùng hệ điều hành
systemctl enable --now chrony

# Kiểm tra để đảm bảo đồng hồ phần cứng (RTC) cũng được đồng bộ
hwclock --systohc

# Kiểm tra trạng thái đồng bộ (Nếu thấy 'Leap status : Normal' và 'System time' báo sai số cực nhỏ là thành công)
chronyc tracking
```

#### 2. Tunning các thông số Network
*(Thực hiện trên tất cả các node master + worker)*

```bash
sudo tee /etc/sysctl.d/99-kubernetes-cni.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.neigh.default.gc_thresh1=1024
net.ipv4.neigh.default.gc_thresh2=2048
net.ipv4.neigh.default.gc_thresh3=4096
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF

sudo sysctl --system
```

**Giải thích:**

- **ip_forward=1:** Đây là "linh hồn" của mạng K8s. Nếu không bật, các gói tin từ Pod khi đi ra interface eth0 của node sẽ bị Kernel drop ngay lập tức vì nó hiểu node không phải là một router.

- **rp_filter=0:** Đây là điểm hay gây lỗi nhất khi dùng Cilium. Cilium thường định tuyến gói tin theo những đường đi tối ưu mà Kernel có thể coi là "vô lý" (asymmetric routing). Nếu rp_filter bật (giá trị 1), Kernel sẽ chặn các gói tin này vì cho rằng đó là kỹ thuật giả mạo IP.

- **fs.inotify:** RKE2 chạy rất nhiều container, mỗi container lại có các tiến trình theo dõi file (như kubelet theo dõi config/secret). Nếu không tăng giới hạn này, bạn sẽ gặp lỗi "too many open files" rất khó debug.

#### 3. Update config cho coreDNS
*(Thực hiện trên tất cả các node master + worker)*

**Tạo thư mục sử dụng DNS public:**

```bash
sudo mkdir -p /etc/rancher/rke2
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee /etc/rancher/rke2/resolv.conf
```

**Sau này khi môi trường internet bị đóng → switch qua DNS nội bộ:**

```bash
# B1: Update nội dung configMap của coreDNS:
kubectl edit configmap rke2-coredns-rke2-coredns -n kube-system
# forward . 10.10.10.5 10.10.10.6 # Giả sử 10.10.10.5 và 10.10.10.6 là IP máy chủ DNS nội bộ

# B2: Restart pod coreDNS:
kubectl rollout restart deployment rke2-coredns-rke2-coredns -n kube-system
```

#### 4. Cấu hình OS cho CNI

**Docs:** https://docs.rke2.io/networking/basic_network_options?CNIplugin=Cilium+CNI+Plugin

**Kiểm tra hạ tầng xem có đủ điều kiện dùng cilium (master + worker):**

```bash
# Xem phiên bản Kernel
uname -r

# Kiểm tra xem Kernel có biên dịch sẵn các module BPF không
cat /boot/config-$(uname -r) | grep -E "CONFIG_CGROUP_BPF|CONFIG_BPF_SYSCALL"
# Expected: y
```

**Tạo phân vùng ảo bpffs giúp tăng tốc cho cilium (master + worker):**

```bash
# Mount BPF filesystem ngay lập tức
sudo mount bpffs -t bpf /sys/fs/bpf

# Lưu vào fstab để tự động mount lại nếu server khởi động lại
echo "bpffs /sys/fs/bpf bpf defaults,nofail 0 0" | sudo tee -a /etc/fstab
```

**Update config trên master-1:**

```bash
# Update config.yaml:
cni: ["cilium"]
disable-kube-proxy: true

# Update cấu hình nâng cao để kích hoạt tính năng Kube-proxy replacement
# File này chỉ cần thiết trên master-1, sau khi cài đặt hoàn tất thì file này sẽ tự sync sang các master còn lại
mkdir -p /var/lib/rancher/rke2/server/manifests/
sudo vim /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
```

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: true
    k8sServiceHost: 192.168.64.31  # Tạm thời chỗ này trỏ về IP chính node master-1
    k8sServicePort: 6443
```

```bash
sudo chmod 644 /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
```

### Bootstrap master-1

#### 1. Tạo /etc/rancher/rke2/config.yaml

```bash
mkdir -p /etc/rancher/rke2
sudo vim /etc/rancher/rke2/config.yaml

# Dùng kỹ thuật fake dns để sau này nếu thay đổi VIP hoặc IP loadbalancer thì không cần update lại list tls-san
sudo vim /etc/hosts
# 192.168.64.100 k8s-lb
```

#### 2. Cài đặt

> **Lưu ý:** Chỉ được install sau khi đã tạo config → Tránh trường hợp install trước node nghĩ nó là master chính

```bash
sudo apt install curl
export RKE2_VERSION="v1.34.1+rke2r1"
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} INSTALL_RKE2_TYPE=server INSTALL_RKE2_CHANNEL=stable INSTALL_RKE2_METHOD=tar sh -
apt-get update

systemctl enable rke2-server.service
systemctl restart rke2-server.service
systemctl status rke2-server

# Check
sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes
```

#### 3. Cấu hình symlink cho kubectl và kubeconfig

```bash
# Symlink cho kubectl
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

# Cấu hình cho kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config        
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Sử dụng Kube-vip: Cài đặt Kube-vip DaemonSet

- **kube-vip** dùng ARP để hút traffic về máy đang giữ VIP
- Nếu bật `lb_enable: true` → kube-vip cần IPVS để load-balance round-robin giữa các master

*(Thực hiện trên tất cả các node master)*

```bash
# Nạp module ipvs ngay lập tức
sudo apt update
sudo apt install ipset ipvsadm -y
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo modprobe nf_conntrack

# Nạp tự động sau khi reboot
cat <<EOF | sudo tee /etc/modules-load.d/kube-vip-ipvs.conf
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF
```

**Tạo file manifests trên tất cả các node master:**
- `/var/lib/rancher/rke2/server/manifests/kube-vip.yml`
- `/var/lib/rancher/rke2/server/manifests/kube-vip-rbac.yml`

```bash
# Restart master-1 để cập nhật cấu hình kube-vip:
sudo systemctl restart rke2-server

# Kiểm tra danh sách backend của IPVS:
sudo ipvsadm -ln
# Expected:
# TCP  192.168.64.100:6443 rr
#   -> 192.168.64.2:6443            Local   1      0          0         
#   -> 192.168.64.3:6443            Local   1      0          0         
#   -> 192.168.64.4:6443            Local   1      0          0  

# Restart các node master còn lại để join cluster
```

### Sử dụng HAProxy: Cài đặt HAProxy

```bash
sudo apt update
sudo apt install haproxy -y

sudo vim /etc/haproxy/haproxy.cfg
```

```
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# --- CẶP 1: DÀNH CHO KUBERNETES API ---
listen k8s-api
    bind 192.168.64.6:6443 
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    server k8s-master-1 192.168.64.2:6443 check fall 3 rise 2
    server k8s-master-2 192.168.64.3:6443 check fall 3 rise 2
    server k8s-master-3 192.168.64.4:6443 check fall 3 rise 2

# --- CẶP 2: DÀNH CHO RKE2 REGISTRATION ---
listen rke2-registration
    bind 192.168.64.6:9345 
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    server k8s-master-1 192.168.64.2:9345 check fall 3 rise 2
    server k8s-master-2 192.168.64.3:9345 check fall 3 rise 2
    server k8s-master-3 192.168.64.4:9345 check fall 3 rise 2

listen haproxy-ui
    bind *:8404             # Lắng nghe trên cổng 8404
    mode http
    stats enable
    stats uri /stats   
    stats realm HAProxy\ Statistics
    stats auth admin:password  
    stats admin if TRUE
```

> **Note:** Do RKE2 dùng cơ chế join nodes bằng password thay vì token → Node mới vào cần đi cửa sau 9345 thay vì cửa 6443 lúc này vẫn đang mã hoá

```bash
# Verify
haproxy -c -f /etc/haproxy/haproxy.cfg
# Expected: "Configuration file is valid"

sudo systemctl enable --now haproxy
sudo systemctl status haproxy.service
# Expected: Active: active (running)

# Nếu có lỗi, trace log:
sudo journalctl -u haproxy -n 100 --no-pager

# Nếu có vấn đề phải sửa /etc/haproxy/haproxy.cfg, chạy lệnh sau để reload:
sudo systemctl reload haproxy
```

### Join Worker Node

> **Lưu ý:** nhớ join các master trước

```bash
sudo apt install curl
export RKE2_VERSION="v1.34.1+rke2r1"
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} INSTALL_RKE2_TYPE=agent INSTALL_RKE2_CHANNEL=stable INSTALL_RKE2_METHOD=tar sh -
apt-get update

systemctl enable rke2-agent.service
systemctl restart rke2-agent.service
systemctl status rke2-server
```

### Network Configuration

**Docs:** https://docs.rke2.io/networking/basic_network_options?CNIplugin=Canal+CNI+Plugin

- **Canal:** Cân bằng giữa Flannel (để routing cơ bản) và Calico (để bảo mật policy)
- **Cilium:** Công nghê eBPF → Tối ưu tốc độ + bảo mật → Yêu cầu cao về phần cứng Kernel Linux
- **Calico:** Bảo mật tốt → Cấu hình phức tạp
- **Flannel:** Nhẹ → Dùng để lab

#### 1. Sử dụng Cilium

Do đã tunning OS ở trên nên lúc này chỉ cần nhớ update `config.yaml`:

```yaml
cni: ["cilium"]
disable-kube-proxy: true
```

```bash
# Update lại cấu hình rke2-cilium-config.yaml để k8sServiceHost trỏ về VIP/Loadbalancer
sudo vim /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml

sleep 120

# Kiểm tra
kubectl get pods -n kube-system -l k8s-app=cilium
# Pod: cilium-tq4h5
kubectl exec -n kube-system cilium-tq4h5 -- env | grep KUBERNETES_SERVICE_HOST
# Expected: KUBERNETES_SERVICE_HOST=192.168.64.100 → Trong đó 192.168.64.100 là VIP/Loadbalancer
```

> **Lưu ý:** 
> - KUBERNETES_SERVICE_HOST có nhiệm vụ báo cho cilium biết nên kết nối đến API server ở đâu
> - Nguyên nhân là thay vì dùng kube-proxy để lấy rules như canal, cilium gọi thẳng đến API server để lấy rules để routing
> - Nếu trên cả 3 master đều có file `/var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml` thì file nào được sửa cuối cùng → được apply

#### 2. Sử dụng Canal hoặc Calico mặc định

```yaml
cni: canal
# hoặc
cni: calico
```

#### 3. Sử dụng Calico custom với Tigera Operator

```bash
# B1: Update cni từ ["canal"] → ["none"]
# B2: Khởi động RKE2 lên
sudo systemctl enable --now rke2-server
# Lúc này các nodes sẽ NotReady do chưa có network

# B3: Cài CRD Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/tigera-operator.yaml

# Đợi 20s
sleep 20

# Tạo file cấu hình network
vim custom-resources.yaml
```

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.42.0.0/16    # Chỉ định dải ip-pod
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
    nodeAddressAutodetectionV4:
      firstFound: true
```

```bash
# Triển khai cấu hình:
kubectl create -f custom-resources.yaml

# Kiểm tra:
kubectl get pods -n calico-system
# Expected:
# NAME                                       READY   STATUS    RESTARTS   AGE
# calico-kube-controllers-5f95bbdd84-757ch   1/1     Running   0          80s
# calico-node-5s6ms                          1/1     Running   0          80s
# calico-typha-77fc495f-78l7v                1/1     Running   0          80s
# csi-node-driver-tslqn                      2/2     Running   0          80s
```

## Uninstall RKE2 k8s Cluster

### Remove RKE2 k8s cluster

```bash
# Kill toàn bộ các container/pod đang chạy của RKE2
sudo /usr/local/bin/rke2-killall.sh

# Chạy script gỡ cài đặt (nếu là worker node thì dùng rke2-agent-uninstall.sh)
sudo /usr/local/bin/rke2-uninstall.sh || sudo /usr/local/bin/rke2-agent-uninstall.sh

# Dừng và vô hiệu hóa các service liên quan:
sudo systemctl stop rke2-server rke2-agent rancher-system-agent
sudo systemctl disable rke2-server rke2-agent rancher-system-agent
sudo systemctl reset-failed

# Kill các process còn sót:
sudo pkill -9 rke2
sudo pkill -9 containerd
sudo pkill -9 kube-apiserver
sudo pkill -9 etcd
sudo pkill -9 cilium

# Unmount các volume của kubelet và rke2
for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do sudo umount $mount; done

# Xóa CNI interface (thường là cni0, flannel.1, cilium_host...)
sudo ip link delete cilium_host || true
sudo ip link delete cilium_net || true
sudo ip link delete cilium_vxlan || true
sudo ip link delete kube-ipvs0 || true
sudo ip link delete lxc_health || true

# Reset filter table
sudo iptables -F
sudo iptables -X
# Reset nat table
sudo iptables -t nat -F
sudo iptables -t nat -X
# Reset mangle table
sudo iptables -t mangle -F
sudo iptables -t mangle -X
# Save lại (tùy OS, ví dụ Ubuntu)
sudo netfilter-persistent save || true
# VIP
sudo ip addr del 192.168.64.100/32 dev enp0s1 || true

# Unmount mạng ảo (nếu có)
sudo umount -lf /run/netns/cni-* || true

# Xóa cấu hình Kube-vip & IPVS (Chỉ chạy trên Master)
sudo rm -f /etc/modules-load.d/kube-vip-ipvs.conf
sudo modprobe -r ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack || true
sudo apt-get purge -y ipset ipvsadm

# Xoá cấu hình Fake DNS trong /etc/hosts
sudo sed -i '/k8s-lb/d' /etc/hosts

# Remove cilium config
sudo umount /sys/fs/bpf || true
sudo sed -i '/bpffs/d' /etc/fstab
sudo rm -f /etc/sysctl.d/99-kubernetes-cni.conf
sudo sysctl --system
# Lưu ý: Nếu lệnh này gây treo máy thì cần vào console để reboot

# Xóa các thư mục dữ liệu chính
sudo rm -rf /etc/ceph \
       /etc/cni \
       /etc/kubernetes \
       /etc/rancher \
       /opt/cni \
       /opt/rke \
       /run/secrets/kubernetes.io \
       /run/calico \
       /run/flannel \
       /var/lib/calico \
       /var/lib/etcd \
       /var/lib/cni \
       /var/lib/kubelet \
       /var/lib/rancher \
       /var/log/containers \
       /var/log/kube-audit \
       /var/log/pods \
       /var/run/calico \
       /var/run/cilium

# Xóa các binary còn sót (nếu có)
sudo rm -f /usr/local/bin/rke2 \
       /usr/local/bin/kubectl \
       /usr/local/bin/crictl

# Reboot
sudo reboot
```

### Remove HAProxy

```bash
# Dừng dịch vụ
sudo systemctl stop haproxy

# Vô hiệu hóa (để không tự khởi động lại khi reboot)
sudo systemctl disable haproxy

# Gỡ bỏ hoàn toàn HAProxy
sudo apt purge haproxy -y

# Dọn dẹp các gói tin phụ thuộc không còn cần thiết
sudo apt autoremove -y

# Reboot:
sudo reboot
```

---

## Install Kubeadm k8s Cluster

**Phiên bản:** Kubernetes v1.34.5  
**Network Plugin:** Canal (VXLAN)  
**Pod CIDR:** 10.42.0.0/16  
**Service CIDR:** 10.43.0.0/16  
**Môi trường:** Ubuntu 22.04 (3 Masters, 3 Workers)

### Step 1: Tunning OS
*(Thực hiện trên tất cả các nodes)*

#### Đặt hostname chuẩn cho từng máy

```bash
sudo hostnamectl set-hostname master-1
# Lặp lại tương tự cho master-2, master-3, worker-1...
```

#### Update /etc/hosts

```bash
cat <<EOF | sudo tee -a /etc/hosts
192.168.64.2  master-1
192.168.64.3  master-2
192.168.64.4  master-3
192.168.64.10 worker-1
# ... thêm các worker khác nếu có

# Khai báo IP của Load Balancer (Nếu chưa có HAProxy ngoài, trỏ tạm về master-1)
192.168.64.2  k8s-lb
EOF
```

#### Tắt Swap và cấu hình Kernel modules

```bash
# Tắt swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Mở Module overlay và br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Cho phép IP Forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Sửa trực tiếp net.ipv4.ip_forward = 1
sudo sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf

# Áp dụng
sudo sysctl --system

# Chốt hạ kiểm tra biến trong RAM
cat /proc/sys/net/ipv4/ip_forward
# Expected: 1
```

### Step 2: Cài trong container runtime (containerd) và kube tools
*(Thực hiện trên tất cả các nodes)*

#### Cài đặt kubelet, kubeadm, kubectl

```bash
# Dọn dẹp cache
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Cài các gói phụ trợ
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Xóa key cũ (nếu có) và tải Key v1.34 mới nhất
sudo mkdir -p -m 755 /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Cấp quyền cho user '_apt' được phép đọc chìa khóa
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Ghi đè repo list của v1.34
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update lại apt để nhận repo mới
sudo apt-get update

# Cài đặt kubelet, kubeadm, kubectl và khóa version
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Check
kubectl version
```

#### Cài đặt containerd

```bash
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd

# Tạo config mặc định cho containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Bắt buộc sửa SystemdCgroup = true
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Lấy tự động tên bản pause image mà kubeadm đang yêu cầu
PAUSE_IMAGE=$(kubeadm config images list | grep pause)
# Dùng lệnh sed để tự động tìm và thay thế dòng sandbox_image
sudo sed -i "s|sandbox_image = .*|sandbox_image = \"$PAUSE_IMAGE\"|g" /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl status containerd
```

### Step 3: Init k8s cluster trên master-1

#### 1. Xác định entrypoint (VIP, HAProxy, IP master)

```bash
sudo apt install haproxy -y

sudo vim /etc/haproxy/haproxy.cfg
```

```
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 2500

defaults
    log     global
    mode    http
    option  tcplog
    option  dontlognull    

    timeout connect 5000
    timeout client  50000
    timeout server  50000

    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

listen stats
    bind *:8089
    mode http
    stats enable
    stats hide-version
    stats realm Haproxy\ Statistics
    stats uri /admin?stats
    stats auth admin:admin
    http-request use-service prometheus-exporter if { path /metrics }

listen k8s-lb
    mode tcp
    bind *:8443       
    timeout connect 30000
    timeout client  120000
    timeout server  120000

    # Dồn kết nối vào master-1, giảm tải đồng bộ cho etcd
    server master-1 192.168.64.2:6443 id 1 check
    server master-2 192.168.64.3:6443 id 2 check backup
    server master-3 192.168.64.4:6443 id 3 check backup
```

```bash
# Verify
haproxy -c -f /etc/haproxy/haproxy.cfg
# Expected: "Configuration file is valid"

sudo systemctl enable --now haproxy
sudo systemctl status haproxy.service
# Expected: Active: active (running)

# Nếu có lỗi, trace log:
sudo journalctl -u haproxy -n 100 --no-pager

# Reload để nhận cấu hình haproxy
sudo systemctl reload haproxy
```

#### 2. Init master-1

**Tạo file kubeadm-config.yaml:**

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "v1.34.5"         # Lấy theo: kubectl version
controlPlaneEndpoint: "k8s-lb:6443"  # Điểm neo entrypoint (VIP hoặc DNS)
networking:
  podSubnet: "10.42.0.0/16"          # Quy hoạch dải IP cho Pod
  serviceSubnet: "10.43.0.0/16"      # Quy hoạch dải IP cho Service
apiServer:
  certSANs:                          # Danh sách IP/Domain hợp lệ của chứng chỉ TLS
  - "cluster.local"
  - "k8s-lb"
  - "192.168.64.2"
  - "192.168.64.3"
  - "192.168.64.4"
  - "master-1"
  - "master-2"
  - "master-3"
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  name: "master-1"                   # Định danh node (giống hostname)
  kubeletExtraArgs:                  
  - name: "node-ip"                  # IP master-1
    value: "192.168.64.2"    
```

**Khởi tạo cluster:**

```bash
sudo kubeadm init --config kubeadm-config.yaml --upload-certs
```

> **Giải thích:**
> - `--control-plane-endpoint`: Khai báo VIP của HAProxy. Đây chính là điểm neo cho toàn bộ hệ thống
> - `--upload-certs`: Upload chứng chỉ TLS gốc lên etcd để tí nữa Master-2 và Master-3 có thể tải về xài chung

**Update kubectl config:**

```bash
unset KUBECONFIG
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 3. Cấu hình Network - CNI

**Option 1: Sử dụng Canal mặc định**

```bash
# Tải file cấu hình mạng Canal gốc về máy
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/canal.yaml

# Thay thế dải IP mặc định bằng dải IP 10.42.0.0/16
sed -i 's/10.244.0.0\/16/10.42.0.0\/16/g' canal.yaml

# Triển khai Canal vào Cluster
kubectl apply -f canal.yaml
```

**Option 2: Sử dụng Calico Operator**

```bash
# Cài đặt Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/tigera-operator.yaml

# Đợi 20s
sleep 20

# Tạo file cấu hình network
vim custom-resources.yaml
```

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.42.0.0/16    # Chỉ định dải ip-pod
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
    nodeAddressAutodetectionV4:
      firstFound: true
```

```bash
# Triển khai cấu hình:
kubectl create -f custom-resources.yaml

# Kiểm tra:
kubectl get pods -n calico-system
```

> **Giải thích:**
> - **calico-node:** Xử lý định tuyến (BGP/eBPF) và tường lửa (Network Policy) dưới mức Kernel → DaemonSet
> - **calico-kube-controllers:** Theo dõi K8s API để dịch các sự kiện thành luật mạng
> - **calico-typha:** Làm Proxy trung gian để giảm tải cho Kube-API Server
> - **csi-node-driver:** Trình điều khiển lưu trữ tiêu chuẩn (CSI) → DaemonSet

### Step 4: Join các master và worker

#### 1. Join Master

**Tạo file kubeadm-config.yaml:**

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "k8s-lb:6443"     # Điểm neo VIP/DNS
    token: "ch7ir9.md2agmi6hq8gkb9p"     # Lấy từ kết quả kubeadm init
    caCertHashes:
    - "sha256:a6fcbbf310ffb8abd3b080001145fba97913935ae6e42f311952d3802a59ad1d"
controlPlane:
  certificateKey: "0aecfe00e9ee8722ead66aca53c20060ce60129275da57ce68daeed38b7d6576"
nodeRegistration:
  name: "master-2"                       
  kubeletExtraArgs:
  - name: "node-ip"
    value: "192.168.64.3"
```

```bash
# Join master:
sudo kubeadm join --config kubeadm-config.yaml

# Update kubectl config
unset KUBECONFIG
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 2. Join Worker

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "k8s-lb:6443"
    token: "ch7ir9.md2agmi6hq8gkb9p"
    caCertHashes:
    - "sha256:a6fcbbf310ffb8abd3b080001145fba97913935ae6e42f311952d3802a59ad1d"
nodeRegistration:
  name: "worker-1"                       
  kubeletExtraArgs:
  - name: "node-ip"
    value: "192.168.64.4"
```

```bash
# Join worker:
sudo kubeadm join --config kubeadm-config.yaml    
```

**Fix sai node-ip:**

```bash
# Sửa file môi trường của kubelet:
sudo vim /var/lib/kubelet/kubeadm-flags.env
# Thay node-ip mới: --node-ip=192.168.64.4

# Restart kubelet
sudo systemctl restart kubelet

# Kiểm tra
kubectl get nodes -o wide
```

### Step 5: Vận hành cơ bản

> **Lưu ý:** Token hết hạn sau 24 giờ, và certificateKey hết hạn sau 2 giờ

**Tạo lệnh Join mới khi token hết hạn:**

```bash
# Tạo lệnh Join cho Worker mới (Lấy token mới):
kubeadm token create --print-join-command

# Sinh key mới để Join Master mới:
sudo kubeadm init phase upload-certs --upload-certs
# Lấy certificate-key mới vừa sinh ra đắp vào file YAML
```

**Verify Cluster:**

```bash
# Pod BE
kubectl run nginx-server --image=nginx --port=80
# clusterIP
kubectl expose pod nginx-server --port=80 --target-port=80 --name=nginx-service
# Pod FE
kubectl run client-test --image=curlimages/curl --restart=Never -- sleep 3600
# Test kết nối
kubectl exec client-test -- wget -qO- http://nginx-service

# Nếu lỗi:
# kubectl exec client-test -- wget -qO- http://nginx-service
# → Lỗi bad address → Không resolve được dns
# kubectl exec client-test -- wget -qO- http://10.43.94.48
# → Lỗi timed out → Gói tin đi ra có vấn đề, có thể bị drop
```

### Fix Network Issues on Kubeadm Cluster (Calico on OpenStack)

#### Vấn đề

- Pod A gửi gói tin đến clusterIP cho pod B
- Không thể resolve DNS
- Gửi thẳng IP thì bị timeout

#### 1. Xử lý Checksum Offloading
*(Thực hiện trên tất cả các node)*

```bash
# Tắt checksum tự động trên card mạng vật lý của VM
ethtool -K ens3 tx-checksum-ip-generic off

# Tắt checksum tự động trên card mạng ảo của Calico
ethtool -K vxlan.calico tx-checksum-ip-generic off
```

#### 2. Kiểm tra cấu hình IPPool của Calico

```bash
kubectl get ippools -o yaml
# Nếu kết quả: vxlanMode: CrossSubnet
```

> Calico chỉ sử dụng hầm VXLAN khi 2 node nằm ở 2 dải mạng khác nhau. Nếu các node nằm cùng dải (VD: 172.24.11.0/24) → gói tin sẽ được gửi với IP trực tiếp của pod (VD: 10.42.126.199)

#### 3. Kiểm tra bảng định tuyến

```bash
# Đứng từ Worker-2, kiểm tra đường đi tới IP Pod đích trên Worker-1
ip route get 10.42.126.199
# Expected: 10.42.126.199 via 172.24.11.41 dev ens3 src 172.24.11.42
```

#### 4. Bắt gói tin thực tế

```bash
# Lắng nghe gói tin gửi đến IP Pod đích
tcpdump -ni ens3 host 10.42.126.199

# Từ Pod trên Worker-2 gọi sang Pod trên Worker-1
kubectl exec client-test -- wget -qO- http://10.43.94.48
```

> IP 10.42.243.133 > 10.42.126.199: Flags [S] ... (Cờ SYN liên tục không có phản hồi)

#### 5. Nguyên nhân lỗi

- Các Node (VM) nằm cùng Subnet → Calico không đóng gói VXLAN, gửi gói với IP của Pod
- OpenStack có Port Security (Anti-Spoofing) → kiểm tra mọi gói tin đi ra
- Gói tin mang IP 10.42.x.x từ card mạng cấp IP 172.24.11.42 → coi là IP Spoofing → Drop

#### 6. Khắc phục

```bash
# Force Calico luôn đóng gói gói tin (Encapsulation)
kubectl patch ippool default-ipv4-ippool --type merge -p '{"spec":{"vxlanMode":"Always"}}'

sleep 60
```

## Uninstall Kubeadm k8s Cluster

### BƯỚC 1: Hủy Kubeadm và Dừng Service

```bash
# Hủy config kubeadm (bỏ qua lỗi nếu chưa init)
sudo kubeadm reset -f || true

# Dừng và vô hiệu hóa service
sudo systemctl stop kubelet containerd || true
sudo systemctl disable kubelet containerd || true
sudo systemctl reset-failed

# Kill các process:
sudo pkill -9 rke2
sudo pkill -9 containerd
sudo pkill -9 kube-apiserver
sudo pkill -9 etcd
```

### BƯỚC 2: Unmount Tàn Dư

```bash
echo "Unmounting stale volumes and network namespaces..."
for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet; do sudo umount -lf $mount || true; done

# Ép nhả các namespace mạng
sudo umount -lf /run/netns/cni-* || true
```

### BƯỚC 3: Xóa Gói Cài Đặt

```bash
# Mở khóa và purge toàn bộ tool k8s
sudo apt-mark unhold kubelet kubeadm kubectl || true
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni cri-tools containerd
sudo apt-get autoremove -y
```

### BƯỚC 4: Dọn Rác Ổ Cứng

```bash
echo "Removing data and log directories..."
sudo rm -rf \
    /etc/kubernetes \
    /etc/cni \
    /opt/cni \
    /var/lib/etcd \
    /var/lib/kubelet \
    /var/lib/cni \
    /var/lib/calico \
    /var/run/calico \
    /var/run/flannel \
    /var/log/containers \
    /var/log/pods \
    /var/log/kube-audit \
    /etc/containerd \
    $HOME/.kube \
    /root/.kube
```

### BƯỚC 5: Tẩy Trắng Mạng và Tường Lửa

```bash
# Xóa card mạng ảo
sudo ip link delete cni0 || true
sudo ip link delete flannel.1 || true
sudo ip link delete vxlan.calico || true
sudo ip link delete kube-ipvs0 || true
sudo ip link delete dummy0 || true

# Flush Iptables
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X

# Save trạng thái
sudo netfilter-persistent save || true
```

### BƯỚC 6: Hoàn Lương HĐH

```bash
# Bật lại Swap
sudo swapon -a
sudo sed -i '/ swap / s/^#//g' /etc/fstab

# Xóa config tuning OS
sudo rm -f /etc/modules-load.d/k8s.conf
sudo rm -f /etc/sysctl.d/k8s.conf
sudo sysctl --system

# Reboot
sudo reboot
```
