---
title: Prometheus 手册
date: 2024-03-14 22:30:59
tags:
  - Prometheus
  - 监控
  - PromQL
  - 可观测性
---
## Metrics 类型

Prometheus 指标以向量的形式存储在时序数据库中，各类型指标底层存储一致，但使用场景不同。

### Counter 只增不减的计数器

- `http_requests_total` - 服务器请求总数
- `node_cpu` - CPU 使用总时长

**约定**：Counter 类型指标建议以 `_total` 结尾。

```promql
// 计算 5 分钟内请求的变化速率（每秒平均请求数）
rate(http_requests_total[5m])

// 请求量最多的 10 个实例
topk(10, http_requests_total)
```

### Gauge 可增可减的仪表盘

适用于当前瞬时值，如内存、温度、连接数等。

```promql
// 当前 node 空闲内存
node_memory_MemFree_bytes
```

**常用函数**：

```promql
// 返回一段时间内的变化量
delta(cpu_temp_celsius{host="zeus"}[2h])

// 线性预测：根据 1h 内的变化趋势，预测 4h 后的文件占用
predict_linear(node_filesystem_free_bytes{job="node"}[1h], 4 * 3600)
```

### Histogram 与 Summary 数据分布指标

时延等统计类指标易受长尾影响，单个异常值会拉高整体。Histogram 和 Summary 通过分桶/分位数直接呈现分布。

| 特性 | Histogram | Summary |
|------|-----------|---------|
| 分位数 | 服务端聚合，可跨实例 | 客户端计算，不可跨实例 |
| 桶边界 | 可自定义 | 固定 quantile |
| 适用场景 | 需要跨实例聚合（如 P99） | 单实例、对精度要求高 |

**Summary 示例**（Prometheus 自身 WAL fsync）：

```text
# HELP prometheus_tsdb_wal_fsync_duration_seconds Duration of WAL fsync.
# TYPE prometheus_tsdb_wal_fsync_duration_seconds summary
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.5"} 0.012352463
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.9"} 0.014458005
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.99"} 0.017316173
prometheus_tsdb_wal_fsync_duration_seconds_sum 2.888716127000002
prometheus_tsdb_wal_fsync_duration_seconds_count 216
```

**Histogram 示例**（分桶累计样本数）：

```text
# HELP prometheus_tsdb_compaction_chunk_range Final time range of chunks on their first compaction
# TYPE prometheus_tsdb_compaction_chunk_range histogram
prometheus_tsdb_compaction_chunk_range_bucket{le="100"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="+Inf"} 780
prometheus_tsdb_compaction_chunk_range_sum 1.1540798e+09
prometheus_tsdb_compaction_chunk_range_count 780
```

> Histogram 查询 P99：`histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))`

---

## PromQL

通过 metric name + labels 选定时间序列，再进行聚合与计算。

### 标签选择器

- `=` / `!=` 精确匹配
- `=~` / `!~` 正则匹配

```promql
// 单条时序
http_requests_total{code="200", handler="alerts"}

// 多环境、排除 GET
http_requests_total{environment=~"staging|testing|development", method!="GET"}
```

### 数学运算

```promql
// 字节转 MB
node_memory_MemFree_bytes / (1024 * 1024)

// 内存使用率超过 95% 的主机
(node_memory_MemTotal_bytes - node_memory_MemFree_bytes) / node_memory_MemTotal_bytes > 0.95
```

### 聚合操作

| 函数 | 含义 |
|------|------|
| `sum` / `min` / `max` / `avg` | 求和 / 最小 / 最大 / 平均 |
| `stddev` / `stdvar` | 标准差 / 方差 |
| `count` / `count_values` | 计数 / 按 value 计数 |
| `topk` / `bottomk` | 前 n / 后 n 条 |
| `quantile` | 分位数 |

```promql
sum(http_requests_total)
count_values("version", http_requests_total)
topk(5, http_requests_total)
quantile(0.5, http_requests_total)
```

### 内置函数

| 函数 | 说明 |
|------|------|
| `rate()` | 区间内每秒平均增长率，平滑、适合告警 |
| `irate()` | 最后两个样本的瞬时导数，灵敏、易抖动 |
| `increase()` | 区间内总增长量 |

```promql
// 等价：increase(x[2m])/120 ≈ rate(x[2m])
rate(node_cpu[2m])

// 瞬时速率，对瞬时尖刺更敏感
irate(node_cpu[2m])
```

> **选型**：告警用 `rate`，短时间粒度图用 `irate`。`irate` 在刮取间隔不规则时会失真。

---

## 黄金指标（Four Golden Signals）

Google SRE 总结的四大黄金信号：延迟、流量、错误、饱和度。

### 延迟 Latency

服务请求所需时间，用 Histogram 记录。

- 区分成功/失败请求的延迟：HTTP 500 可能很快返回，混入会拉低实际体感
- 微服务中“慢失败”比“快失败”更危险，需单独追踪慢错误延迟

### 流量 Traffic

系统负载，衡量容量需求。如 HTTP API 的 RPS。

```promql
sum(rate(http_requests_total[5m]))
```

### 错误 Errors

失败请求速率，通过 `code` 等 label 过滤。

- 显式：HTTP 5xx、连接超时
- 隐式：HTTP 200 但业务失败，需在应用层打点

### 饱和度 Saturation

资源瓶颈程度。内存型服务看内存，I/O 型看磁盘/网络。

- 用 `predict_linear` 做容量预测，例如：“磁盘是否可能在 4 小时后写满”
