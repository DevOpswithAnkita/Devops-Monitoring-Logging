# Prometheus Interview Guide

## Core Concepts

**Metrics**: Measurements or data points that indicate what is happening in a system (e.g., CPU usage, request count, memory consumption).

**Monitoring**: The continuous process of observing metrics over time to establish baselines, detect anomalies, and identify issues.

**Prometheus**: An open-source monitoring and alerting toolkit with a powerful query language (PromQL), designed for reliability and scalability in dynamic environments.

## Architecture Components

**Prometheus Server**: Core component that scrapes metrics, stores them in a time-series database (TSDB), and serves queries via HTTP API.

**Service Discovery**: Automatically identifies scrape targets in dynamic environments (Kubernetes, Consul, File-based configurations).

**Pushgateway**: Allows short-lived jobs to push metrics to Prometheus for later scraping.

**Alertmanager**: Handles alert deduplication, grouping, routing, and delivery to notification channels (Slack, email, PagerDuty).

**Exporters**: Bridge applications that expose metrics from third-party systems in Prometheus format (Node Exporter, MySQL Exporter, etc.).

**PromQL**: Prometheus Query Language for querying and aggregating time-series data.

**Grafana**: Visualization platform that integrates with Prometheus for creating dashboards and graphs.

## Key Features

- **Pull-based model**: Prometheus scrapes metrics from targets at regular intervals
- **Multi-dimensional data model**: Uses labels for flexible querying and aggregation
- **Local storage**: Efficient time-series database optimized for append-only writes
- **Service discovery**: Automatic target detection in cloud-native environments
- **Alerting**: Built-in alert evaluation and integration with Alertmanager

## Common Interview Questions

**Q: Why use Prometheus over other monitoring tools?**
A: Prometheus excels in cloud-native environments with its service discovery, powerful PromQL, dimensional data model, and Kubernetes integration.

**Q: What is the difference between push and pull monitoring?**
A: Prometheus uses pull-based scraping where it fetches metrics from targets, while push-based systems require applications to send metrics to the collector.

**Q: When would you use Pushgateway?**
A: For short-lived batch jobs that complete before Prometheus can scrape them, or for applications behind firewalls where pull isn't feasible.

**Q: How does Prometheus handle high availability?**
A: Run multiple Prometheus instances scraping the same targets, use Thanos or Cortex for long-term storage and global query view.

**Q: What are the retention limitations of Prometheus?**
A: Default local storage retention is 15 days; for longer retention, integrate with remote storage solutions like Thanos, Cortex, or cloud providers.