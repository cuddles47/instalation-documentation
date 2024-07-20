# node exporter setup document by kewwi

# Mục lục

- [node exporter setup document by kewwi](#node-exporter-setup-document-by-kewwi)
  - [Mục lục](#mục-lục)
  - [Cấu hình máy chủ](#cấu-hình-máy-chủ)
  - [step 1 : Create a system user for Node Exporter](#step-1--create-a-system-user-for-node-exporter)
  - [step 2 : Download](#step-2--download)
  - [step 3 : Extract node exporter from the archive](#step-3--extract-node-exporter-from-the-archive)
  - [step 4 : Move binary to the /usr/local/bin](#step-4--move-binary-to-the-usrlocalbin)
  - [step 6 : Verify that you can run the binary](#step-6--verify-that-you-can-run-the-binary)
  - [step 7 : Node Exporter has a lot of plugins that we can enable. If you run Node Exporter help you will get all the options](#step-7--node-exporter-has-a-lot-of-plugins-that-we-can-enable-if-you-run-node-exporter-help-you-will-get-all-the-options)
  - [step 8 :Next, create similar systemd unit file](#step-8-next-create-similar-systemd-unit-file)
  - [step 9 :Paste below code to node\_exporter.service file](#step-9-paste-below-code-to-node_exporterservice-file)
  - [step 10 : Automatically start the Node Exporter after reboot, enable the service](#step-10--automatically-start-the-node-exporter-after-reboot-enable-the-service)
  - [step 11 : Start the Node Exporter](#step-11--start-the-node-exporter)
  - [step 12 : Check the status of Node Exporter with the following command](#step-12--check-the-status-of-node-exporter-with-the-following-command)

# Cấu hình máy chủ

================

Phần mềm được cài đặt trên máy chủ có:

- Hệ điều hành: Ubuntu 20.04 server

- CPU: 2 core (Khuyến nghị 4 core)

- RAM: 8GB  (Khuyến nghị 8GB)

- Bộ nhớ: 50GB (Khuyến nghị 100GB)

- Cho phép truy cập SSH từ xa.

# Bắt đầu

================

## step 1 : Create a system user for Node Exporter

```sh

sudo useradd

     --system

    --no-create-home

    --shell /bin/false node_exporter

```

## step 2 : Download 
Use wget command to download binary (get other version [here](https://prometheus.io/download/))

```sh

wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz

```

## step 3 : Extract node exporter from the archive

```sh

tar -xvf node_exporter-1.3.1.linux-amd64.tar.gz

```

## step 4 : Move binary to the /usr/local/bin

```sh

sudo mv

  node_exporter-1.3.1.linux-amd64/node_exporter

  /usr/local/bin/

  ```

## step 5 : Clean up, delete node_exporter archive and a folder

```sh

rm -rf node_exporter*

```

## step 6 : Verify that you can run the binary

```sh

node_exporter --version

```

## step 7 : Node Exporter has a lot of plugins that we can enable. If you run Node Exporter help you will get all the options

```sh

node_exporter --help

```

## step 8 :Next, create similar systemd unit file

```sh

sudo vim /etc/systemd/system/node_exporter.service

```

## step 9 :Paste below code to node_exporter.service file

```yaml

[Unit]

Description=Node Exporter

Wants=network-online.target

After=network-online.target

StartLimitIntervalSec=500

StartLimitBurst=5

[Service]

User=node_exporter

Group=node_exporter

Type=simple

Restart=on-failure

RestartSec=5s

ExecStart=/usr/local/bin/node_exporter

    --collector.logind

[Install]

WantedBy=multi-user.target

```

## step 10 : Automatically start the Node Exporter after reboot, enable the service

```sh

sudo systemctl enable node_exporter

```

## step 11 : Start the Node Exporter

```sh

sudo systemctl start node_exporter

```

## step 12 : Check the status of Node Exporter with the following command

```sh

sudo systemctl status node_exporter

```
