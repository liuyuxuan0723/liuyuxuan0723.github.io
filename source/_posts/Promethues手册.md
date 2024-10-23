---
title: Promethues手册
date: 2024-03-14 22:30:59
tags:
---

## Metrics类型

promethues指标以向量的形式存储在时序数据中，每种metrics的存储都是一样的，但使用场景存在一定差异



#### Counter 只增不减的计数器

- http_requests_total   服务器请求总数
- node_cpu  cpu使用总时长

一般counter类型的指标建议以 total结尾

通过内置的PromQL可以进一步的聚合这些数据

```PromQL
// 计算5m中内请求的变化速率，可以理解为截取5m中内的每秒的平均请求数
rate(http_requests_total[5m])
```

```
// 计算请求最多的是个服务器
topk(10, http_requests_total)
```



### Gauge 可增可减的仪表盘

```
// 当前node空闲的内存大小
node_memory_MemFree
```

- 对于Gauge，可以使用delta函数返回一段时间内的变化情况

```
delta(cpu_temp_celsius{host="zeus"}[2h])
// 回归函数，根据1h内的文件变化情况，预测4h后的文件占用情况
predict_linear(node_filesystem_free{job="node"}[1h], 4 * 3600)
```



### Histogram 与 Summary 数据分布指标

对于统计类的指标，可能会出现长尾问题，如时延指标，一个过高的请求可能会拉高整体的请求时长，所以有一种指标可以直接对所有的指标进行分桶统计

- Summary指标
  - 以下样本当前Prometheus Server进行wal_fsync操作的总次数为216次，耗时2.888716127000002s。其中中位数（quantile=0.5）的耗时为0.012352463，9分位数（quantile=0.9）的耗时为0.014458005s。

```
# HELP prometheus_tsdb_wal_fsync_duration_seconds Duration of WAL fsync.
# TYPE prometheus_tsdb_wal_fsync_duration_seconds summary
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.5"} 0.012352463
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.9"} 0.014458005
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.99"} 0.017316173
prometheus_tsdb_wal_fsync_duration_seconds_sum 2.888716127000002
prometheus_tsdb_wal_fsync_duration_seconds_count 216
```



- Histogram指标
  - 直接反应每个区间内的样本数

```
# HELP prometheus_tsdb_compaction_chunk_range Final time range of chunks on their first compaction
# TYPE prometheus_tsdb_compaction_chunk_range histogram
prometheus_tsdb_compaction_chunk_range_bucket{le="100"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="1600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="6400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="25600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="102400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="409600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="1.6384e+06"} 260
prometheus_tsdb_compaction_chunk_range_bucket{le="6.5536e+06"} 780
prometheus_tsdb_compaction_chunk_range_bucket{le="2.62144e+07"} 780
prometheus_tsdb_compaction_chunk_range_bucket{le="+Inf"} 780
prometheus_tsdb_compaction_chunk_range_sum 1.1540798e+09
prometheus_tsdb_compaction_chunk_range_count 780
```



## PromQL

通过定义的一组metrics name和label指定时间序列，从而进一步的对数据进行聚合计算

- 查询时间序列
  - 支持 = 和 !=两种类型
  - 使用 label=~regx 进行正则匹配，label!~regx进行排除

```
http_requests_total{code="200",handler="alerts",instance="localhost:9090",job="prometheus",method="get"}=(20889@1518096812.326)
http_requests_total{code="200",handler="graph",instance="localhost:9090",job="prometheus",method="get"}=(21287@1518096812.326)

// 多个查询
http_requests_total{environment=~"staging|testing|development",method!="GET"}
```



- 数学运算

```
node_memory_free_bytes_total / (1024 * 1024)

// 计算使用率超过95%的主机
(node_memory_bytes_total - node_memory_free_bytes_total) / node_memory_bytes_total > 0.95
```



- 聚合操作

```
sum (求和)
min (最小值)
max (最大值)
avg (平均值)
stddev (标准差)
stdvar (标准方差)
count (计数)
count_values (对value进行计数)
bottomk (后n条时序)
topk (前n条时序)
quantile (分位数)

sum(http_requests_total)
count_values("count", http_requests_total)
topk(5, http_requests_total)
quantile(0.5, http_requests_total)
```



- 内置函数

```
// 增长量
increase(node_cpu[2m]) / 120
// 等同于上面，直接计算增长率
rate(node_cpu[2m])
// 更灵敏的增长率，通过区间向量中最后两个样本数据来计算区间向量的计算瞬时增长率，用上面的容易陷入长尾问题
irate(node_cpu[2m])
```



## 黄金指标

Four Golden Signals是Google针对大量分布式监控的经验总结，4个黄金指标可以在服务级别帮助衡量终端用户体验、服务中断、业务影响等层面的问题。主要关注与以下四种类型的指标：延迟，通讯量，错误以及饱和度：

- 延迟：服务请求所需时间，可用Histogram指标来计算

记录用户所有请求所需的时间，重点是要区分成功请求的延迟时间和失败请求的延迟时间。 例如在数据库或者其他关键祸端服务异常触发HTTP 500的情况下，用户也可能会很快得到请求失败的响应内容，如果不加区分计算这些请求的延迟，可能导致计算结果与实际结果产生巨大的差异。除此以外，在微服务中通常提倡“快速失败”，开发人员需要特别注意这些延迟较大的错误，因为这些缓慢的错误会明显影响系统的性能，因此追踪这些错误的延迟也是非常重要的。



- 通讯量：监控当前系统的流量，用于衡量服务的容量需求，req_total

流量对于不同类型的系统而言可能代表不同的含义。例如，在HTTP REST API中, 流量通常是每秒HTTP请求数；



- 错误：监控当前系统所有发生的错误请求，衡量当前系统错误发生的速率，通过httpcode label过滤

对于失败而言有些是显式的(比如, HTTP 500错误)，而有些是隐式(比如，HTTP响应200，但实际业务流程依然是失败的)。

对于一些显式的错误如HTTP 500可以通过在负载均衡器(如Nginx)上进行捕获，而对于一些系统内部的异常，则可能需要直接从服务中添加钩子统计并进行获取。



- 饱和度：衡量当前服务的饱和度。

主要强调最能影响服务状态的受限制的资源。 例如，如果系统主要受内存影响，那就主要关注系统的内存状态，如果系统主要受限于磁盘I/O，那就主要观测磁盘I/O的状态。因为通常情况下，当这些资源达到饱和后，服务的性能会明显下降。同时还可以利用饱和度对系统做出预测，比如，“磁盘是否可能在4个小时候就满了”。