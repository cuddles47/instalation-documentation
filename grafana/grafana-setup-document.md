# grafana setup document  

## Mục lục

- [grafana setup document](#grafana-setup-document)
  - [Mục lục](#mục-lục)
  - [Cấu hình máy chủ](#cấu-hình-máy-chủ)
- [Bước 1 : Cài đặt dependencies](#bước-1--cài-đặt-dependencies)
- [Bước 2 : Thêm khóa CPG](#bước-2--thêm-khóa-cpg)
- [Bước 3 : Sau khi bạn thêm kho lưu trữ, hãy cập nhật và cài đặt Grafana.](#bước-3--sau-khi-bạn-thêm-kho-lưu-trữ-hãy-cập-nhật-và-cài-đặt-grafana)
- [Bước 4 : Khởi động Grafana](#bước-4--khởi-động-grafana)

## Cấu hình máy chủ
================

Phần mềm được cài đặt trên máy chủ có:

-   Hệ điều hành: Ubuntu 20.04 server

-   CPU: 2 core (Khuyến nghị 4 core)

-   RAM: 8GB   (Khuyến nghị 8GB)

-   Bộ nhớ: 50GB  (Khuyến nghị  100GB)

-   Cho phép truy cập SSH từ xa.

================

# Bước 1 : Cài đặt dependencies
```sh
sudo apt-get install -y apt-transport-https software-properties-common\
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXeBQB0SI2XdbMZzYl2eHAJ-1cbAoy2p2hNjyF-qt1S4KHEXVmapSZMn41I-GWlt8Tsg6L_y9FAPMuowNemCvxMwj8GSdbfl1f2VDcCz7GLaXM9ENf7CUoa7qaw4pQz5pUMNf1Htkr-fnhFk7rJGdz0B6Lq7?key=KlWMgODr0HM5OGs9sD0aNg)

# Bước 2 : Thêm khóa CPG
```sh
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -\
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXfPur30_65HyzehqDF4HSczJdVXFuLACH104eQoE8N3Nlb_xbZTG3VwaPPciaO4bgjBJjZBHfdY0UP_LKVnT4VanDMAn2ngnXb6LteZOA5VKwtLHQWQWw3b9gM5Vgfv2fN34c2rl44-jYTeZF80w061Wfs?key=KlWMgODr0HM5OGs9sD0aNg)

Thêm kho lưu trữ này cho các bản phát hành ổn định\
```sh
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list\
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXfrmK2SSkeJ3YUj5N561h_YWQv7e1T2pNKRYhv5qWgDynOcneeEHMzv3W6wRwk1YVI8t5w4RPwgeD1R7EMyL6sxNzXBF6kw41yVOKTXRLH_MXYxoSj64rBR4d3Zf6ioj5ZiXrdqcwU4NoN6qaoiJlouNGFX?key=KlWMgODr0HM5OGs9sD0aNg)

# Bước 3 : Sau khi bạn thêm kho lưu trữ, hãy cập nhật và cài đặt Grafana.
```sh
sudo apt-get update

sudo apt-get -y install grafana\
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXcstP5Iub489dejwLdsfV6chpSkycwy3w2fcJwL9G_RJ6V60iP4mUjBSs4iBlkHDUSGPtdhB9QESFvswYIipfHXBg286_0ZHI4WxwC2jjTH3_rJ-ZzZlI8m6NBGzc9YMDS5lzaOqkEEYVRGSVC9vxrY0RER?key=KlWMgODr0HM5OGs9sD0aNg)

# Bước 4 : Khởi động Grafana
Để tự động khởi động Grafana sau khi khởi động lại, hãy chạy enable.
```sh
sudo systemctl enable grafana-server\
```
Sau đó chỉ cần khởi động Grafana.
```sh
sudo systemctl start grafana-server
```
Để kiểm tra trạng thái của Grafana, hãy chạy lệnh sau:
```sh
sudo systemctl status grafana-server
```
Giả sử bạn gặp bất kỳ sự cố nào với Grafana hoặc không thể khởi động nó. Cách dễ nhất để tìm ra sự cố là sử dụng lệnh journalctl và tìm kiếm lỗi.
```sh
journalctl -u grafana-f\
```
![](https://lh7-us.googleusercontent.com/docsz/AD_4nXeLpDgrDRBJUQWXXYM8pdEFTlrMthp-HZwjQ5fNKHREPFA3kEMJBe48u8wpjd0HR0G33yFBoJ-3Qg09TbPXOQwbZ4YHLSblzvA8McTjJKfgsEQkB4iN3RpbGVzcO2hbFN8ssKJjQKiDTJEJRbHzTP-ZVU-h?key=KlWMgODr0HM5OGs9sD0aNg)\
Giờ bạn có thể truy cập nó qua trình duyệt với thông tin đăng nhập mặc định là account : admin\
và password : admin\
http://<ip>:3000

