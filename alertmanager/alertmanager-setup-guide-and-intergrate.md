# Alertmanager setup document

## Mục lục

- [Alertmanager setup document](#alertmanager-setup-document)
  - [Mục lục](#mục-lục)
  - [Cấu hình máy chủ](#cấu-hình-máy-chủ)
- [Bắt đầu](#bắt-đầu)
  - [Bước 1 : Tạo một người dùng Linux chuyên dụng](#bước-1--tạo-một-người-dùng-linux-chuyên-dụng)
  - [Bước 2 : Tải xuống prometheus bằng curl hoặc wget](#bước-2--tải-xuống-prometheus-bằng-curl-hoặc-wget)
  - [Bước 3 : Giải nén và di chuyển các file prometheus từ kho lưu trữ](#bước-3--giải-nén-và-di-chuyển-các-file-prometheus-từ-kho-lưu-trữ)
  - [Bước 4 : Dọn dẹp và thu hồi tài nguyên](#bước-4--dọn-dẹp-và-thu-hồi-tài-nguyên)
  - [Bước 5 : Xác minh rằng bạn có thể thực thi tệp nhị phân alertmanager bằng cách chạy lệnh sau](#bước-5--xác-minh-rằng-bạn-có-thể-thực-thi-tệp-nhị-phân-alertmanager-bằng-cách-chạy-lệnh-sau)
  - [Bước 6 : Điều chỉnh file alertmanager.service](#bước-6--điều-chỉnh-file-alertmanagerservice)
  - [Bước 7 : Khởi động Alertmanager](#bước-7--khởi-động-alertmanager)
  - [Bước 8 : Tạo alert dead mans snitch](#bước-8--tạo-alert-dead-mans-snitch)
  - [Bước 9 : Update file config của prometheus](#bước-9--update-file-config-của-prometheus)
  - [Bước 10 : Dùng promtool để check config trước khi restart](#bước-10--dùng-promtool-để-check-config-trước-khi-restart)
  - [Bước 11 : Restart và check status dịch vụ](#bước-11--restart-và-check-status-dịch-vụ)
  - [Bước 12 : Tích hợp với slack](#bước-12--tích-hợp-với-slack)
  - [Bước 13 : Restart và check status của dịch vụ](#bước-13--restart-và-check-status-của-dịch-vụ)
  - [Bước 14 : Thêm rule để kiểm tra tích hợp với slack](#bước-14--thêm-rule-để-kiểm-tra-tích-hợp-với-slack)
  - [Bước 15 : Kiểm tra cấu hình prometheus và reload ](#bước-15--kiểm-tra-cấu-hình-prometheus-và-reload)
  - [Bước 16 : Kích hoạt cảnh váo bằng cách gửi metrics mới và prometheus pushgateway](#bước-16--kích-hoạt-cảnh-váo-bằng-cách-gửi-metrics-mới-và-prometheus-pushgateway)
  - [Bước 17 : Kiểm tra slack](#bước-17--kiểm-tra-slack)
- [Alert rules reference](#alert-rules-reference)
## Cấu hình máy chủ
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
Tạo người dùng linux chuyên dụng hay còn được gọi là tài khoản hệ thống cho Alertmanager. Việc có người dùng riêng cho từng dịch vụ phục vụ hai mục đích chính :
- giảm tác động trong trường hợp xảy ra sự cố với dịch vụ\
- đơn giản hóa việc quản lý và cấp quyền\
chạy lệnh sau để tạo người dùng hệ thống :
```sh
sudo useradd \
   --system  \
   --no-create-home \
   --shell /bin/false alertmanager
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXdkLL8pQwd7CSFkjUOR962GrlRnhEI2nlrA2nW1Cwu5QLjLuSRx-xa1ZzprWC2lPfbuiyAU7211M41OG6JM9DSRNgLsgxIf13SgHVo76_dthmVj8CDePYIBBqAk7SlEnA4WMCiCPaOEfHh3f4gGV0LQOIQG?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 2 : Tải xuống prometheus bằng curl hoặc wget
```sh
wget https://github.com/prometheus/alertmanager/releases/download/v0.23.0/alertmanager-0.23.0.linux-amd64.tar.gz
```
chọn phiên bản [tại đây](https://prometheus.io/download/)
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXf4_N_sjBpllEmCzT2SwC7mjLVSWZKpq-XX5ivzjyjnA8J08E5dUUyOvb2dvAWHn4-vubvfiGwu4INxXdSGecijmlvLu2pn7DBRtciAMBqDorJ0OExbefa5ubjeeztmFI7twKgeWXjU1FVKcniC8cH_xHcF?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 3 : Giải nén và di chuyển các file prometheus từ kho lưu trữ
```sh
tar -xvf alertmanager-0.23.0.linux-amd64.tar.gz/
sudo mkdir -p /data /etc/prometheus/
sudo mv alertmanager-0.23.0.linux-amd64/alertmanager /usr/local/bin/
sudo mv alertmanager-0.23.0.linux-amd64/alertmanager.yml /etc/alertmanager/
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXe0GaWrFIkTe5jYxZ0u3Nw1rJLM5YZ1I1pd1sxXPAu74vF5IraD4bARUrFfaJVtKAxgulk1qVztw-SKGlCgE016j9Mm_zFMJJf-S1ZVOqcFsVzAVULnd1AxDHT6ttjOtolUPOeFoc7CD1vbDw33lVozxLzt?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 4 : Dọn dẹp và thu hồi tài nguyên
```sh
rm -rf alertmanager*
```

## Bước 5 : Xác minh rằng bạn có thể thực thi tệp nhị phân alertmanager bằng cách chạy lệnh sau
```sh
alertmanager--version
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXcja-DE2Ikt50hkaoXDp6_42LVHmyjblq7SZDlok1zpk5Rh9ttrC3x7PTi-pIk7pl1TC4cJkNlWiLfZtJbhDA-pl_S-ZKjl1xV16RimXMbtAnEIbLXOAqofp8jLtfCodUr_V1wBnu38j1trIfeOvlwrcup8?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 6 : Điều chỉnh file alertmanager.service
```sh
sudo vim /etc/systemd/system/alertmanager.service
```
alertmanager.service scripts :
```yml
[Unit]

Description=Alertmanager

Wants=network-online.target

After=network-online.target

StartLimitIntervalSec=500

StartLimitBurst=5

[Service]

User=alertmanager

Group=alertmanager

Type=simple

Restart=on-failure

RestartSec=5s

ExecStart=/usr/local/bin/alertmanager

  --storage.path=/alertmanager-data

  --config.file=/etc/alertmanager/alertmanager.yml

[Install]

WantedBy=multi-user.target
```

![](https://lh7-us.googleusercontent.com/docsz/AD_4nXdVC40sRYnAeBuZ6v1-1FBvb1P9bmbZfzbMRy4UjOxqHXDtcVF4LEU4fKH30f2kw-oDEOd3WAFIR0Q04rD28jOVqRhc6eqSqVKuGfaogVlAcaxjjYznMuph9AsZGdRhaDRUjZLEXfj11n9NdYfYhKVGtxdE?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 7 : Khởi động Alertmanager
Để tự động khởi động Alertmanager sau khi khởi động lại, hãy chạy enable.
```sh
sudo systemctl enable alertmanager
```
Sau đó chỉ cần khởi động Alertmanager.
```sh
sudo systemctl start alertmanager
```
Để kiểm tra trạng thái của Alertmanager, hãy chạy lệnh sau:
```sh
sudo systemctl status alertmanager
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXeuza8D8JdU1kuRToGPuK1LgXQM9qzyxLsFqIgbX2BDP4ryyyCrftU-wY75Lj6S9zJtjnr7nZwzxKDH94xNCpt4U3MqrsbsMMUV2wvCBzFG00Zy2abnDAvBb_G3f69LY4-l8MG9nl5OrY42wH6FRl_zhzXj?key=IyyMZ2m2wlVblNcI5EDDXg)

Giả sử bạn gặp bất kỳ sự cố nào với Alertmanager hoặc không thể khởi động nó. Cách dễ nhất để tìm ra sự cố là sử dụng lệnh journalctl và tìm kiếm lỗi.
```sh
journalctl -u alertmanager-f
```
Giờ bạn có thể truy cập nó qua trình duyệt  http://< ip>:9093 

![](https://lh7-us.googleusercontent.com/docsz/AD_4nXeKg_WztpR3KLa0L2UrI23ZU2jnt1ISBmrZDUPljv3bBnLP4zVsJS0hY-loSnR4qgeig9rNbSfHolZ6FTZONAWPO0HT5u8s3T4FwHi00cr0nML5SajvRHtsc8lY1sRXduYv_9X1Y51io0zKCiAVLp8uGiTi?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 8 : Tạo alert dead mans snitch
```sh
sudo vim /etc/prometheus/dead-mans-snitch-rule.yml
```
 dead mans snitch scripts below:
```yml
---

groups:

- name: dead-mans-snitch

  rules:

  - alert: DeadMansSnitch

    annotations:

      message: This alert is integrated with DeadMansSnitch.

    expr: vector(1)
```

## Bước 9 : Update file config của prometheus
```sh
sudo vim /etc/prometheus/prometheus.yml
```
thêm đoạn sau vào cấu hình prometheus :
```yml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093
```
```yml
rule_files:
  - dead-mans-snitch-rule.yml
```

## Bước 10 : Dùng promtool để check config trước khi restart
promtool check config /etc/prometheus/prometheus.yml
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXdAbsV_lwh2yPKR1C7odBZN6fUaWQ0IdrDz1yZu_GFLsT8zRY5yepKa6rKvbtW7x6kLIHONcgmEdgrXQ2xh8EzjwYBTkAwt-v4qorQsZ0I5wGRDzj_y1PwIOzvmYP4N_czSLDVQ5o1NqJl7uFMq3hFMmBM5?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 11 : Restart và check status dịch vụ
Chạy các lệnh sau
```sh
sudo systemctl restart prometheus
```
```sh
sudo systemctl status prometheus
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXfh4XwfhPTaf5GDn8zhmjqZ0xIFPAQRADLlEbiodbU4jGuRh0hoqEA0FyPsLeCRAWVt1FI2XCaCdicYiwQKzMWgHrGT1n0VLnHdA9tuJQjVspXzO3e46Ls6HYVUb3kMsvspcvV6MsnBpa5V5KUfebhIXKPR?key=IyyMZ2m2wlVblNcI5EDDXg)

## Bước 12 : Tích hợp với slack
- Tạo 1 channel Slack\
- Tạo Slack App , chọn new Slack App from scratch. Give it a name and select a workspace\
- Enable incoming webhook sau đó thêm webhoo vào workspace\
- Copy webhook url và thêm vào cấu hình Alertmanager\
vào cấu hình alertmanager và cấu hình new route gửi cảnh báo tới Slack
```sh
sudo vim /etc/alertmanager/alertmanager.yml
```
alertmanager.yml scripts : 
```yml
---

route:

  group_by: ['alertname']

  group_wait: 30s

  group_interval: 5m

  repeat_interval: 1h

  receiver: 'web.hook'

  routes:

  - receiver: slack-notifications

    match:

      severity: warning

receivers:

- name: 'web.hook'

  webhook_configs:

  - url: 'http://127.0.0.1:5001/'

- name: slack-notifications

  slack_configs:

  - channel: "#alerts"

    send_resolved: true

    api_url: "https://hooks.slack.com/services/< id>"

    title: "{{ .GroupLabels.alertname }}"

    text: "{{ range .Alerts }}{{ .Annotations.message }}\n{{ end }}"

inhibit_rules:

  - source_match:

      severity: 'critical'

    target_match:

      severity: 'warning'

    equal: ['alertname', 'dev', 'instance']
```

## Bước 13 : Restart và check status của dịch vụ
```sh
sudo systemctl restart alertmanager
```
```sh
sudo systemctl status alertmanager
```
## Bước 14 : Thêm rule để kiểm tra tích hợp với slack
```sh
sudo vim /etc/prometheus/batch-job-rules.yml
```
batch-job-rules scripts : 
```yml
---

groups:

- name: batch-job-rules

  rules:

  - alert: JenkinsJobExceededThreshold

    annotations:

      message: Jenkins job exceeded a threshold of 30 seconds.

    expr: jenkins_job_duration_seconds{job="backup"} > 30

    for: 1m

    labels:

      severity: warning
```
sau đó add rule vào cấu hình prometheus như hướng dẫn với dead-mans-snitch bên trên

## Bước 15 : Kiểm tra cấu hình prometheus và reload 
```sh
promtool check config /etc/prometheus/prometheus.yml
```
thay user_account và password
```sh
curl -X POST -u user_account:password http://localhost:9090/-/reload
```

## Bước 16 : Kích hoạt cảnh váo bằng cách gửi metrics mới và prometheus pushgateway
```sh
echo "jenkins_job_duration_seconds 31.87" | curl --data-binary @- http://localhost:9091/metrics/job/backup
```
## Bước 17 : Kiểm tra slack
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXf62G6xIyWcnExtaO4nVynIS_NKXbXPr0Gp68aZkAINIFEpEoQaaaqpYSLyyT3MQm55vbX_jJm013qKN3pv-qAm2yKDgExXpX04vGpRya72XQVx24ZHQVgnEHahLGXdpRpFHv0OWbcgI1jlB0xgMyfcW_iv?key=IyyMZ2m2wlVblNcI5EDDXg)

# Alert rules reference
xem thêm rules [tại đây](https://samber.github.io/awesome-prometheus-alerts/rules.html)
