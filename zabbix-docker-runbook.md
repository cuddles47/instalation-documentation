# Zabbix – Cài đặt, vận hành và cấu hình Monitoring

## 1. Mục đích

Tài liệu hướng dẫn triển khai và vận hành **Zabbix** cho hệ thống monitoring tập trung.

Nội dung bao gồm:

- Kiến trúc Zabbix
- Cài đặt Zabbix Server
- Cài đặt PostgreSQL
- Cài đặt Zabbix Agent 2
- Add Host
- Template
- Item
- Trigger
- Discovery
- SNMP monitoring
- Web/API monitoring
- User/permission
- Action và notification
- Backup/restore
- Upgrade
- Housekeeping
- Troubleshooting
- Quy trình vận hành
- Mô hình Central Monitoring cho doanh nghiệp lớn

> Tài liệu sử dụng mô hình Zabbix Server + PostgreSQL + Zabbix Agent 2. Các hostname, IP, port sử dụng placeholder để có thể áp dụng cho nhiều môi trường.

---

# 2. Kiến trúc tổng thể

## 2.1. Zabbix cơ bản

```text
                         Zabbix Web
                             │
                             │
                             ▼
                    ┌─────────────────┐
                    │  Zabbix Server  │
                    └────────┬────────┘
                             │
                     ┌───────┴───────┐
                     │               │
                     ▼               ▼
                PostgreSQL       Zabbix Proxy
                                     │
                                     ▼
                              Remote Network
```

Zabbix Server thực hiện:

- Thu thập dữ liệu.
- Xử lý item.
- Đánh giá trigger.
- Thực hiện discovery.
- Xử lý event.
- Gửi action/notification.
- Lưu trạng thái monitoring.

Database lưu:

- Configuration.
- History.
- Trends.
- Events.
- Problems.
- Users.
- Templates.
- Hosts.
- Items.
- Triggers.

---

# 3. Mô hình monitoring

## 3.1. Agent monitoring

```text
┌──────────────────────┐
│    Zabbix Server     │
│                      │
│  172.16.x.x          │
└──────────┬───────────┘
           │
           │ TCP 10050
           ▼
┌──────────────────────┐
│    Zabbix Agent 2    │
│                      │
│      Server          │
└──────────────────────┘
```

## 3.2. SNMP monitoring

```text
┌──────────────────────┐
│    Zabbix Server     │
└──────────┬───────────┘
           │
           │ UDP 161
           ▼
┌──────────────────────┐
│ Switch / Router /    │
│ Firewall / Device    │
└──────────────────────┘
```

## 3.3. Zabbix Proxy

Với mạng phân tán:

```text
                     Zabbix Server
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
         Proxy A        Proxy B        Proxy C
            │              │              │
       Network A       Network B       Network C
            │              │              │
         Servers        Servers         Devices
```

Proxy phù hợp khi:

- Có nhiều site.
- Network giữa site và Zabbix Server không ổn định.
- Có firewall giữa các vùng.
- Muốn giảm traffic trực tiếp về Zabbix Server.
- Cần buffer dữ liệu khi Zabbix Server tạm thời unavailable.

---

# 4. Thành phần chính

| Thành phần | Vai trò |
|---|---|
| Zabbix Server | Core monitoring |
| Zabbix Frontend | Web UI |
| PostgreSQL | Database |
| Zabbix Agent 2 | Monitor server |
| Zabbix Proxy | Thu thập dữ liệu từ remote site |
| SNMP | Monitor network/device |
| Zabbix Sender | Push dữ liệu |
| Zabbix API | Automation/integration |

---

# 5. Port thường sử dụng

| Port | Protocol | Thành phần |
|---|---|---|
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |
| 10050 | TCP | Zabbix Agent |
| 10051 | TCP | Zabbix Server/Trap/Proxy |
| 161 | UDP | SNMP |
| 162 | UDP | SNMP Trap |
| 5432 | TCP | PostgreSQL |

Kiểm tra port:

```bash
ss -lntup
```

---

# 6. Yêu cầu hệ thống

## 6.1. Zabbix Server

Ví dụ môi trường nhỏ/trung bình:

| Thành phần | Khuyến nghị |
|---|---|
| OS | Ubuntu 22.04/24.04 |
| CPU | >= 4 vCPU |
| RAM | >= 8 GB |
| Disk | SSD |
| Database | PostgreSQL |
| Web | Nginx/Apache |
| Network | Stable |

Môi trường Production phải sizing theo:

- Số host.
- Số item.
- Update interval.
- Số trigger.
- History retention.
- Trend retention.
- Discovery.
- SNMP.
- Number of events.
- Number of concurrent checks.

Không nên sizing chỉ dựa trên số lượng server.

---

# 7. Chuẩn bị OS

Update:

```bash
sudo apt update
sudo apt upgrade -y
```

Kiểm tra:

```bash
hostnamectl
```

```bash
free -h
```

```bash
df -h
```

Kiểm tra thời gian:

```bash
timedatectl
```

Set timezone:

```bash
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```

Kiểm tra:

```bash
timedatectl
```

---

# 8. PostgreSQL

## 8.1. Cài PostgreSQL

Ví dụ:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
```

Kiểm tra:

```bash
sudo systemctl status postgresql
```

Enable:

```bash
sudo systemctl enable postgresql
```

---

# 9. Tạo database cho Zabbix

Chuyển sang user postgres:

```bash
sudo -u postgres psql
```

Tạo database user:

```sql
CREATE USER zabbix WITH PASSWORD '<ZABBIX_DB_PASSWORD>';
```

Tạo database:

```sql
CREATE DATABASE zabbix
    OWNER zabbix
    ENCODING 'UTF8';
```

Thoát:

```sql
\q
```

Kiểm tra:

```bash
sudo -u postgres psql -l
```

---

# 10. Cấu hình PostgreSQL

Kiểm tra file:

```bash
sudo -u postgres psql -c "SHOW config_file;"
```

Kiểm tra:

```bash
sudo -u postgres psql -c "SHOW listen_addresses;"
```

Nếu Zabbix Server và PostgreSQL cùng server thì có thể chỉ bind localhost.

Nếu database nằm trên server riêng, cần cấu hình:

```text
listen_addresses
pg_hba.conf
firewall
```

Sau thay đổi:

```bash
sudo systemctl restart postgresql
```

---

# 11. Cài Zabbix Repository

Sử dụng repository tương ứng với phiên bản Zabbix và OS đang triển khai.

Ví dụ với Zabbix 7.2 trên Ubuntu, tải package repository phù hợp từ Zabbix.

Sau khi cài repository:

```bash
sudo apt update
```

Kiểm tra package:

```bash
apt policy zabbix-server-pgsql
```

```bash
apt policy zabbix-agent2
```

> Production nên pin/version-control package thay vì upgrade tùy ý.

---

# 12. Cài Zabbix Server

Cài các package:

```bash
sudo apt install -y \
    zabbix-server-pgsql \
    zabbix-frontend-php \
    zabbix-nginx-conf \
    zabbix-sql-scripts \
    zabbix-agent2
```

Kiểm tra:

```bash
dpkg -l | grep zabbix
```

---

# 13. Import Database Schema

Tùy package/version, schema nằm trong package Zabbix.

Kiểm tra:

```bash
dpkg -L zabbix-sql-scripts | grep postgresql
```

Import schema theo hướng dẫn của version Zabbix đang cài.

Ví dụ dạng:

```bash
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz \
    | sudo -u postgres psql zabbix
```

Nếu database user không phải `postgres`, có thể import bằng user `zabbix`:

```bash
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz \
    | PGPASSWORD='<ZABBIX_DB_PASSWORD>' \
      psql -h <DB_HOST> -U zabbix -d zabbix
```

Kiểm tra table:

```bash
sudo -u postgres psql zabbix
```

```sql
\dt
```

---

# 14. Cấu hình Zabbix Server

File:

```text
/etc/zabbix/zabbix_server.conf
```

Backup trước khi sửa:

```bash
sudo cp \
    /etc/zabbix/zabbix_server.conf \
    /etc/zabbix/zabbix_server.conf.bak
```

Các tham số quan trọng:

```ini
DBHost=<DB_HOST>
DBName=zabbix
DBUser=zabbix
DBPassword=<ZABBIX_DB_PASSWORD>
```

Port mặc định:

```ini
ListenPort=10051
```

---

# 15. Cache và Worker

Zabbix Server có nhiều process xử lý khác nhau.

Một số tham số quan trọng:

```ini
CacheSize=256M
HistoryCacheSize=128M
HistoryIndexCacheSize=64M
TrendCacheSize=64M
ValueCacheSize=256M
```

Các giá trị trên chỉ là ví dụ.

Không copy nguyên xi vào Production.

Cần sizing dựa trên:

- Number of items.
- History.
- Trends.
- Pollers.
- Cache usage.
- Queue.
- RAM.

---

# 16. Kiểm tra cấu hình Zabbix Server

Sau khi chỉnh config:

```bash
sudo zabbix_server -c /etc/zabbix/zabbix_server.conf -T
```

Nếu version/package không hỗ trợ option trên, kiểm tra bằng:

```bash
zabbix_server --help
```

---

# 17. Start Zabbix Server

```bash
sudo systemctl enable zabbix-server
```

```bash
sudo systemctl start zabbix-server
```

Kiểm tra:

```bash
sudo systemctl status zabbix-server
```

Nếu lỗi:

```bash
sudo journalctl -u zabbix-server -n 200 --no-pager
```

---

# 18. Cấu hình Frontend

Nếu sử dụng Nginx, kiểm tra:

```text
/etc/zabbix/nginx.conf
```

Cấu hình:

```nginx
server {
    listen 80;
    server_name <ZABBIX_HOST_NAME>;

    root /usr/share/zabbix;

    index index.php;
}
```

Restart:

```bash
sudo systemctl restart nginx
```

Kiểm tra:

```bash
sudo systemctl status nginx
```

---

# 19. Truy cập Zabbix Web

Truy cập:

```text
http://<ZABBIX_HOST_NAME>
```

Hoặc:

```text
http://<ZABBIX_IP>
```

Production nên sử dụng:

```text
https://<ZABBIX_HOST_NAME>
```

với TLS.

---

# 20. Kiểm tra Zabbix Server từ Frontend

Sau khi login:

```text
Reports / System information
```

hoặc các khu vực tương ứng tùy version.

Kiểm tra:

```text
Zabbix Server:
Running

Database:
OK

Required server:
OK
```

---

# 21. Cài Zabbix Agent 2

Trên server cần monitor:

```bash
sudo apt update
sudo apt install -y zabbix-agent2
```

Kiểm tra:

```bash
zabbix_agent2 --version
```

---

# 22. Cấu hình Agent 2

File:

```text
/etc/zabbix/zabbix_agent2.conf
```

Backup:

```bash
sudo cp \
    /etc/zabbix/zabbix_agent2.conf \
    /etc/zabbix/zabbix_agent2.conf.bak
```

Các tham số quan trọng:

```ini
Server=<ZABBIX_SERVER_IP>
ServerActive=<ZABBIX_SERVER_IP>
Hostname=<HOST_NAME>
```

Ví dụ:

```ini
Server=172.16.x.x
ServerActive=172.16.x.x
Hostname=<HOST_NAME>
```

---

# 23. Passive và Active Check

## Passive

```text
Zabbix Server
      │
      │ request
      ▼
Agent :10050
```

Zabbix Server chủ động hỏi Agent.

## Active

```text
Agent
  │
  │ request/send
  ▼
Zabbix Server :10051
```

Agent chủ động gửi dữ liệu về Zabbix Server.

### So sánh

| | Passive | Active |
|---|---|---|
| Connection | Server → Agent | Agent → Server |
| Port Agent | 10050 | Không cần server vào 10050 |
| Firewall | Cần allow Server → Agent | Chỉ cần Agent → Server |
| Phù hợp | Network đơn giản | Network phân tán |

---

# 24. Start Agent 2

```bash
sudo systemctl enable zabbix-agent2
```

```bash
sudo systemctl start zabbix-agent2
```

Kiểm tra:

```bash
sudo systemctl status zabbix-agent2
```

Log:

```bash
sudo journalctl -u zabbix-agent2 -n 100 --no-pager
```

---

# 25. Kiểm tra Agent Port

```bash
ss -lntp | grep 10050
```

Expected:

```text
LISTEN ... :10050
```

Test từ Zabbix Server:

```bash
nc -zv <HOST_NAME> 10050
```

---

# 26. Kiểm tra Agent bằng zabbix_get

Trên Zabbix Server:

```bash
sudo apt install -y zabbix-get
```

Test:

```bash
zabbix_get \
    -s <HOST_NAME> \
    -k agent.ping
```

Kết quả:

```text
1
```

Có nghĩa Agent phản hồi.

Test hostname:

```bash
zabbix_get \
    -s <HOST_NAME> \
    -k system.hostname
```

---

# 27. Add Host trên Web UI

Vào:

```text
Data collection
    ↓
Hosts
    ↓
Create host
```

Nhập:

```text
Host name:
<HOST_NAME>
```

Chọn Host group:

```text
Linux servers
```

Interface:

```text
Agent
IP:
<SERVER_IP>

Port:
10050
```

Sau đó gắn Template.

---

# 28. Template

Template là tập hợp cấu hình monitoring có thể tái sử dụng.

Một template có thể chứa:

```text
Template
├── Items
├── Triggers
├── Discovery
├── Graphs
├── Value maps
└── Macros
```

Ví dụ:

```text
Linux server
    │
    ├── CPU
    ├── Memory
    ├── Disk
    ├── Network
    ├── Process
    └── Filesystem
```

Không nên tạo từng item thủ công nếu đã có template phù hợp.

---

# 29. Add Template cho Linux Server

Trong Host:

```text
Templates
    ↓
Link new templates
```

Chọn template Linux phù hợp với version Zabbix đang sử dụng.

Sau khi add:

```text
Host
   │
   └── Template
          │
          ├── Items
          ├── Triggers
          └── Discovery
```

---

# 30. Item

Item là thành phần thu thập một metric hoặc giá trị.

Ví dụ:

```text
system.cpu.util
vm.memory.size
vfs.fs.size
net.if.in
net.if.out
agent.ping
```

Một item thường có:

```text
Name
Key
Type
Update interval
History
Trend
Units
```

Ví dụ:

```text
Name:
CPU utilization

Key:
system.cpu.util

Update interval:
60s

Units:
%
```

---

# 31. Item Type

Một số loại:

| Type | Mục đích |
|---|---|
| Zabbix agent | Agent passive |
| Zabbix agent (active) | Agent active |
| SNMP agent | SNMP |
| HTTP agent | HTTP/API |
| Simple check | Ping/TCP |
| Zabbix trapper | Nhận dữ liệu push |
| Dependent item | Phân tích dữ liệu từ item khác |
| Calculated | Tính toán từ item |

---

# 32. Trigger

Trigger xác định khi nào một metric trở thành vấn đề.

Ví dụ:

```text
CPU > 90%
```

Trigger:

```text
CPU utilization is too high
```

Logic:

```text
Item
  │
  │ CPU = 95%
  ▼
Trigger
  │
  │ expression = TRUE
  ▼
Problem
```

---

# 33. Severity

Nên chuẩn hóa severity.

Ví dụ:

```text
Not classified
Information
Warning
Average
High
Disaster
```

Có thể mapping nội bộ:

```text
Warning   → Theo dõi
Average   → Cần xử lý
High      → Ưu tiên cao
Disaster  → Critical / Incident
```

Không nên đặt tất cả trigger thành High/Disaster vì sẽ tạo alert fatigue.

---

# 34. Ví dụ Trigger CPU

Ví dụ logic:

```text
CPU utilization > 90% trong 5 phút
```

Ý tưởng:

```text
CPU > 90%
   │
   ├── 30s → chưa alert
   ├── 60s → chưa alert
   ├── 180s → chưa alert
   └── 300s → Problem
```

Mục tiêu là tránh cảnh báo do CPU spike ngắn.

---

# 35. Disk Monitoring

Disk là một trong những monitoring quan trọng nhất.

Ví dụ:

```text
Disk usage > 80%
```

Severity:

```text
Warning
```

```text
Disk usage > 90%
```

Severity:

```text
High
```

```text
Disk usage > 95%
```

Severity:

```text
Disaster
```

Nhưng threshold phải phụ thuộc:

- Disk size.
- Application.
- Log growth.
- Database.
- Backup.
- WAL.
- Business criticality.

---

# 36. Memory Monitoring

Có thể monitor:

```text
Memory utilization
Available memory
Swap
```

Không nên chỉ nhìn:

```text
used memory
```

vì Linux sử dụng RAM cho:

- Page cache.
- Buffer.
- Kernel.
- Application.

Nên xem available memory và xu hướng sử dụng.

---

# 37. Network Monitoring

Các metric thường dùng:

```text
net.if.in
net.if.out
```

Theo dõi:

- Traffic.
- Errors.
- Drops.
- Interface status.
- Utilization.

Đối với network device nên ưu tiên SNMP.

---

# 38. Process Monitoring

Có thể monitor process quan trọng:

```text
postgres
nginx
haproxy
docker
patroni
```

Ví dụ:

```text
Process postgres không tồn tại
        ↓
Trigger
        ↓
High
        ↓
Notification
```

Tuy nhiên process tồn tại không có nghĩa service healthy.

Ví dụ:

```text
postgres process = running
```

nhưng:

```text
Database query = failed
```

Nên kết hợp nhiều lớp monitoring.

---

# 39. HTTP Monitoring

Sử dụng HTTP agent khi cần kiểm tra:

```text
https://<HOST_NAME>/health
```

Có thể kiểm tra:

- Status code.
- Response time.
- Content.
- JSON.
- Header.
- SSL certificate.

Mô hình:

```text
Zabbix Server
      │
      │ HTTP
      ▼
Application
      │
      ▼
/health
```

---

# 40. Database Monitoring

Ví dụ PostgreSQL.

Không nên chỉ monitor:

```text
TCP 5432
```

Nên monitor thêm:

```text
Database availability
Connections
Active sessions
Long-running queries
Locks
Replication
WAL
Disk
Transaction rate
Cache
```

Mô hình:

```text
                   PostgreSQL
                       │
       ┌───────────────┼────────────────┐
       │               │                │
       ▼               ▼                ▼
 Availability        Metrics          Replication
       │               │                │
     5432          Connections        Lag/WAL
```

---

# 41. PostgreSQL Monitoring qua Zabbix

Có thể sử dụng:

- Zabbix Agent.
- PostgreSQL plugin.
- UserParameter.
- Script.
- ODBC.
- Custom monitoring.

Ví dụ custom check:

```bash
psql -h <DB_HOST> \
     -U <DB_USER> \
     -d <DB_NAME> \
     -c "SELECT 1;"
```

Không nên hard-code password trong script.

Có thể sử dụng:

```text
.pgpass
```

với permission phù hợp hoặc cơ chế credential management của hệ thống.

---

# 42. SNMP Monitoring

Dùng cho:

- Switch.
- Router.
- Firewall.
- Printer.
- UPS.
- Network appliance.

Mô hình:

```text
Zabbix Server
      │
      │ UDP 161
      ▼
Network Device
```

Cấu hình trên device:

```text
SNMP version:
v2c / v3

Community:
<COMMUNITY>
```

Hoặc ưu tiên SNMPv3 nếu thiết bị hỗ trợ.

---

# 43. SNMP Test

Cài tool:

```bash
sudo apt install -y snmp
```

Test:

```bash
snmpwalk \
    -v2c \
    -c <COMMUNITY> \
    <DEVICE_IP>
```

Nếu SNMPv3:

```bash
snmpwalk \
    -v3 \
    -u <SNMP_USER> \
    -l authPriv \
    -a <AUTH_PROTOCOL> \
    -A '<AUTH_PASSWORD>' \
    -x <PRIV_PROTOCOL> \
    -X '<PRIV_PASSWORD>' \
    <DEVICE_IP>
```

---

# 44. Discovery

Discovery giúp tự động phát hiện:

- Interface.
- Filesystem.
- Process.
- Network interface.
- SNMP interface.
- Database objects.

Ví dụ:

```text
Server
  │
  ├── eth0
  ├── eth1
  ├── lo
  └── docker0
```

Discovery có thể tự động tạo monitoring cho interface phù hợp.

---

# 45. Low-Level Discovery

LLD có mô hình:

```text
Discovery Rule
      │
      ▼
Find objects
      │
      ├── Object 1
      ├── Object 2
      └── Object 3
             │
             ▼
        Item prototype
             │
             ▼
        Trigger prototype
```

Ví dụ filesystem:

```text
/
 /var
 /data
 /backup
```

LLD tự động tạo item cho từng filesystem.

---

# 46. Macro

Macro giúp template dùng được cho nhiều host.

Ví dụ:

```text
{$DISK.THRESHOLD}=80
```

Host A:

```text
{$DISK.THRESHOLD}=80
```

Host B:

```text
{$DISK.THRESHOLD}=90
```

Không cần clone template.

---

# 47. User và Permission

Không nên dùng một tài khoản admin chung.

Nên phân quyền:

```text
Zabbix Admin
     │
     ├── Full configuration
     └── User management

Monitoring Team
     │
     ├── View
     ├── Acknowledge
     └── Problem management

Application Team
     │
     └── View selected groups
```

Có thể tổ chức theo:

```text
User
  ↓
User group
  ↓
Role / Permissions
  ↓
Host groups
```

---

# 48. Host Group

Nên chuẩn hóa Host Group.

Ví dụ:

```text
Production
├── Linux
├── Windows
├── Database
├── Network
├── Security
└── Application
```

Hoặc theo team:

```text
Production
├── QTHT
├── DBA
├── Network
└── Application
```

Không nên tạo quá nhiều group trùng ý nghĩa.

---

# 49. Action

Action dùng để phản ứng khi có event.

Mô hình:

```text
Trigger
   │
   ▼
Problem
   │
   ▼
Event
   │
   ▼
Action
   │
   ├── Send notification
   ├── Execute script
   └── Webhook
```

Ví dụ:

```text
IF:
Severity >= High

AND:
Host group = Production

THEN:
Send Telegram
```

---

# 50. Notification

Có thể tích hợp:

- Email.
- Telegram.
- Webhook.
- Slack.
- Các hệ thống incident/alerting.

Trong mô hình tập trung:

```text
Zabbix
   │
   ▼
Webhook / Alerta
   │
   ├── Telegram
   ├── Email
   └── Incident system
```

Nên tránh để mỗi team tự cấu hình một kiểu notification.

---

# 51. Acknowledge Problem

Khi xử lý incident:

```text
Problem
   │
   ▼
Acknowledge
   │
   ├── Comment
   ├── Assign
   └── Update
```

Acknowledge không đồng nghĩa problem đã resolved.

Ví dụ:

```text
Problem:
Disk > 90%

Operator:
Acknowledge

Status:
Still Problem
```

Khi disk giảm:

```text
Problem
   ↓
Resolved
```

---

# 52. Queue

Queue giúp phát hiện Zabbix Server không xử lý kịp item.

Kiểm tra trên frontend:

```text
Administration
    ↓
Queue
```

Nếu queue tăng:

```text
Queue
  │
  ├── 0-5s
  ├── 5-10s
  ├── 10-30s
  └── >10m
```

Có item nằm lâu trong queue có thể cho thấy:

- Poller thiếu.
- Database chậm.
- Network chậm.
- Server quá tải.
- Timeout.
- Discovery quá nhiều.
- Item quá dày.

---

# 53. Zabbix Server Processes

Một số process quan trọng:

```text
poller
unreachable poller
trapper
preprocessor
history syncer
alerter
discoverer
housekeeper
timer
```

Không nên chỉ nhìn CPU/RAM.

Cần xem:

```text
Queue
Process busy %
Cache usage
Database performance
```

---

# 54. Database Performance

Zabbix database có thể trở thành bottleneck.

Theo dõi:

```text
CPU
RAM
IOPS
Latency
Connections
Locks
Cache
Queries
Table size
Autovacuum
Bloat
```

PostgreSQL:

```text
pg_stat_activity
pg_stat_database
pg_stat_bgwriter
pg_stat_wal
```

Đặc biệt quan trọng khi Zabbix có:

```text
Thousands of hosts
Hundreds of thousands of items
High-frequency checks
Long history retention
```

---

# 55. History và Trends

Zabbix lưu dữ liệu theo hai dạng chính:

```text
History
  ↓
Raw data

Trends
  ↓
Aggregated data
```

History phù hợp:

```text
Chi tiết
Ngắn hạn
Troubleshooting
```

Trends phù hợp:

```text
Dài hạn
Capacity planning
Trend analysis
```

Không nên giữ history quá dài nếu không có yêu cầu nghiệp vụ vì database sẽ tăng rất nhanh.

---

# 56. Housekeeping

Housekeeping dọn dữ liệu cũ:

```text
History
Trends
Events
Problems
Audit
```

Cần thiết kế retention phù hợp.

Ví dụ:

```text
History:
7-30 days

Trends:
180-365 days
```

Đây chỉ là ví dụ.

Retention thực tế phụ thuộc:

- Compliance.
- Capacity.
- Troubleshooting requirement.
- Database size.
- Backup requirement.

---

# 57. Backup Zabbix Database

Không chỉ backup config.

Database chứa phần lớn cấu hình và dữ liệu quan trọng.

PostgreSQL backup:

```bash
pg_dump \
    -h <DB_HOST> \
    -U zabbix \
    -d zabbix \
    -Fc \
    -f /backup/zabbix_$(date +%Y%m%d_%H%M%S).dump
```

Ví dụ:

```text
/backup/
└── zabbix_20261006_020000.dump
```

---

# 58. Restore Database

Tạo database mới hoặc chuẩn bị database restore.

Ví dụ:

```bash
pg_restore \
    -h <DB_HOST> \
    -U zabbix \
    -d zabbix \
    /backup/<BACKUP_FILE>.dump
```

Tùy phương án restore có thể cần:

```text
DROP DATABASE
CREATE DATABASE
OWNER
EXTENSION
PERMISSION
```

Trước khi restore Production:

- Xác định RPO.
- Xác định RTO.
- Backup database hiện tại.
- Kiểm tra version compatibility.
- Test restore trên môi trường độc lập.

---

# 59. Backup Configuration

Ngoài database, nên backup:

```text
/etc/zabbix/
/etc/nginx/
/etc/postgresql/
```

Ví dụ:

```bash
sudo tar -czf \
    /backup/zabbix-config-$(date +%Y%m%d).tar.gz \
    /etc/zabbix \
    /etc/nginx
```

Nếu có custom script:

```text
/usr/lib/zabbix/
/usr/local/bin/
/opt/zabbix/
```

cũng cần đưa vào backup nếu hệ thống sử dụng.

---

# 60. Upgrade Zabbix

Quy trình:

```text
Review version
      ↓
Backup DB
      ↓
Backup config
      ↓
Read release notes
      ↓
Test
      ↓
Upgrade
      ↓
Database migration
      ↓
Restart services
      ↓
Validate
```

Không nên:

```text
apt upgrade
```

trực tiếp trên Production mà không backup và không kiểm tra compatibility.

---

# 61. Validate sau Upgrade

Kiểm tra:

```bash
systemctl status zabbix-server
```

```bash
systemctl status zabbix-agent2
```

```bash
systemctl status nginx
```

Database:

```bash
systemctl status postgresql
```

Log:

```bash
journalctl -u zabbix-server -n 200 --no-pager
```

Frontend:

```bash
curl -I http://127.0.0.1
```

Sau đó kiểm tra Web UI:

```text
Hosts
Items
Problems
Graphs
Latest data
Administration
```

---

# 62. Troubleshooting – Agent không hoạt động

## Bước 1

```bash
systemctl status zabbix-agent2
```

## Bước 2

```bash
journalctl -u zabbix-agent2 -n 200 --no-pager
```

## Bước 3

```bash
ss -lntp | grep 10050
```

## Bước 4

Từ Zabbix Server:

```bash
nc -zv <HOST_NAME> 10050
```

## Bước 5

Test:

```bash
zabbix_get -s <HOST_NAME> -k agent.ping
```

Nếu fail, kiểm tra:

```text
Agent process
    ↓
Listen port
    ↓
Firewall
    ↓
Server parameter
    ↓
Hostname
    ↓
Network
```

---

# 63. Troubleshooting – Agent ping OK nhưng Host vẫn lỗi

Có thể xảy ra:

```text
zabbix_get agent.ping
        ↓
        1
```

nhưng Web UI vẫn:

```text
ZBX unavailable
```

Kiểm tra:

```text
Host interface IP
Host name
Template
Item type
Allowed server IP
ServerActive
Server parameter
```

Đặc biệt với active agent:

```text
Hostname
```

phải khớp với host được cấu hình trên Zabbix Server theo cơ chế active checks.

---

# 64. Troubleshooting – Zabbix Server không start

Kiểm tra:

```bash
systemctl status zabbix-server
```

Log:

```bash
journalctl -u zabbix-server -n 200 --no-pager
```

Kiểm tra config:

```bash
grep -E \
'^(DBHost|DBName|DBUser|DBPassword|ListenPort)' \
/etc/zabbix/zabbix_server.conf
```

Kiểm tra database:

```bash
sudo -u postgres psql -d zabbix -c "SELECT 1;"
```

Kiểm tra port:

```bash
ss -lntp | grep 10051
```

---

# 65. Troubleshooting – Database connection failed

Kiểm tra PostgreSQL:

```bash
systemctl status postgresql
```

Test:

```bash
psql \
    -h <DB_HOST> \
    -U zabbix \
    -d zabbix
```

Kiểm tra:

```text
listen_addresses
pg_hba.conf
Firewall
DB username
DB password
Database name
Network
```

---

# 66. Troubleshooting – Queue tăng

Nếu Queue tăng liên tục:

```text
Queue
  ↓
High
```

Kiểm tra:

```text
1. Zabbix Server CPU
2. RAM
3. Database latency
4. Poller busy %
5. Preprocessor busy %
6. History syncer
7. Network
8. Item interval
9. Discovery
10. Number of hosts/items
```

Không nên chỉ tăng process ngay lập tức.

Cần xác định bottleneck trước.

---

# 67. Troubleshooting – Database quá lớn

Kiểm tra:

```sql
SELECT
    pg_size_pretty(pg_database_size('zabbix'));
```

Top table:

```sql
SELECT
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;
```

Kiểm tra retention:

```text
History
Trends
Events
Audit
```

Không nên xóa dữ liệu Zabbix trực tiếp bằng SQL nếu không hiểu schema và housekeeping.

---

# 68. Troubleshooting – Alert quá nhiều

Đây là vấn đề phổ biến trong monitoring.

Ví dụ:

```text
1000 alerts / hour
```

không có nghĩa monitoring tốt.

Có thể do:

- Threshold quá nhạy.
- Trigger không có hysteresis.
- Duplicate monitoring.
- Không có dependency.
- Severity sai.
- Notification sai.
- Monitor infrastructure thấp nhưng gửi Critical.
- Không suppress downstream alerts.

---

# 69. Dependency

Ví dụ:

```text
Core Switch DOWN
       │
       ├── Server A DOWN
       ├── Server B DOWN
       ├── Server C DOWN
       └── Application DOWN
```

Nếu không có dependency:

```text
1 incident
    ↓
100 alerts
```

Có dependency:

```text
Core Switch DOWN
       ↓
Root Problem
       ↓
Suppress downstream symptoms
```

Đây là một trong những thành phần quan trọng khi xây dựng monitoring cho doanh nghiệp lớn.

---

# 70. Alert Design

Một alert tốt nên trả lời:

```text
What?
Where?
When?
Severity?
Owner?
Current value?
Threshold?
```

Ví dụ:

```text
[HIGH]
PROD-DB-01

Disk usage on /var/lib/postgresql
is above 90%.

Current: 93%
Threshold: 90%

Time: 2026-10-06 10:20
Owner: DBA
```

Alert không nên chỉ có:

```text
Problem on server
```

---

# 71. Naming Convention

Đề xuất:

```text
<ENV>-<SYSTEM>-<HOST>-<CHECK>
```

Ví dụ:

```text
PROD-PHBC-DB01-POSTGRES
PROD-PHBC-APP01-HTTP
PROD-QTHT-ZBX01-SYSTEM
PROD-NET-CORE01-SNMP
```

Host group:

```text
Production/Linux
Production/Database
Production/Network
Production/Application
```

---

# 72. Tagging

Nên dùng tag:

```text
environment=Production
team=QTHT
service=PostgreSQL
system=PHBC
criticality=Critical
owner=DBA
```

Tag giúp:

- Action.
- Notification.
- Filtering.
- Dashboard.
- Correlation.
- Phân quyền.

---

# 73. Monitoring Standard

Một server Production có thể có:

```text
Availability
├── Agent
├── Ping
└── Application

System
├── CPU
├── Memory
├── Disk
├── Network
└── Process

Application
├── HTTP
├── Port
└── Health

Database
├── Connection
├── Sessions
├── Query
├── Replication
└── Storage
```

Không phải server nào cũng cần toàn bộ item.

Cần xác định baseline theo service.

---

# 74. Monitoring theo Layer

## Layer 1 – Infrastructure

```text
Ping
CPU
RAM
Disk
Network
```

## Layer 2 – OS

```text
Process
Filesystem
Service
System load
```

## Layer 3 – Middleware

```text
Nginx
HAProxy
Redis
Kafka
RabbitMQ
```

## Layer 4 – Database

```text
PostgreSQL
MariaDB
SQL Server
Oracle
```

## Layer 5 – Application

```text
HTTP
API
Health check
Response time
Business metric
```

## Layer 6 – Business

```text
Transaction
Order
Payment
Request
Success rate
```

---

# 75. Central Monitoring Architecture

Đối với doanh nghiệp lớn:

```text
                         CENTRAL MONITORING
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
      Zabbix Server          Prometheus             Uptime Kuma
          │                       │                       │
          │                       │                       │
          ▼                       ▼                       ▼
      Infrastructure            Metrics              Availability
      Server/Network          Application            HTTP/TCP/Ping
          │                       │                       │
          └───────────────────────┼───────────────────────┘
                                  ▼
                           Alert / Incident
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
                 Alerta       Telegram        Email
```

---

# 76. Khi nào dùng Zabbix và Uptime Kuma?

| Bài toán | Uptime Kuma | Zabbix |
|---|---:|---:|
| Ping | Có | Có |
| TCP | Có | Có |
| HTTP | Có | Có |
| CPU | Không phù hợp | Có |
| RAM | Không phù hợp | Có |
| Disk | Cơ bản | Có |
| SNMP | Hạn chế | Có |
| Network device | Hạn chế | Có |
| Database metrics | Hạn chế | Có |
| Discovery | Hạn chế | Có |
| Dependency | Hạn chế | Có |
| Capacity planning | Hạn chế | Có |
| Large-scale monitoring | Không phải mục tiêu chính | Phù hợp |
| Simple uptime | Rất phù hợp | Có |

---

# 77. Backup Strategy

Zabbix Production nên có:

```text
Zabbix Database
       │
       ├── Daily backup
       ├── WAL / PITR nếu yêu cầu
       └── Offsite copy

Zabbix Configuration
       │
       └── Git / Backup

Custom Scripts
       │
       └── Git / Backup
```

Backup phải đáp ứng:

```text
RPO
RTO
Retention
Offsite
Restore Test
```

Backup thành công không đồng nghĩa restore chắc chắn thành công.

Phải test restore.

---

# 78. Daily Checklist

- [ ] Zabbix Server UP.
- [ ] PostgreSQL UP.
- [ ] Frontend UP.
- [ ] Agent errors.
- [ ] Queue.
- [ ] Problems.
- [ ] High/Disaster alerts.
- [ ] Database disk.
- [ ] Zabbix server disk.
- [ ] Notification.
- [ ] Backup status.

Commands:

```bash
systemctl status zabbix-server
```

```bash
systemctl status zabbix-agent2
```

```bash
systemctl status postgresql
```

```bash
df -h
```

---

# 79. Weekly Checklist

- [ ] Review unresolved problems.
- [ ] Review noisy triggers.
- [ ] Review false positives.
- [ ] Review queue.
- [ ] Review database growth.
- [ ] Review top largest tables.
- [ ] Review host availability.
- [ ] Review discovery.
- [ ] Verify backup.
- [ ] Test notification.
- [ ] Review disabled items.
- [ ] Review unsupported items.

---

# 80. Monthly Checklist

- [ ] Test database restore.
- [ ] Review retention.
- [ ] Review database size.
- [ ] Review Zabbix Server capacity.
- [ ] Review CPU/RAM.
- [ ] Review queue trend.
- [ ] Review templates.
- [ ] Review unused hosts.
- [ ] Review unused users.
- [ ] Review permissions.
- [ ] Review notification rules.
- [ ] Review version.
- [ ] Review security.

---

# 81. Security Checklist

- [ ] HTTPS cho Zabbix Frontend.
- [ ] Restrict Web UI access.
- [ ] Không dùng shared admin account.
- [ ] Password mạnh.
- [ ] RBAC.
- [ ] Giới hạn Agent `Server`.
- [ ] Không mở TCP 10050 toàn Internet.
- [ ] Giới hạn TCP 10051.
- [ ] SNMPv3 nếu có thể.
- [ ] Không hard-code database password trong script.
- [ ] Backup được bảo vệ.
- [ ] Kiểm soát quyền file config.
- [ ] Patch OS.
- [ ] Patch Zabbix.
- [ ] Review account định kỳ.

---

# 82. Quick Recovery Runbook

Khi Zabbix Server có vấn đề:

```text
1. Check Server
      ↓
2. Check Disk
      ↓
3. Check PostgreSQL
      ↓
4. Check Zabbix Server
      ↓
5. Check Frontend
      ↓
6. Check Logs
      ↓
7. Check Port 10051
      ↓
8. Check Queue
      ↓
9. Check Agents/Proxy
      ↓
10. Validate Alerts
```

Commands:

```bash
hostnamectl
```

```bash
df -h
```

```bash
systemctl status postgresql
```

```bash
systemctl status zabbix-server
```

```bash
systemctl status nginx
```

```bash
journalctl -u zabbix-server -n 200 --no-pager
```

```bash
ss -lntp | grep 10051
```

---

# 83. Các command vận hành thường dùng

## Zabbix Server

```bash
systemctl status zabbix-server
```

```bash
systemctl restart zabbix-server
```

```bash
journalctl -u zabbix-server -f
```

## Zabbix Agent 2

```bash
systemctl status zabbix-agent2
```

```bash
systemctl restart zabbix-agent2
```

```bash
journalctl -u zabbix-agent2 -f
```

## PostgreSQL

```bash
systemctl status postgresql
```

```bash
sudo -u postgres psql
```

## Nginx

```bash
systemctl status nginx
```

```bash
nginx -t
```

---

# 84. Incident Flow

Ví dụ:

```text
Zabbix:
PROD-DB-01 Disk > 90%
        │
        ▼
Problem
        │
        ▼
High Severity
        │
        ▼
Action
        │
        ▼
Alerta / Telegram
        │
        ▼
Operator ACK
        │
        ▼
RCA
        │
        ▼
Remediation
        │
        ▼
Metric normal
        │
        ▼
Resolved
```

---

# 85. Nguyên tắc xây dựng Zabbix Production

1. Không monitor mọi thứ một cách không kiểm soát.
2. Mỗi monitor phải có mục đích.
3. Chuẩn hóa host/template/tag.
4. Chuẩn hóa severity.
5. Có owner cho service.
6. Có dependency cho hệ thống lớn.
7. Giảm false positive.
8. Không biến mọi warning thành Critical.
9. Theo dõi queue và database.
10. Có retention policy.
11. Backup database.
12. Test restore.
13. Có RBAC.
14. Hạn chế access network.
15. Quản lý version.
16. Có quy trình upgrade/rollback.
17. Review monitoring định kỳ.

---

# 86. Kết luận

Zabbix phù hợp làm nền tảng monitoring tập trung cho doanh nghiệp có nhiều:

- Server.
- Network device.
- Database.
- Application.
- Middleware.
- VM.
- Container.
- Infrastructure.

Kiến trúc khuyến nghị:

```text
                         CENTRAL MONITORING
                                  │
             ┌────────────────────┼────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼
          Zabbix               Uptime Kuma          Logs/APM
             │                    │                    │
             ▼                    ▼                    ▼
        Infrastructure        Availability          Observability
        Metrics/SNMP          HTTP/TCP/Ping         Logs/Traces
             │                    │                    │
             └────────────────────┼────────────────────┘
                                  ▼
                            Alert Platform
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
                 Alerta        Telegram        Email
```

Zabbix nên đóng vai trò **monitoring platform trung tâm** cho infrastructure và metrics.

Uptime Kuma có thể bổ sung lớp **availability monitoring** cho các endpoint/service quan trọng.

Mục tiêu của hệ thống monitoring không phải là tạo thật nhiều alert, mà là:

```text
Detect
  ↓
Understand
  ↓
Alert đúng người
  ↓
Respond
  ↓
Resolve
  ↓
Analyze
  ↓
Prevent recurrence
```

Một hệ thống Zabbix Production tốt cần đồng thời đảm bảo:

- Monitoring coverage.
- Alert quality.
- Low false positive.
- Database performance.
- Scalability.
- Security.
- Backup/restore.
- Standardization.
- Ownership.
- Incident response.
