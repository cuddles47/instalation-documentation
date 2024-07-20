# Pushgateway setup document

# Mục lục

- [Pushgateway setup document](#pushgateway-setup-document)
- [Cấu hình máy chủ](#cấu-hình-máy-chủ)
- [Bắt đầu](#bắt-đầu)
  - [Bước 1 : Tạo một người dùng Linux chuyên dụng](#bước-1--tạo-một-người-dùng-linux-chuyên-dụng)
  - [Bước 2 : Tải xuống prometheus bằng curl hoặc wget](#bước-2--tải-xuống-prometheus-bằng-curl-hoặc-wget)
  - [Bước 3 : Giải nén và di chuyển các file prometheus từ kho lưu trữ](#bước-3--giải-nén-và-di-chuyển-các-file-prometheus-từ-kho-lưu-trữ)
  - [Bước 4 : Dọn dẹp và thu hồi tài nguyên](#bước-4--dọn-dẹp-và-thu-hồi-tài-nguyên)
  - [Bước 5 : Xác minh rằng bạn có thể thực thi tệp nhị phân pushgateway bằng cách chạy lệnh sau](#bước-5--xác-minh-rằng-bạn-có-thể-thực-thi-tệp-nhị-phân-pushgateway-bằng-cách-chạy-lệnh-sau)
  - [Bước 6 : Điều chỉnh file pushgateway.service](#bước-6--điều-chỉnh-file-pushgatewayservice)
  - [Bước 7 : Khởi động PushGateway](#bước-7--khởi-động-pushgateway)
  - [Bước 8 : Thêm PushGateway như 1 target của prometheus](#bước-8--thêm-pushgateway-như-1-target-của-prometheus)
  - [Bước 9 : Dùng promtool để kiểm tra cấu hình của Prometheus và reload config](#bước-9--dùng-promtool-để-kiểm-tra-cấu-hình-của-prometheus-và-reload-config)
  
# Cấu hình máy chủ
================

Phần mềm được cài đặt trên máy chủ có:

-   Hệ điều hành: Ubuntu 20.04 server

-   CPU: 2 core (Khuyến nghị 4 core)

-   RAM: 8GB   (Khuyến nghị 8GB)

-   Bộ nhớ: 50GB  (Khuyến nghị  100GB)

-   Cho phép truy cập SSH từ xa.

# Bắt đầu
================

## Bước 1 : Tạo một người dùng Linux chuyên dụng 
Tạo một người dùng Linux chuyên dụng hay còn được gọi là tài khoản hệ thống cho PushGateway. Việc có người dùng riêng cho từng dịch vụ phục vụ hai mục đích chính :
- giảm tác động trong trường hợp xảy ra sự cố với dịch vụ\
- đơn giản hóa việc quản lý và cấp quyền\
chạy lệnh sau để tạo người dùng hệ thống :
```sh
sudo useradd \
-- system \
-- no-create-home \
-- shell /bin/false pushgateway
```
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdH_oQkKwB517t1SIRzKyzPrC2iyv8jJy95raYWhrj5C56QNIVexTmB7KB6VHUMPqVuGvmBb6pI95cnlPp3XyEgg9T4nwoi4rRuDHcGLc4Whr0-BEroVmyw_MCgV1U5AB3AzoyWZae_iEt2m0I_SrUTWFKs?key=3x_hHM-VbkFAM466sYQpVQ)

## Bước 2 : Tải xuống prometheus bằng curl hoặc wget
```sh
wget https://github.com/prometheus/pushgateway/releases/download/v1.4.2/pushgateway-1.4.2.linux-amd64.tar.gz
```
chọn phiên bản [tại đây](https://prometheus.io/download/)![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXf-OGY7ZzTQt969V2NDTGRp96CQ0Ii_RYLD1nMCaIwzCUW-akjRoAhpOZ1vlCgoCxqDmdZtFCTsV_VIIubzP68s6aVvVvGUu5HpMd32m9bx4H6ORQzSOPzAAoHTwlao2AHvKuHX19Xl3U8YU7wIQGsX3zyO?key=3x_hHM-VbkFAM466sYQpVQ)

## Bước 3 : Giải nén và di chuyển các file prometheus từ kho lưu trữ
```sh
tar -xvf pushgateway-1.4.2.linux-amd64.tar.gz
sudo mkdir -p /data /etc/prometheus
sudo mv pushgateway-1.4.2.linux-amd64/pushgateway /usr/local/bin/
```
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfPPrHK73lwxzv4wQUN8YtxOyRqEmo_vJSYvZPI42OoaDQIKS1CJMnZ-xua9V8ICb9Wd9cbxI5oE4u3GkDu94jDH_XbU5zKSXnyrb9VAFmewjbhTeC092XRI8XCnm3EgXqE6OoOgtYg6iMfw5aCLaFTM7U?key=3x_hHM-VbkFAM466sYQpVQ)\
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXcLuuSY7bFlWMmAvlzQIiVrldexT9Ff1FYTTITTs_tA9mNCX47QFXnQknNTtabADYHbm00KAZRmBb9IL2cY6fEq66o4nAWddsD7Q_R7E2puwzJbY8ojW7I8YcYvkLGgIUI-ZXZhe1-ArLiOdm5B9giwOQM?key=3x_hHM-VbkFAM466sYQpVQ)\
## Bước 4 : Dọn dẹp và thu hồi tài nguyên
```sh
rm -rf pushgateway*
```
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfmWVDx2GWGd7e2l4YC8let6tIGuokPzFfsDFW3C33Jq0zuvw5-jGA3g0kFVWX1Fuewm8iYVq64YidXSzptl3HTh9Kcl1yP-xF30sEpaWNIkvj1umkvKTTeoo-u5QjPIbEKsXsQGYuWlMUpOWTK4Se0yI48?key=3x_hHM-VbkFAM466sYQpVQ)

## Bước 5 : Xác minh rằng bạn có thể thực thi tệp nhị phân pushgateway bằng cách chạy lệnh sau
```sh
pushgateway --version
```
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdWgNPM59MfZucJ8zCAJP1uCUib7y9GvH0FhDHaJyR1BuRSdxT6yGZmQ4CAj1jJZQKvOygjLJThuYk0og8eFJUla1H3L_j0Gsg5uvV2GWt1NncFrLKTvB_Tu4vEFknCWPOKRrqoa9i4Ce1wEfUGktFjM9zx?key=3x_hHM-VbkFAM466sYQpVQ)

## Bước 6 : Điều chỉnh file pushgateway.service
```sh
sudo vim /etc/systemd/system/pushgateway.service
```
pushgateway.service scripts :
```yml
[Unit]

Description=Pushgateway

Wants=network-online.target

After=network-online.target

StartLimitIntervalSec=500

StartLimitBurst=5

[Service]

User=pushgateway

Group=pushgateway

Type=simple

Restart=on-failure

RestartSec=5s

ExecStart=/usr/local/bin/pushgateway

[Install]

WantedBy=multi-user.target
```
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXd3mVX0aJcK1Qn2usyNLJhccFD1po_-IG7UVRQpyGqvNOxXjQsw3YiZ9e1qpa_LcAEls0_zfJX-GX36X_KDGTDY4rIiSeS93j_E7Iiy12mD91Y4dSzxejcTHdPN89DrdtqOMLx300PiYMsteWkQlpqQU5q6?key=3x_hHM-VbkFAM466sYQpVQ)

## Bước 7 : Khởi động PushGateway
Để tự động khởi động PushGateway sau khi khởi động lại, hãy chạy enable.
```sh
sudo systemctl enable pushgateway
```
Sau đó chỉ cần khởi động PushGateway.
```sh
sudo systemctl start pushgateway
```
Để kiểm tra trạng thái của PushGateway, hãy chạy lệnh sau:
```sh
sudo systemctl status pushgateway
```
Giả sử bạn gặp bất kỳ sự cố nào với PushGateway hoặc không thể khởi động nó. Cách dễ nhất để tìm ra sự cố là sử dụng lệnh journalctl và tìm kiếm lỗi.
```sh
journalctl -u pushgateway-f
```
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdG4K_bAPgm9CPnA-Vxixcz_2EnXGvoGOrGyRKCpRgXfPlp0BXyKZkTvShGwWjTMj2OV2gvOJv7V6zW-Z37pozcvbe_EhIAnL_2oKg3ZNc26xWY41hqhvBEEnsG6yzPl7kRGPun6Cb4xmcWY8C-xFNu7ThQ?key=3x_hHM-VbkFAM466sYQpVQ)\
Giờ bạn có thể truy cập nó qua trình duyệt\
http://< ip>:9091 \
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXf385xx_PUFDuL4UddwQ9DupA8IhBx4hQ2O4jC6iyRVR1xqYzXboDMx1VS_cYyKLThdhZ9qPbiSvwCbcWk1kl4kRlsigGXyqBpBTOZ1DtG9zhi8ehacqgEkEYIE-prvAcbDvU8H9VlC3zOuihCEdT0TxbI8?key=3x_hHM-VbkFAM466sYQpVQ)

## Bước 8 : Thêm PushGateway như 1 target của pronetheus
```sh
sudo vim /etc/prometheus/prometheus.yml
```
thêm đoạn scripts sau vào prometheus.yml
```yml
  - job_name: pushgateway

    honor_labels: true

    static_configs:

      - targets: ["localhost:9091"]
```
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfsDq_bM6_bYE0uGlwZ1qMxp7TY3LY_KEamy9e7gy_pj-lxMSfj3bgLmMBfT6xXIk26N0FnbWtnI1k6_4K34d1KkZnYMsAPkxmR9abLWcN0ZRWtQcwP2-oI8rF96AreN1gzH3RmougVdB7dUCC2H9EhHHQ9?key=3x_hHM-VbkFAM466sYQpVQ)\
## Bước 9: Dùng promtool để kiểm tra cấu hình của Prometheus xem có hợp lệ không và reload config
```sh
promtool check config /etc/prometheus/prometheus.yml
curl - X POST http://localhost:9090/-/reloads
```