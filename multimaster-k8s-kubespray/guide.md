# Hướng dẫn cài đặt Kubernetes Cluster bằng Kubespray

## 📋 Yêu cầu hệ thống

**Cấu hình mẫu:**
- **Kubernetes version:** 1.28.5
- **Công cụ triển khai:** Kubespray v2.23.0
- **Số lượng node:** 6 nodes + 1 installation server
- **User:** root cho tất cả các node

### Sơ đồ mạng
| Loại node | IP Address | Vai trò |
|-----------|------------|---------|
| Master 1  | 172.27.4.31/24 | Control Plane + etcd |
| Master 2  | 172.27.4.32/24 | Control Plane + etcd |
| Master 3  | 172.27.4.33/24 | Control Plane + etcd |
| Worker 1  | 172.27.4.41/24 | Worker Node |
| Worker 2  | 172.27.4.42/24 | Worker Node |
| Worker 3  | 172.27.4.43/24 | Worker Node |

---

## 🔐 Bước 1: Cấu hình SSH Key (trên Installation Server)

Tạo SSH key và copy đến tất cả các node để thực hiện passwordless SSH:

```bash
# Tạo SSH key
ssh-keygen -t rsa

# Copy SSH key đến tất cả các node
for ip in 172.27.4.31 172.27.4.32 172.27.4.33 172.27.4.41 172.27.4.42 172.27.4.43; do
  ssh-copy-id root@$ip
done
```

**Mục tiêu:** Cấp quyền SSH không cần password từ installation server đến các node.

---

## 📦 Bước 2: Cài đặt Kubespray

### 2.1 Download và checkout version phù hợp

> **Lưu ý:** Kubespray latest sẽ cài Kubernetes latest. Chọn đúng version Kubespray để cài bản K8s mong muốn.

```bash
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout v2.23.0  # Hỗ trợ Kubernetes 1.28.x
```

### 2.2 Cài đặt dependencies (trên Installation Server)

```bash
# Cập nhật hệ thống
sudo apt update
sudo apt install -y python3 python3-pip git sshpass

# Cài đặt Python packages
pip3 install --upgrade pip
pip3 install ansible jinja2

# Cài đặt requirements của Kubespray
cd kubespray
sudo pip3 install -r requirements.txt
```

### 2.3 Chuẩn bị các node (trên tất cả các node)

```bash
# Tắt swap tạm thời
swapoff -a

# Tắt swap vĩnh viễn (disable trong /etc/fstab)
sudo sed -i '/swap/d' /etc/fstab

# Kiểm tra resolv.conf hiện tại
readlink -f /etc/resolv.conf

# Tạo symlink DNS (nếu cần thiết)
mkdir -p /run/systemd/resolve
ln -sf /etc/resolv.conf /run/systemd/resolve/resolv.conf
```

> **⚠️ Lưu ý quan trọng:**
> - Kiểm tra `/etc/resolv.conf` có đang là symlink đến systemd-resolved không
> - Nếu không phải, cần thiết lập lại đúng theo systemd hoặc sử dụng DNS hợp lệ khác

---

## 📝 Bước 3: Tạo inventory cho Kubespray

### 3.1 Tạo inventory từ mẫu

```bash
cp -rfp inventory/sample inventory/mycluster
```

### 3.2 Tạo file `inventory/mycluster/hosts.yaml`
```yaml
all:
  hosts:
    node1:
      ansible_host: 172.27.4.31
      ip: 172.27.4.31
      access_ip: 172.27.4.31
    node2:
      ansible_host: 172.27.4.32
      ip: 172.27.4.32
      access_ip: 172.27.4.32
    node3:
      ansible_host: 172.27.4.33
      ip: 172.27.4.33
      access_ip: 172.27.4.33
    node4:
      ansible_host: 172.27.4.41
      ip: 172.27.4.41
      access_ip: 172.27.4.41
    node5:
      ansible_host: 172.27.4.42
      ip: 172.27.4.42
      access_ip: 172.27.4.42
    node6:
      ansible_host: 172.27.4.43
      ip: 172.27.4.43
      access_ip: 172.27.4.43

  children:
    kube_control_plane:
      hosts:
        node1:
        node2:
        node3:
    kube_node:
      hosts:
        node4:
        node5:
        node6:
    etcd:
      hosts:
        node1:
        node2:
        node3:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
```

---

## ⚙️ Bước 4: Cấu hình Kubespray

### 4.1 Cấu hình Kubernetes version

Mở file `inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml` và cấu hình:

```yaml
kube_version: v1.28.5
```

### 4.2 Xác nhận container runtime

Trong cùng file `inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml`:

```yaml
container_manager: containerd
```

---

## 🚀 Bước 5: Triển khai cụm Kubernetes

Chạy lệnh sau từ installation server:

```bash
ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml
```

> **💡 Mẹo:** Có thể thêm `-v`, `-vv` hoặc `-vvv` để xem log chi tiết nếu có lỗi

---

## ✅ Bước 6: Kiểm tra cụm K8s

Sau khi hoàn tất, SSH vào một trong 3 master node (VD: `172.27.4.31`) và kiểm tra:

```bash
# Thiết lập kubeconfig
export KUBECONFIG=/etc/kubernetes/admin.conf

# Kiểm tra các node
kubectl get nodes

# Kiểm tra tất cả pods
kubectl get pods -A
```

---

## ♻️ Reset Cluster (nếu triển khai lỗi)

Trong trường hợp cài đặt thất bại hoặc cần cài đặt lại cluster, thực hiện các bước sau:

### Reset trên tất cả các node (Master và Worker)

```bash
# Reset cấu hình kubeadm
kubeadm reset -f

# Gỡ bỏ các package Kubernetes
apt-get purge -y kubelet kubeadm kubectl

# Xóa các thư mục cấu hình và data
rm -rf ~/.kube /etc/cni /etc/kubernetes /var/lib/etcd /var/lib/kubelet /etc/containerd
```

### Sau khi reset, thực hiện lại từ bước 2.3

> **⚠️ Cảnh báo:** 
> - Lệnh này sẽ xóa toàn bộ cấu hình Kubernetes
> - Chạy trên cả master và worker nodes
> - Backup dữ liệu quan trọng trước khi reset

---

## 📚 Ghi chú quan trọng

- ✅ Đảm bảo tất cả các node có thể kết nối internet để download images
- ✅ Firewall cần được cấu hình đúng cho các port của Kubernetes
- ✅ Swap phải được tắt trên tất cả các node
- ✅ DNS resolution phải hoạt động đúng giữa các node

## 🔧 Troubleshooting

### Các lỗi thường gặp và cách khắc phục:

#### 1. Lỗi SSH connectivity
```bash
# Kiểm tra SSH từ installation server
ssh root@<node-ip> "echo 'SSH OK'"

# Nếu lỗi, kiểm tra SSH key
ssh-copy-id -f root@<node-ip>
```

#### 2. Lỗi DNS resolution
```bash
# Kiểm tra DNS trên các node
nslookup google.com
ping google.com

# Kiểm tra resolv.conf
cat /etc/resolv.conf
```

#### 3. Lỗi download packages/images
```bash
# Kiểm tra internet connectivity
curl -I https://github.com
curl -I https://registry.k8s.io

# Kiểm tra proxy/firewall settings
```

#### 4. Lỗi Ansible
```bash
# Chạy với verbose để xem chi tiết
ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml -vvv

# Kiểm tra Ansible có thể connect đến các host
ansible -i inventory/mycluster/hosts.yaml all -m ping
```

### Các bước debug nâng cao:

1. **Kiểm tra connectivity giữa các node**
2. **Xem log chi tiết với `-vvv`**
3. **Đảm bảo SSH key được copy đúng**
4. **Kiểm tra DNS và network configuration**
5. **Verify firewall rules cho Kubernetes ports**
6. **Kiểm tra disk space và memory trên các node**

---

## 📖 Tài liệu tham khảo

- [Kubespray Official Documentation](https://kubespray.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Ports and Protocols](https://kubernetes.io/docs/reference/ports-and-protocols/)
- [Troubleshooting kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)
