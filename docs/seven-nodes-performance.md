
# DolphinDB 与 ClickHouse 集群性能对比

## 概述

### DolphinDB

`DolphinDB` 是以 C++ 编写的一款分析型的高性能分布式时序数据库，使用高吞吐低延迟的列式内存引擎，集成了功能强大的编程语言和高容量高速度的流数据分析系统，可在数据库中进行复杂的编程和运算，显著减少数据迁移所耗费的时间。
DolphinDB 通过内存引擎、数据本地化、细粒度数据分区和并行计算实现高速的分布式计算，内置流水线、 Map Reduce 和迭代计算等多种计算框架，使用内嵌的分布式文件系统自动管理分区数据及其副本，为分布式计算提供负载均衡和容错能力。
DolphinDB 支持类标准 SQL 的语法，提供类似于 Python 的脚本语言对数据进行操作，也提供其它常用编程语言的 API，在金融领域中的历史数据分析建模与实时流数据处理，以及物联网领域中的海量传感器数据处理与实时分析等场景中表现出色。

### ClickHouse

`ClickHouse` 也是以 C++ 编写的一款用于联机分析(OLAP)的列式数据库管理系统(DBMS)，是一款真正的列式数据库管理系统。
许多的列式数据库只能在内存中工作，ClickHouse被设计用于工作在传统磁盘上的系统，它提供每GB更低的存储成本，但如果有可以使用SSD和内存，它也会合理的利用这些资源。大型查询可以以很自然的方式在ClickHouse中进行并行化处理，以此来使用当前服务器上可用的所有资源。
ClickHouse支持在表中定义主键。为了使查询能够快速在主键中进行范围查找，数据总是以增量的方式有序的存储在MergeTree中。因此，数据可以持续不断高效的写入到表中，并且写入的过程中不会存在任何加锁的行为。
ClickHouse提供各种各样在允许牺牲数据精度的情况下对查询进行加速的方法：

- 用于近似计算的各类聚合函数，如：distinct values, medians, quantiles
- 基于数据的部分样本进行近似查询。这时，仅会从磁盘检索少部分比例的数据。
- 不使用全部的聚合条件，通过随机选择有限个数据聚合条件进行聚合。这在数据聚合条件满足某些分布条件下，在提供相当准确的聚合结果的同时降低了计算资源的使用。

在本次性能对比中，我们对DolphinDB和ClickHouse在时间序列数据集上进行对比。测试涵盖了数据导入、空间占用、查询性能等方面。

## 测试环境

在本次测试中，分别为2款数据库软件搭建一个简单集群环境来进行对比。
选用 `DolphinDB 0.95.3` 和 `ClickHouse 19.4.4.33 `进行对比。

### 服务器环境

本次配置7个节点进行性能对比测试，不设置副本，所有运行环境使用`docker`创建。

### 测试集

434 GB 股票交易大数据集（CSV 格式，42 个 CSV，近105 亿条）。
我们将纽约证券交易所（NYSE）提供的 2007.08.01 - 2007.09.31 一个月的股市 Level 1 报价数据作为大数据集进行测试，数据集包含 8000 多支股票在2个月内的 交易时间, 股票代码, 买入价, 卖出价, 买入量, 卖出量等报价信息。
数据集中共有 105 亿（10486785993）条报价记录，一个 CSV 中保存一个交易日的记录，2个月共 42 个交易日，未压缩的 CSV 文件共计 434 GB。 来源：https://www.nyse.com/market-data/historical

#### TAQ 表设计

| Column | DolphinDB 数据类型 | ClickHouse 数据类型 |
| ------ | ------------------ | ------------------- |
| symbol | SYMBOL             | String              |
| date   | DATE               | Date                |
| time   | SECOND             | DateTime            |
| bid    | DOUBLE             | Float64             |
| ofr    | DOUBLE             | Float64             |
| bidsiz | INT                | Int32               |
| ofrsiz | INT                | Int32               |
| mode   | INT                | Int32               |
| ex     | CHAR               | FixedString(1)      |
| mmid   | SYMBOL             | Nullable(String)    |

在ClickHouse中，由于没有对应的Time类型，我们将它转为DateTime类型，并且在导入前先转换CSV文件适配ClickHouse的CSV格式要求。ClickHouse的CSV文件体积会有一定的增大。

####  表结构创建

以下是DolphinDB的表创建。在DolphinDB中，我们按 `date`，`symbol` 进行分区， 每天再根据 `symbol` 分为 100 个分区。

```sql
// ...
DATE_RANGE = 2007.08.01..2007.09.30
date_schema = database("", VALUE, DATE_RANGE)
symbol_schema = database("", RANGE, buckets)
db = database(db_path, COMPO, [date_schema, symbol_schema])
db.createPartitionedTable(table(schema.name, schema.type), table_name, `date`symbol)

```



在ClickHouse中，我们尝试了一些表结构、分区方式、主键和分布式表的分发方式，最终选择了如下结构，该结构在该对比场景下综合上最优性能。通过`Distributed`表来选择`MergeTree`表插入，而查询`Distributed`表时，ClickHouse会自动委托其他节点去查找局部`MergeTree`表。

```sql
CREATE TABLE IF NOT EXISTS taq_local (
    symbol String,
    date Date,
    time DateTime,
    bid Float64,
    ofr Float64,
    bidSiz Int32,
    ofrsiz Int32,
    mode Int32,
    ex FixedString(1),
    mmid Nullable(String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(time)
ORDER BY symbol
SETTINGS index_granularity=8192;

CREATE TABLE IF NOT EXISTS taq AS taq_local
ENGINE = Distributed(cluster_7shard_1replicas, default, taq_local, toYYYYMMDD(time));
```

这种分区设计也跟DolphinDB的分区设计比较接近。

## 性能对比

### 导入性能

#### 从CSV文件导入数据

考虑到一共有42个TAQ数据，这里DolphinDB和ClickHouse的7节点各自启动6个进程来并行导入CSV。ClickHouse 为了高效的使用CPU，数据不仅仅按列存储，同时还按向量(列的一部分)进行处理。(ClickHouse 本身需要支持SSE 4.2指令集)，在底层，DolphinDB和ClickHouse会自动并发地加载数据；

DolphinDB 脚本：

```sql
// ...
db_path = 'dfs://TAQ2'

def load_csv(db_path, f) {
	db = database(db_path)
	loadTextEx(db, `taq, `date`symbol, f)	
}

def loadCSV(job_id, job_desc, db_path) {
	taq_path = '/data2/TAQ/'
	fs = taq_path + (exec filename from files(taq_path) order by filename)
	for (f in fs) {
		submitJob(job_id, job_desc, load_csv, db_path, f)
	}
}

rpc("P1-node1", loadCSV, `node1, "load csv", db_path)
rpc("P2-node1", loadCSV, `node2, "load csv", db_path)
rpc("P3-node1", loadCSV, `node3, "load csv", db_path)
rpc("P4-node1", loadCSV, `node4, "load csv", db_path)
rpc("P5-node1", loadCSV, `node5, "load csv", db_path)
rpc("P6-node1", loadCSV, `node6, "load csv", db_path)
rpc("P7-node1", loadCSV, `node7, "load csv", db_path)
```

考虑到性能，ClickHouse 使用官方自带客户端，使用Bash为每个CSV导入启动一个进程。以下是部分代码

```sh
for i in 1 2 3 4 5 6 7; do
for file in /hdd/hdd${i}/data/*.csv ; do
        clickhouse-client \
        --use_client_time_zone true \
        --host 10.5.0.$((${i} + 1)) \
        --port 9000 \
        --query="INSERT INTO taq FORMAT CSV"  < $file &
    done;
done;
```

#### 导入性能表

| 导入性能 | DolphinDB | ClickHouse |
| -------- | --------- | ---------- |
| 导入时间 | 10分28秒  | 28分5秒    |
| 磁盘空间 | 83.0 GB   | 94.8 GB    |

导入时间是按照开始时间到最后一个进程完成的时间来计算。具体来看，DolphinDB一半导入任务在8分钟上下时完成，而ClickHouse是在20分钟上下的时候。

由于DolphinDB 和 ClickHouse 都支持`LZ4压缩`，因此导入性能都非常高。

### 查询性能

查询测试的时间包含磁盘 I/O 的时间，为保证测试公平，每次启动程序测试前均通过 Linux 系统命令 `sync; echo 1,2,3 > /proc/sys/vm/drop_caches` 分别清除系统的页面缓存、目录项缓存和硬盘缓存。

考虑到服务器机器的性能和实际观察情况，每条SQL语句执行后都用无关的表的SQL语句查询使之前的各种缓存失效。

对于DolphinDB，我们使用相关的 API 清理所有缓存，并且释放操作系统分配的内存，保证第一次查询不受其他查询的影响。

#### 查询语句设计

我们编写了10个查询语句来进行对比

查询语句：

0. 查询总数
1. 点查询：按股票代码、时间查询
2. 范围查询：查询某时间段内的某些股票的所有记录
3. top1000 + 排序： 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序排序
4. 聚合查询： 单分区维度
5. 聚合查询：多分区维度 + 排序
6. 经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
7. 窗口查询：查询某种股票某天时间的差值
8. 经典查询：计算某天 (每个股票 每分钟) 最大卖出与最小买入价之差
9. 统计查询：拿到所有股票数据后计算中位数

#### 查询语句源码

| Query | DolphinDB                                                    | ClickHouse                                                   |
| ----- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 0     | select count(*) from taq                                     | SELECT count(*) FROM taq;                                    |
| 1     | select * from taq<br/>where<br/>	symbol = 'IBM', <br/>	date == 2007.09.07 | SELECT * FROM taq <br /> WHERE symbol = 'IBM' <br/>AND toDate(time) = '2007-09-07'; |
| 2     | select symbol, time, bid, ofr from taq <br/>where<br/>	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'),<br/>	date between 2007.08.03 : 2007.08.07,<br/>	bid > 20 | SELECT symbol, time, bid, ofr FROM taq <br/> WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') <br/>AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' <br/>AND bid > 20 |
| 3     | select top 1000 * from taq <br/>where<br/>	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'),<br/>	date == 2007.08.07,<br/>	time >= 07:36:37,<br/>	ofr > bid<br/>order by (ofr - bid) desc | SELECT * FROM taq <br/>WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') <br/>AND time >= toDateTime('2007-08-07 07:36:37') <br/>AND time < toDateTime('2007-08-08 00:00:00')<br/> AND ofr > bid <br/>ORDER BY (ofr - bid) DESC LIMIT 1000 |
| 4     | select max(bid) as max_bid, min(ofr) as min_ofr from taq<br/>where <br/>	date == 2007.08.02,<br/>	symbol == 'IBM',<br/>	ofr > bid<br/>group by minute(time) | SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq <br/>WHERE toDate(time) = '2007-08-02' <br/>AND symbol = 'IBM' AND ofr > bid <br/>GROUP BY toStartOfMinute(time) |
| 5     | select std(bid) as std_bid, sum(bidsiz) as sum_bidsiz from taq <br/>where <br/>	((date = 2007.09.10 and time > 09:00:00) or ( date = 2007.08.11 and time < 21:00:00)),<br/>	symbol in `IBM`MSFT`GOOG`YHOO,<br/>	bid >= 20,<br/>	ofr > 20<br/>group by symbol, minute(time) <br/>order by symbol asc, minute_time asc | SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq <br/> WHERE time BETWEEN toDateTime('2007-09-10 09:00:00')  AND toDateTime('2007-09-11 21:00:00') <br/>AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')<br/>AND bid >= 20 AND ofr > 20<br/>GROUP BY symbol, toStartOfMinute(time) AS minute_time <br/>ORDER BY symbol ASC , minute_time ASC |
| 6     | select symbol, time, bid, ofr from taq where<br/>	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'), <br/>	date = 2007.08.03, <br/>	time between 09:30:00 : 14:30:00, <br/>	bid > 0, <br/>	ofr > bid | SELECT symbol, time, bid, ofr FROM taq <br/>where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') <br/>AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') <br/>AND bid > 0 <br/>AND ofr > bid |
| 7     | select symbol, time, deltas(time) as time_diff from taq<br/>where<br/>	symbol = 'YHOO',<br/>	date = 2007.09.04<br/>order by time asc | SELECT symbol, time, runningDifference(time) AS time_diff FROM taq <br/> WHERE symbol = 'YHOO' AND date = '2007-09-04' <br/>ORDER BY time ASC |
| 8     | select max(ofr) - min(bid) as gap from taq<br/>where <br/>	date = 2007.08.01, <br/>	bid > 0, <br/>	ofr > bid<br/>group by symbol, minute(time) as minute | SELECT max(ofr) - min(bid) AS gap FROM taq  <br/>WHERE toDate(time) IN '2007-08-01' <br/>AND bid > 0 AND ofr > bid <br/>GROUP BY symbol, toStartOfMinute(time) AS minute |
| 9     | select median(ofr), median(bid) from taq <br/>where <br/>	date = 2007.08.10, <br/>	symbol = 'IBM' | SELECT median(ofr), median(bid) FROM taq <br/> WHERE date = '2007-08-10' <br/>AND symbol = 'IBM' |

#### 查询性能对比

所有查询分为2种：

- 第一次查询的性能，没有缓存

- 连续查询，对比缓存带来的性能改变。

每个查询用例测量3次。DolphinDB 和 ClickHouse 两款数据库对表的读操作都是自动并行的。


|    样例     | DolphinDB 用时(第一次查询) | ClickHouse 用时(第一次查询) | DolphinDB 用时(连续查询) | ClickHouse 用时(连续查询) |
| :---------: | :------------------------: | :-------------------------: | :----------------------: | :-----------------------: |
| 0. 查询总数 |     137ms 190ms  160ms     |   14.674s 13.743s 16.689s   |    140ms 142ms 148ms     |     661ms 649ms 646ms     |
|  1. 点查询  |     412ms 319ms 330ms      |      810ms 625ms 677ms      |    121ms 119ms 117ms     |     198ms 193ms 195ms     |
| 2. 范围查询 |     971ms 1224ms 958ms     |     868ms 976ms 1061ms      |    850ms 855ms 839ms     |     354ms 366ms 433ms     |
| 3. top1000  |     607ms 596ms 411ms      |      956ms 640ms 808ms      |      40ms 42ms 38ms      |      94ms 98ms 98ms       |
| 4. 聚合查询 |     328ms 390ms 178ms      |      135ms 126ms 189ms      |      28ms 29ms 28ms      |      37ms 45ms 43ms       |
| 5. 聚合查询 |     360ms 425ms 252ms      |      545ms 509ms 450ms      |     94ms 101ms 96ms      |     115ms 127ms 104ms     |
| 6. 经典查询 |     364ms 357ms 359ms      |      337ms 206ms 280ms      |    225ms 233ms 226ms     |     220ms 220ms 227ms     |
| 7. 窗口查询 |     128ms 123ms 123ms      |      733ms 511ms 834ms      |      91ms 87ms 94ms      |     209ms 196ms 209ms     |
| 8. 经典查询 |    4.799s 5.481s 4.051s    |   22.295s 22.966s 24.186s   |   2.826s 3.004s 2.872s   |   4.500s 4.472s 4.465s    |
| 9.统计查询  |     321ms 364ms 229ms      |      378ms 205ms 387ms      |      44ms 44ms 46ms      |      45ms 43ms 43ms       |

