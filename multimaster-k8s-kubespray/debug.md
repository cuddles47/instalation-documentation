Dưới đây là một **tài liệu hoàn chỉnh** tóm tắt lại **các lỗi đã gặp**, **nguyên nhân**, và **cách khắc phục** trong quá trình bạn tạo và cấu hình cụm Kubernetes bằng `kubeadm`. Tài liệu này được trình bày theo từng bước, có thể dùng để chia sẻ lại hoặc ghi chú nội bộ.

---

# 📘 Tài liệu tổng hợp lỗi và cách xử lý khi tạo cụm Kubernetes bằng `kubeadm`

## 📌 Môi trường sử dụng

* Hệ điều hành: Ubuntu Server 20.04+
* Phương pháp cài: `kubeadm` tạo cụm thủ công
* Cấu hình:

  * 1 master node (`sb-k8s-master01`)
  * 1 hoặc nhiều worker nodes
* Công cụ hỗ trợ: Docker / containerd, Helm, Lens, Lens Metrics

---

## 1. 🧨 Lỗi: `Failed to remove the cluster context. Please check your kubeconfig file permissions.`

### ✅ Nguyên nhân:

* Không đủ quyền ghi file `~/.kube/config`
* File `config` có chủ sở hữu không đúng (VD: thuộc `root`)

### 💡 Cách xử lý:

```bash
# Sửa quyền file config
sudo chown $(id -u):$(id -g) ~/.kube/config
sudo chmod 600 ~/.kube/config
```

---

## 2. 🧨 Lỗi: `coredns` hoặc `kube-proxy` pod CrashLoopBackOff

### ✅ Nguyên nhân:

* Thiếu mạng pod (CNI plugin chưa cài)
* Thiết lập `kubeadm init` chưa thêm `--pod-network-cidr`

### 💡 Cách xử lý:

* Khi init master:

```bash
kubeadm init --pod-network-cidr=192.168.0.0/16
```

* Sau khi init thành công, cài CNI:

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

---

## 3. 🧨 Lỗi: `The connection to the server localhost:8080 was refused - did you specify the right host or port?`

### ✅ Nguyên nhân:

* Chưa cấu hình `kubectl` sau `kubeadm init`

### 💡 Cách xử lý:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```


## 🧰 Một số lệnh tiện ích khi quản trị cụm

```bash
# Xem các pod đang chạy
kubectl get pods -A

# Xem logs của pod
kubectl logs -n <namespace> <pod-name>

# Xem node
kubectl get nodes -o wide

# Join node mới vào cluster
# (chạy trên worker)
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Khởi tạo lại cluster (reset nếu hỏng)
kubeadm reset
```

---

## 📦 Khuyến nghị addon

| Tên              | Chức năng     | Gợi ý                                    |
| ---------------- | ------------- | ---------------------------------------- |
| Calico / Flannel | Mạng pod      | Cần thiết                                |
| metrics-server   | Đo tài nguyên | Hữu ích cho `kubectl top`                |
| Helm             | Quản lý addon | Cực kỳ tiện dụng                         |
| Lens Metrics     | GUI tiện lợi  | Dễ dùng nhưng hay lỗi, nên biết cách xoá |

---

## ✅ Kết luận

Việc dựng cụm Kubernetes bằng `kubeadm` cần sự cẩn thận về quyền, mạng, và addon. Lens là công cụ GUI mạnh nhưng có thể gây lỗi nếu thao tác chưa đúng. Tài liệu này giúp bạn chủ động hơn khi gặp sự cố.

---

Nếu bạn muốn mình đóng gói tài liệu này thành file `.md` (Markdown) hoặc `.pdf`, mình có thể tạo giúp. Bạn cũng có thể bổ sung mục `Câu hỏi thường gặp` nếu muốn.
