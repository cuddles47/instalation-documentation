# node exporter setup document by kewwi 

**step 1 : create a system user for Node Exporter**
```sh
sudo useradd \
    --system \
    --no-create-home \
    --shell /bin/false node_exporter
```
**step 2 : Use wget command to download binary**(get other version [here](https://prometheus.io/download/))
```sh
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
```
**step 3 : Extract node exporter from the archive**
```sh
tar -xvf node_exporter-1.3.1.linux-amd64.tar.gz
```
**step 4 : Move binary to the /usr/local/bin**
```sh
sudo mv \
  node_exporter-1.3.1.linux-amd64/node_exporter \
  /usr/local/bin/
  ```
**step 5 : Clean up, delete node_exporter archive and a folder**
```sh
rm -rf node_exporter*
```
**step 6 : Verify that you can run the binary.**
```sh
node_exporter --version
```
**step 7 : Node Exporter has a lot of plugins that we can enable. If you run Node Exporter help you will get all the options.**
```sh
node_exporter --help
```
**step 8 :Next, create similar systemd unit file.**
```sh
sudo vim /etc/systemd/system/node_exporter.service
```
**step 9 :Paste below code to node_exporter.service file**
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
ExecStart=/usr/local/bin/node_exporter \
    --collector.logind

[Install]
WantedBy=multi-user.target
```
**step 10 : Automatically start the Node Exporter after reboot, enable the service**
```sh
sudo systemctl enable node_exporter
```
**step 11 : Start the Node Exporter.**
```sh
sudo systemctl start node_exporter
```
**step 12 : Check the status of Node Exporter with the following command:**
```sh
sudo systemctl status node_exporter
```
