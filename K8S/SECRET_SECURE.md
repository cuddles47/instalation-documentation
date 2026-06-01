### Phân tích các lớp bảo vệ Secret trong Kubernetes

#### Bài toán 1: Secret Management & GitOps

Mục tiêu là lưu trữ toàn bộ cấu hình hệ thống, bao gồm cả secret, trên Git để phục vụ GitOps, version control, audit và quản trị tập trung mà không làm lộ dữ liệu nhạy cảm.

Giải pháp phổ biến là Sealed Secrets. Thay vì commit Kubernetes Secret trực tiếp lên Git, secret sẽ được mã hóa bất đối xứng bằng public key của cluster thông qua utility `kubeseal` ở phía client. Kết quả là một đối tượng `SealedSecret` có thể lưu trữ an toàn trên repository. Chỉ Sealed Secrets Controller trong cluster, nơi nắm giữ private key, mới có khả năng giải mã và tạo lại Kubernetes Secret thực tế.

Tuy nhiên, Sealed Secrets chỉ giải quyết bài toán **secret-at-rest** (bảo vệ secret khi lưu trữ trên Git), chưa giải quyết được bài toán **runtime secret exposure**.

---

#### Bài toán 2: Runtime Secret Security

Sau khi được giải mã trong cluster, Kubernetes vẫn phải phân phối secret cho ứng dụng.

Luồng mặc định hiện nay là:

```text
Secret
    ↓
Kubelet
    ↓
Container Runtime
    ↓
Environment Variable / Mounted File
    ↓
Application
```

Khi secret được inject dưới dạng environment variable hoặc mounted file, secret sẽ xuất hiện trong runtime context của container. Điều này đồng nghĩa bất kỳ process hoặc shell session nào bên trong container đều có khả năng tiếp cận secret nếu có đủ quyền truy cập.

Đây là điểm yếu khi container hoặc ứng dụng bị compromise.

Cách tiếp cận của X00 là giảm sự phụ thuộc vào Kubernetes Secret runtime injection. Thay vì đưa secret vào toàn bộ container namespace, X00 sử dụng eBPF để hook vào các syscall như `execve()` và chỉ inject secret cho những process được phép dựa trên process identity, executable path hoặc cgroup. Nhờ đó secret chỉ xuất hiện ở đúng process cần sử dụng thay vì toàn bộ container.

Mô hình này tuân thủ nguyên tắc:

```text
Need-to-Know
```

thay vì:

```text
Container-wide Secret Exposure
```

---

#### Bài toán 3: Bảo vệ Secret khi Container bị Compromise

Ngay cả khi secret chỉ được inject cho một process cụ thể, secret vẫn phải tồn tại trong memory (heap, stack hoặc các memory region khác) để ứng dụng sử dụng.

Nếu attacker có thể:

```bash
kubectl exec
```

hoặc chiếm được quyền root trong container, họ vẫn có thể cố gắng đọc memory của process thông qua:

```text
/proc/<pid>/environ
/proc/<pid>/mem
ptrace()
gdb
```

Đây là các cơ chế chuẩn của Linux cho phép quan sát hoặc debug process.

Để giảm thiểu rủi ro này, X00 sử dụng BPF-LSM (Linux Security Module dựa trên eBPF) để áp dụng các policy ở mức kernel, ngăn chặn việc đọc `environ`, truy cập `mem` hoặc thực hiện `ptrace` đối với các process chứa secret.

Kết quả là ngay cả khi người dùng có shell hoặc quyền root bên trong container, việc thu thập secret từ process memory cũng trở nên khó khăn hơn đáng kể.

---

### Tóm tắt theo mô hình phòng thủ nhiều lớp

```text
Layer 1
Git Security
→ Sealed Secrets

Layer 2
Runtime Secret Distribution
→ eBPF Secret Injection

Layer 3
Memory Protection
→ BPF-LSM
```

