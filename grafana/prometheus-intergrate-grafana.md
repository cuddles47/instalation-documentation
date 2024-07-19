# prometheus intergrate grafana document  

## Mục lục

- [prometheus intergrate grafana document](#prometheus-intergrate-grafana-document)
  - [Mục lục](#mục-lục)
  - [Cấu hình máy chủ](#cấu-hình-máy-chủ)
- [Bước 1 : Add data source](#bước-1--add-data-source)
- [Bước 2 : Khởi động lại dịch vụ để load config](#bước-2--khởi-động-lại-dịch-vụ-để-load-config)


## Cấu hình máy chủ
================

Phần mềm được cài đặt trên máy chủ có:

-   Hệ điều hành: Ubuntu 20.04 server

-   CPU: 2 core (Khuyến nghị 4 core)

-   RAM: 8GB   (Khuyến nghị 8GB)

-   Bộ nhớ: 50GB  (Khuyến nghị  100GB)

-   Cho phép truy cập SSH từ xa.

================
# Bước 1 : Add data source
Để trực quan hóa số liệu, trước tiên bạn cần thêm nguồn dữ liệu. Nhấp Add data source và chọn Prometheus. Đối với URL, hãy nhập <http://localhost:9090>  và nhấp vào Save and test. Bạn có thể thấy Data source is working

1 cách làm khác là add data source dưới dạng mã
```sh
sudo vim /etc/grafana/provisioning/datasources/datasources.yaml
```
datasources.yaml scripts:
```yaml
apiVersion: 1

datasources:

   - name: Prometheus
     type: prometheus
     url: http://localhost:9090
     isDefault: true
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXd7T7OK8BQlTdEgHcTjK82V6OBOnP15tW7oQxJSvgENF12qI1a6gwrbice6vALA5WOIn9ujSd_uDXSMbBJ5JXBHyvFS9l2naUrMERjNM-UiKJ6Lb2MuWDpRVvRSWuww-7Jv2H9mhp4TarHNKF2cwOKZbTJE?key=KlWMgODr0HM5OGs9sD0aNg)

# Bước 2 : Khởi động lại dịch vụ để load config
chạy lệnh sau 
```sh
sudo systemctl restart grafana-server
```
