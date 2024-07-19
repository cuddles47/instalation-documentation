# prometheus setup document

## Mục lục

- [Hướng dẫn cài đặt Prometheus trên Ubuntu Server 20.04](#hướng-dẫn-cài-đặt-prometheus-trên-ubuntu-server-2004)
  - [Mục lục](#mục-lục)  
  - [Bước 1 : Tạo một người dùng Linux chuyên dụng hay còn được gọi là tài khoản hệ thống cho Prometheus](#bước-1--tạo-một-người-dùng-linux-chuyên-dụng-hay-còn-được-gọi-là-tài-khoản-hệ-thống-cho-prometheus)
  - [Bước 2 : Tải xuống Prometheus bằng curl hoặc wget](#bước-2--tải-xuống-prometheus-bằng-curl-hoặc-wget)
  - [Bước 3 : Giải nén và di chuyển các file Prometheus từ kho lưu trữ](#bước-3--giải-nén-và-di-chuyển-các-file-prometheus-từ-kho-lưu-trữ)
  - [Bước 4 : Dọn dẹp và thu hồi tài nguyên](#bước-4--dọn-dẹp-và-thu-hồi-tài-nguyên)
  - [Bước 5 : Xác minh rằng bạn có thể thực thi tệp nhị phân Prometheus](#bước-5--xác-minh-rằng-bạn-có-thể-thực-thi-tệp-nhị-phân-prometheus)
  - [Bước 6 : Điều chỉnh file prometheus.service](#bước-6--điều-chỉnh-file-prometheusservice)
  - [Bước 7 : Khởi động Prometheus](#bước-7--khởi-động-prometheus)

Cấu hình máy chủ
================

Phần mềm được cài đặt trên máy chủ có:

-   Hệ điều hành: Ubuntu 20.04 server

-   CPU: 2 core (Khuyến nghị 4 core)

-   RAM: 8GB  (Khuyến nghị 8GB)

-   Bộ nhớ: 50GB (Khuyến nghị 100GB)

-   Cho phép truy cập SSH từ xa.

Bắt đầu
=======

## Bước 1 : Tạo một người dùng Linux chuyên dụng hay còn được gọi là tài khoản hệ thống cho Prometheus.
Việc có người dùng riêng cho từng dịch vụ phục vụ hai mục đích chính :
- giảm tác động trong trường hợp xảy ra sự cố với dịch vụ
- đơn giản hóa việc quản lý và cấp quyền\
chạy lệnh sau để tạo người dùng hệ thống :
```sh
sudo useradd \
-- system \
-- no-create-home \
-- shell /bin/false prometheus
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXcYs5A4TRpH7fUv-aRH7YNJRKjTEWvlXaDEskcfoPUVLj3jrzF_Ca8JENE1bAAorKPl5INsVzOevvnfNZYdklcVIM3qPk9jdrkp8VdH3gx_02Gh-Dlktjcg91I9UAB9BblqlIxmqungBJdG54B9iLF-lNdK?key=GNGwM7x8FcjuZoSehwKGXg)

## Bước 2 : Tải xuống prometheus bằng curl hoặc wget

```sh
wget [https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz](https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz)
```
chọn phiên bản [tại đây](https://prometheus.io/download/)![](https://lh7-us.googleusercontent.com/docsz/AD_4nXcY-rqYr_99aXEmyxpsRG6pO_IrrPwc0k-bMR2iq4vGxplTAdXdbcLdhfyn7uPuzGXgtIsJatTOSxmmRxD_0VH3dXo7e6MB3-KbQoIL6ChKXSG2Pi8KL2d_WOc7lBKemJHpvhk7ILbKMy38N7m_u8yp7JMt?key=GNGwM7x8FcjuZoSehwKGXg)

## Bước 3 : Giải nén và di chuyển các file prometheus từ kho lưu trữ
```sh
tar -xvf prometheus-2.32.1.linux-amd64.tar.gz\
sudo mkdir -p /data /etc/prometheus\
cd prometheus-2.32.1.linux-amd64\
sudo mv prometheus promtool /usr/local/bin/\
sudo mv prometheus.yml /etc/prometheus/prometheus.yml\
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXeU8D1hTsP6G5Ix4KRC4pH2KqxLIyydrOGv27Bu8NFB6Odl9fhKoxdv1CFeJdKarlsLxCe2jbBSG1SJxY0M6_Epnapl6b5n76zwAjqW6jgp5siaIx8tkyc9-32R8JIT_CRb7nuLNkiOoULzwtFLlkG5OSUx?key=GNGwM7x8FcjuZoSehwKGXg)\
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXf0Kw7LTmsKdWwYseHQfIUNQiLyfuR2Ba3FypAh6vbNMdIDpSY8CRFSVen9bwdNinfN8L-7EEYl0XUp1cnzT8RKd5yvWaoqSNpBbAdqM0GqhIDfKMXqq1wtySIwOOfE7QckKVX13uCZYAqRyXtSddLb1VM?key=GNGwM7x8FcjuZoSehwKGXg)

## Bước 4 : Dọn dẹp và thu hồi tài nguyên
```sh
cd\
rm -rf prometheus*
```

## Bước 5 : Xác minh rằng bạn có thể thực thi tệp nhị phân prometheus 
```sh
prometheus --version
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXebIQ4TrIKiqIj5U-fhfR2rpnIdx7Nu9GQwGQFkiudfjzJFNFBtxsK1jBj8sRkR4-KiHetBOrr1FBN6HxUZEbuRZWCDEiSxE-H3edkPUeomcujNDbS70mbcXflPcBDBCuu4MCnNUp-2ifXOUdpBBr5e2Y2f?key=GNGwM7x8FcjuZoSehwKGXg)

## Bước 6 : Điều chỉnh file prometheus.service
```sh
sudo vim /etc/systemd/system/prometheus.service
```
prometheus.service scripts :\
```service
[Unit]

Description=Prometheus

Wants=network-online.target

After=network-online.target

StartLimitIntervalSec=500

StartLimitBurst=5

[Service]

User=prometheus

Group=prometheus

Type=simple

Restart=on-failure

RestartSec=5s

ExecStart=/usr/local/bin/prometheus

			--config.file=/etc/prometheus/prometheus.yml

			--storage.tsdb.path=/data

			--web.console.templates=/etc/prometheus/consoles

			--web.console.libraries=/etc/prometheus/console_libraries

			--web.listen-address=0.0.0.0:9090

			--web.enable-lifecycle

[Install]

WantedBy=multi-user.target\
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXdj1KBgKHiGxuVUtM1z5gbVdWJktpFyrdD_Z1yxbRp9HJUgplI9BJNWVYe2qRKrvHOLJizA1SXC5qX_psan-GZncXOCtT0ucqkmuZQ3WH847vKLnAnsVISJ7Tu0AXMe6VslV7bEqoViPZn6BO1f2Ps1ELc-?key=GNGwM7x8FcjuZoSehwKGXg)

## Bước 7 : Khởi động prometheus 
Để tự động khởi động Prometheus sau khi khởi động lại, hãy chạy enable.
```sh
sudo systemctl enable prometheus
```
Sau đó chỉ cần khởi động Prometheus.
```sh
sudo systemctl start prometheus
```
Để kiểm tra trạng thái của Prometheus, hãy chạy lệnh sau:
```sh
sudo systemctl status prometheus
```
Giả sử bạn gặp bất kỳ sự cố nào với Prometheus hoặc không thể khởi động nó. Cách dễ nhất để tìm ra sự cố là sử dụng lệnh journalctl và tìm kiếm lỗi.
```sh
journalctl -u prometheus -f
```
Giờ bạn có thể truy cập nó qua trình duyệt\
http://<ip>:9090:\
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXeNAg5m0o8vwtTORzABHHBpy1a0cQco15feIGjpvX3I5XLaCpQlB9DU-djSXgY2IAggIsXbFAYR6gy4LQU7EoEfihQsJnFbAA2x_H4u-boKYAETzcFRXOTnjEzP_qdTD4f0vLZ8OavkaK76CWXun6nkrmwQ?key=GNGwM7x8FcjuZoSehwKGXg)

![](https://lh7-us.googleusercontent.com/docsz/AD_4nXeTbN4Zm9sczgptO7BiY26Ec9sIrb2_KKdXUQ7zYh_pHbmWt0nSfHdoIS_Dc5NbgVC4qkdKOA71Xbvt9VJ6n_GB235FStn0eCALqlu2E6zQ02so4WsgWYC_0CS-RTPkOZ6gVTeUV__TuiyOlottA3AW6QY?key=GNGwM7x8FcjuZoSehwKGXg)
