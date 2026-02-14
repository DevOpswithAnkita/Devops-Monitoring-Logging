# Log Aggregation Stack Setup Guide

A comprehensive guide for setting up a log aggregation stack using Grafana, Loki, and Promtail on Debian/Ubuntu systems.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Components](#components)
- [Installation](#installation)
  - [1. Grafana Installation](#1-grafana-installation)
  - [2. Loki and Promtail Setup](#2-loki-and-promtail-setup)
- [Verification](#verification)
- [Useful LogQL Queries](#useful-logql-queries)
- [Troubleshooting](#troubleshooting)

## Overview

This log aggregation stack provides:
- **Grafana**: Visualization and dashboarding for logs
- **Loki**: Log aggregation and storage system
- **Promtail**: Log shipping agent that sends logs to Loki

## Prerequisites

- Debian or Ubuntu operating system
- Docker installed
- Root or sudo access
- Port availability: 3000 (Grafana), 3100 (Loki)

## Components

### Grafana
Open-source platform for monitoring and observability with rich visualization capabilities for exploring and analyzing logs.

### Loki
Horizontally scalable, highly available log aggregation system designed to store and query logs from all your applications and infrastructure.

### Promtail
Agent that ships local logs to a Loki instance. It discovers targets, attaches labels to log streams, and pushes them to Loki.

## Installation

### 1. Grafana Installation

#### Install Dependencies

```bash
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
```

#### Add Grafana GPG Key

```bash
sudo wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
```

#### Add Repository

**For Stable Release:**
```bash
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
```

**For Beta Release:**
```bash
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com beta main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
```

#### Install Grafana

```bash
# Update package list
sudo apt-get update

# Install latest OSS release
sudo apt-get install grafana
```

#### Start Grafana Server

```bash
# Enable Grafana to start on boot
sudo systemctl enable grafana-server

# Start Grafana service
sudo systemctl start grafana-server

# Check status
sudo systemctl status grafana-server
```

**Access Grafana:**
- URL: `http://localhost:3000`
- Default credentials: `admin/admin`

---

### 2. Loki and Promtail Setup

#### Download Loki Configuration

```bash
cd /home/ubuntu
wget https://raw.githubusercontent.com/grafana/loki/v2.8.0/cmd/loki/loki-local-config.yaml -O loki-config.yaml
```

#### Run Loki Container

```bash
docker run -d \
  --name loki \
  -v /home/ubuntu/loki-config.yaml:/etc/loki/local-config.yaml \
  -p 3100:3100 \
  grafana/loki:2.8.0 \
  --config.file=/etc/loki/local-config.yaml
```

#### Download Promtail Configuration

```bash
wget https://raw.githubusercontent.com/grafana/loki/v2.8.0/clients/cmd/promtail/promtail-docker-config.yaml -O promtail-config.yaml
```

#### Run Promtail Container

```bash
docker run -d \
  --name promtail \
  -v $(pwd):/mnt/config \
  -v /var/log:/var/log \
  --link loki \
  grafana/promtail:2.8.0 \
  --config.file=/mnt/config/promtail-config.yaml
```

---

## Verification

### Check Container Status

```bash
docker ps
```

You should see containers for:
- loki
- promtail

### Access Web Interfaces

- **Grafana**: http://localhost:3000
- **Loki**: http://localhost:3100/ready

### Add Loki Data Source in Grafana

1. Login to Grafana (http://localhost:3000)
   - Default credentials: `admin/admin`
2. Go to **Configuration** → **Data Sources**
3. Click **Add data source**
4. Select **Loki**
5. Configure:
   - Name: `Loki`
   - URL: `http://loki:3100` (if using Docker) or `http://localhost:3100`
6. Click **Save & Test**

---

## Useful LogQL Queries

LogQL is Loki's query language, similar to PromQL but designed for logs.

### View All Logs

```logql
{job="varlogs"}
```

### Filter Logs by Container

```logql
{container="nginx"}
```

### Search for Specific Text

```logql
{job="varlogs"} |= "error"
```

### Exclude Specific Text

```logql
{job="varlogs"} != "debug"
```

### Case-Insensitive Search

```logql
{job="varlogs"} |~ "(?i)error"
```

### Count Log Lines per Minute

```logql
sum(rate({job="varlogs"}[1m]))
```

### Count Error Logs

```logql
sum(count_over_time({job="varlogs"} |= "error" [5m]))
```

### Parse JSON Logs

```logql
{job="varlogs"} | json | level="error"
```

### Multiple Filters

```logql
{container="nginx"} |= "error" != "timeout"
```

---

## Troubleshooting

### Grafana Not Starting

```bash
# Check logs
sudo journalctl -u grafana-server -f

# Verify service status
sudo systemctl status grafana-server

# Restart service
sudo systemctl restart grafana-server
```

### Loki Container Not Running

```bash
# Check container logs
docker logs loki

# Check if port is available
sudo lsof -i :3100

# Restart container
docker restart loki
```

### Promtail Container Not Running

```bash
# Check container logs
docker logs promtail

# Verify promtail can connect to Loki
docker exec promtail wget -O- http://loki:3100/ready

# Restart container
docker restart promtail
```

### No Logs Appearing in Grafana

1. **Check Promtail is running:**
   ```bash
   docker ps | grep promtail
   ```

2. **Verify Promtail configuration:**
   ```bash
   cat promtail-config.yaml
   ```

3. **Check log file paths exist:**
   ```bash
   ls -la /var/log
   ```

4. **Test Loki API:**
   ```bash
   curl http://localhost:3100/ready
   ```

5. **Check Grafana data source:**
   - Go to Grafana → Configuration → Data Sources
   - Test the Loki connection

### Port Already in Use

```bash
# Check what's using a port
sudo lsof -i :3000  # Grafana
sudo lsof -i :3100  # Loki

# Kill process if needed
sudo kill -9 <PID>
```

### Permission Issues with Log Files

```bash
# Give Promtail read access to logs
sudo chmod -R 755 /var/log

# Or run Promtail with appropriate user
docker run -d \
  --name promtail \
  --user root \
  -v $(pwd):/mnt/config \
  -v /var/log:/var/log \
  --link loki \
  grafana/promtail:2.8.0 \
  --config.file=/mnt/config/promtail-config.yaml
```

---

## Architecture Diagram

```
┌─────────────────┐
│    Grafana      │ ← Visualization & Dashboards
│    :3000        │
└────────┬────────┘
         │
         │ Queries logs
         │
┌────────▼────────┐
│      Loki       │ ← Log Aggregation & Storage
│     :3100       │
└────────▲────────┘
         │
         │ Ships logs
         │
┌────────┴────────┐
│   Promtail      │ ← Log Collection Agent
│                 │
└─────────────────┘
         │
         │ Reads from
         │
┌────────▼────────┐
│   /var/log/*    │ ← Application Logs
│   Container     │
│   System Logs   │
└─────────────────┘
```

---

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)

---
