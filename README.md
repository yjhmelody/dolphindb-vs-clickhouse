
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

在本次测试中，分别为2款数据库软件搭建一个简单集群环境来进行对比。本次对比选用 `DolphinDB 0.95.3` 和 `ClickHouse 19.4.4.33 `进行。

### 服务器环境

本次配置7个节点进行性能对比测试，不设置副本，所有运行环境使用`docker`创建。

主机:
CPU: Intel(R) Xeon(R) CPU E5-2650 v4 @ 2.20GHz 48个核
内存: 504GB
硬盘: 10块2TB的HDD
操作系统: Linux version 3.10.0, CentOS 7


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

这里暂时不考虑有副本情况。

以下是DolphinDB的表创建。在DolphinDB中，我们按 `date`，`symbol` 进行分区， 每天再根据 `symbol` 分为 100 个分区。

```sql
// ...
DATE_RANGE = 2007.08.01..2007.09.30
date_schema = database("", VALUE, DATE_RANGE)
symbol_schema = database("", RANGE, buckets)
db = database(db_path, COMPO, [date_schema, symbol_schema])
db.createPartitionedTable(table(schema.name, schema.type), table_name, `date`symbol)
```

在ClickHouse中，我们尝试了一些表结构、分区方式、主键和分布式表的分发方式，最终选择了如下结构，该结构在该对比场景下综合上最优性能。

主键默认跟排序键相同,并且主键允许重复。`index_granularity=8192` 设置了索引粒度，它表示索引中相邻`标记`间的数据行数。ClickHouse 会为每个数据片段创建一个索引文件，索引文件包含每个索引行（`标记`）的主键值。索引行号定义为 `n * index_granularity` 。最大的 `n` 等于总行数除以 `index_granularity` 的值的整数部分。对于每列，跟主键相同的索引行处也会写入`标记`。这些`标记`可以让你直接找到数据所在的列。

通过`Distributed`表来选择`MergeTree`表插入，而查询`Distributed`表时，ClickHouse会自动委托其他节点去查找本地`MergeTree`表。

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

ClickHouse官方文档说明

> 我们建议每次写入不少于1000行的批量写入，或每秒不超过一个写入请求。当使用tab-separated格式将一份数据写入到MergeTree表中时，写入速度大约为50到200MB/s。如果您写入的数据每行为1Kb，那么写入的速度为50，000到200，000行每秒。如果您的行更小，那么写入速度将更高。为了提高写入性能，您可以使用多个INSERT进行并行写入，这将带来线性的性能提升。

对于ClickHouse数据导入，考虑到性能，使用官方自带的客户端，使用Bash为每个CSV导入启动一个进程。根据官方文档说明，这会带来几乎线性的性能提升。

以下是部分代码

```bash
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

导入时间是按照开始时间到最后一个进程完成的时间来计算。具体情况来看，DolphinDB一半导入任务在8分钟上下时完成，而ClickHouse是在20分钟上下的时候。

由于DolphinDB 和 ClickHouse 都支持`LZ4压缩`，因此导入性能都非常高。考虑到ClickHouse的CSV数据偏大，两款数据库的压缩能力相当，但是在导入时间方面，ClickHouse的时间是DolphinDB的2倍多。

### 查询性能

查询测试的时间包含磁盘 I/O 的时间，为保证测试公平，每次执行SQL语句前均通过 Linux 系统命令 `sync; echo 1,2,3 > /proc/sys/vm/drop_caches` 分别清除系统的页面缓存、目录项缓存和硬盘缓存。

ClickHouse 官方文档说明

> 如果一个查询使用主键并且没有太多行(几十万)进行处理，并且没有查询太多的列，那么在数据被page 
> cache缓存的情况下，它的延迟应该小于50毫秒(在最佳的情况下应该小于10毫秒)。 
> 否则，延迟取决于数据的查找次数。如果你当前使用的是HDD，在数据没有加载的情况下，查询所需要的延迟可以通过以下公式计算得知： 查找时间（10 ms） * 查询的列的数量 * 查询的数据块的数量。

对于ClickHouse，考虑到服务器机器的性能和实际观察情况，每条SQL语句执行后都用无关的表的SQL查询语句查询使之前的各种缓存失效，保证对性能对比的影响。

对于DolphinDB，我们使用相关的 API 清理所有缓存，并且释放操作系统分配的内存，保证第一次查询不受其他查询的影响。

为了减少网络开销带来的影响，客户端直接在服务器上启动。DolphinDB在启动数据节点后可以之间进入Web客户端中进行交互。对于ClickHouse，我们使用官方docker镜像与服务端交互。

DolphinDB 和 ClickHouse 两款数据库对表的读操作都是自动并行的。

#### 查询语句设计

我们编写了10个查询语句来进行对比

1. 查询总数
2. 点查询：按股票代码、时间查询
3. 范围查询：查询某时间段内的某些股票的所有记录
4. top1000 + 排序： 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序排序
5. 聚合查询： 单分区维度
6. 聚合查询：多分区维度 + 排序
7. 经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
8. 窗口查询：查询某种股票某天时间的差值
9. 经典查询：计算某天 (每个股票 每分钟) 最大卖出与最小买入价之差
10. 统计查询：拿到所有股票数据后计算中位数

#### 查询语句源码

| Query | DolphinDB                                                    | ClickHouse                                                   |
| ----- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 1     | select count(*) from taq                                     | SELECT count(*) FROM taq;                                    |
| 2     | select * from taq<br/>where<br/>	symbol = 'IBM', <br/>	date == 2007.09.07 | SELECT * FROM taq <br /> WHERE symbol = 'IBM' <br/>AND toDate(time) = '2007-09-07'; |
| 3     | select symbol, time, bid, ofr from taq <br/>where<br/>	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'),<br/>	date between 2007.08.03 : 2007.08.07,<br/>	bid > 20 | SELECT symbol, time, bid, ofr FROM taq <br/> WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') <br/>AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' <br/>AND bid > 20 |
| 4     | select top 1000 * from taq <br/>where<br/>	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'),<br/>	date == 2007.08.07,<br/>	time >= 07:36:37,<br/>	ofr > bid<br/>order by (ofr - bid) desc | SELECT * FROM taq <br/>WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') <br/>AND time >= toDateTime('2007-08-07 07:36:37') <br/>AND time < toDateTime('2007-08-08 00:00:00')<br/> AND ofr > bid <br/>ORDER BY (ofr - bid) DESC LIMIT 1000 |
| 5     | select max(bid) as max_bid, min(ofr) as min_ofr from taq<br/>where <br/>	date == 2007.08.02,<br/>	symbol == 'IBM',<br/>	ofr > bid<br/>group by minute(time) | SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq <br/>WHERE toDate(time) = '2007-08-02' <br/>AND symbol = 'IBM' AND ofr > bid <br/>GROUP BY toStartOfMinute(time) |
| 6     | select std(bid) as std_bid, sum(bidsiz) as sum_bidsiz from taq <br/>where <br/>	((date = 2007.09.10 and time > 09:00:00) or ( date = 2007.08.11 and time < 21:00:00)),<br/>	symbol in `IBM`MSFT`GOOG`YHOO,<br/>	bid >= 20,<br/>	ofr > 20<br/>group by symbol, minute(time) <br/>order by symbol asc, minute_time asc | SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq <br/> WHERE time BETWEEN toDateTime('2007-09-10 09:00:00')  AND toDateTime('2007-09-11 21:00:00') <br/>AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')<br/>AND bid >= 20 AND ofr > 20<br/>GROUP BY symbol, toStartOfMinute(time) AS minute_time <br/>ORDER BY symbol ASC , minute_time ASC |
| 7     | select symbol, time, bid, ofr from taq where<br/>	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'), <br/>	date = 2007.08.03, <br/>	time between 09:30:00 : 14:30:00, <br/>	bid > 0, <br/>	ofr > bid | SELECT symbol, time, bid, ofr FROM taq <br/>where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') <br/>AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') <br/>AND bid > 0 <br/>AND ofr > bid |
| 8     | select symbol, time, deltas(time) as time_diff from taq<br/>where<br/>	symbol = 'YHOO',<br/>	date = 2007.09.04<br/>order by time asc | SELECT symbol, time, runningDifference(time) AS time_diff FROM taq <br/> WHERE symbol = 'YHOO' AND date = '2007-09-04' <br/>ORDER BY time ASC |
| 9     | select max(ofr) - min(bid) as gap from taq<br/>where <br/>login(`admin, `123456)<br/><br/>db_path = 'dfs://TAQ2'<br/>db = database(db_path)<br/>taq = db.loadTable(`taq)	date = 2007.08.01, <br/>	bid > 0, <br/>	ofr > bid<br/>group by symbol, minute(time) as minute | SELECT max(ofr) - min(bid) AS gap FROM taq  <br/>WHERE toDate(time) IN '2007-08-01' <br/>AND bid > 0 AND ofr > bid <br/>GROUP BY symbol, toStartOfMinute(time) AS minute |
| 10    | select median(ofr), median(bid) from taq <br/>where <br/>	date = 2007.08.10, <br/>	symbol = 'IBM' | SELECT median(ofr), median(bid) FROM taq <br/> WHERE date = '2007-08-10' <br/>AND symbol = 'IBM' |

#### 查询性能对比

所有查询分为2种：

- 首次查询的性能，排除缓存影响

- 连续查询，即缓存以后继续查询，对比缓存带来的性能影响

每个查询用例测试3次。

##### 首次查询性能对比

|    样例     | DolphinDB | DolphinDB | DolphinDB | ClickHouse | ClickHouse | ClickHouse |
| :---------: | :-------: | :-------: | --------- | --------- | --------- | --------- |
| 1. 查询总数 |   137ms   |   190ms   | 160ms     | 14674ms    | 13743ms    | 16689ms    |
|  2. 点查询  |   412ms   |   319ms   | 330ms     | 810ms      | 625ms      | 677ms     |
| 3. 范围查询 |   971ms   |  1224ms   | 958ms     | 868ms      | 976ms      | 1061ms     |
| 4. top1000 |   607ms   |   596ms   | 411ms     | 956ms      | 640ms      | 808ms      |
| 5. 聚合查询 |   328ms   |   390ms   | 178ms     | 135ms      | 126ms      | 189ms      |
| 6. 聚合查询 |   360ms   |   425ms   | 252ms     | 545ms      | 509ms      | 450ms      |
| 7. 经典查询 |   364ms   |   357ms   | 359ms     | 337ms      | 206ms      | 280ms      |
| 8. 窗口查询 |   128ms   |   123ms   | 123ms     | 733ms      | 511ms      | 834ms      |
| 9. 经典查询 |  4799ms   |  5481ms   | 4051ms    | 22295ms    | 22966ms    | 24186ms   |
| 10.统计查询 |   321ms   |   364ms   | 229ms    | 378ms      | 205ms      | 387ms      |

|    样例     | DolphinDB | ClickHouse |
| :---------: | :-------: | ---------- |
| 1. 查询总数 |   162ms   | 15035ms    |
|  2. 点查询  |   354ms   | 704ms      |
| 3. 范围查询 |  1051ms   | 968ms      |
| 4. top1000  |   538ms   | 801ms      |
| 5. 聚合查询 |   299ms   | 150ms      |
| 6. 聚合查询 |   359ms   | 501ms      |
| 7. 经典查询 |   360ms   | 274ms      |
| 8. 窗口查询 |   125ms   | 693ms      |
| 9. 经典查询 |  4777ms   | 23149ms    |
| 10.统计查询 |   305ms   | 323ms      |



##### 连续查询性能对比

|    样例     | DolphinDB | DolphinDB | DolphinDB | ClickHouse | ClickHouse | ClickHouse |
| :---------: | :-------: | :-------: | --------- | --------- | --------- | --------- |
| 1. 查询总数 |   140ms   |   142ms   | 148ms     | 661ms      | 649ms      | 646ms      |
|  2. 点查询  |   121ms   |   119ms   | 117ms     | 198ms      | 193ms      | 195ms      |
| 3. 范围查询 |   850ms   |   855ms   | 839ms     | 354ms      | 366ms      | 433ms      |
| 4. top1000 |   40ms    |   42ms    | 38ms      | 94ms       | 98ms       | 98ms       |
| 5. 聚合查询 |   28ms    |   29ms    | 28ms      | 37ms       | 45ms       | 43ms       |
| 6. 聚合查询 |   94ms    |   101ms   | 96ms      | 115ms      | 127ms      | 104ms      |
| 7. 经典查询 |   225ms   |   233ms   | 226ms     | 220ms      | 220ms      | 227ms      |
| 8. 窗口查询 |   91ms    |   87ms    | 94ms      | 209ms      | 196ms      | 209ms      |
| 9. 经典查询 |  2826ms   |  3004ms   | 2872ms    | 4500ms     | 4472ms     | 4465ms     |
| 10.统计查询 |   44ms    |   44ms    | 46ms      | 45ms       | 43ms       | 43ms       |

|    样例     | DolphinDB | ClickHouse |
| :---------: | :-------: | ---------- |
| 1. 查询总数 |   143ms   | 652ms      |
|  2. 点查询  |   119ms   | 195ms      |
| 3. 范围查询 |   848ms   | 384ms      |
| 4. top1000  |   40ms    | 97ms       |
| 5. 聚合查询 |   28ms    | 42ms       |
| 6. 聚合查询 |   97ms    | 116ms      |
| 7. 经典查询 |   225ms   | 222ms      |
| 8. 窗口查询 |   91ms    | 205ms      |
| 9. 经典查询 |  2901ms   | 4479ms     |
| 10.统计查询 |   45ms    | 44ms       |

#### 一个复杂查询对比

由于 DolphinDB 内置了脚本语言，对于复杂查询依然能够方便的编写，内置的数据类型可以用在SQL语句中作为参数，非常灵活。下面一个复合查询可以如此拆开来进行，而不会失去性能。

```txt
	dateValue=2007.08.01
	num=500
	syms = (exec count(*) from taq 
	where 
		date = dateValue, 
		time between 09:30:00 : 15:59:59, 
		0 < bid, bid < ofr, ofr < bid*1.2
	group by symbol order by count desc).symbol[0:num]

	priceMatrix = exec avg(bid + ofr)/2.0 as price from taq 
	where 
		date = dateValue, Symbol in syms, 
		0<bid, bid<ofr, ofr<bid*1.2, 
		time between 09:30:00 : 15:59:59 
	pivot by time.minute() as minute, Symbol
```

pivot by是DolphinDB的独有功能，是对标准SQL的拓展。它按照两个维度将表中某列的内容重新整理（可以使用数据转换函数），和select子句在一起使用时返回一个表，而和exec语句一起使用时将转换成一个矩阵。

对于ClickHouse，无法很好地实现这种pivot查询。于是我们使用第三方API来查询两次数据后，然后使用pandas进行pivot。本次对比也是在本地上查询



|   样例   | DolphinDB | ClickHouse |
| :------: | :-------: | ---------- |
| 首次查询 |  4098ms   | 27636ms    |
| 连续查询 |  3718ms   | 12728ms    |

### 性能对比分析

可以看到对于窗口函数，DolphinDB的速度比ClickHouse要快很多。实际上ClickHouse对窗口函数的支持很有限。ClickHouse不支持多级表连接，而且行为跟常规SQL语句差别很大。ClickHouse没有专门的时分秒数据类型，默认的配置也是按月进行分区，场景定位可能更倾向于较粗时间粒度的时间序列分析。

本次性能对比没有使用上复杂的查询语句，因为ClickHouse主要使用SQL语句进行控制，对于复杂查询，对开发人员的代码编写不太友好。DolphinDB内置的脚本语言对于复杂查询能更灵活的编写。

在该场景下，在ClickHouse中我们选用了MergeTree这种强大的表引擎。

### 分区方式对比

分区的总原则是让数据管理更加高效，提高查询和计算的性能，达到低延时和高吞吐量。

DolphinDB 支持多种分区方式，DolphinDB推荐的分区大小是控制在100MB到1GB之间，这里我们选用了基于股票时间的值分区和股票代码的范围分区的组合分区。

本次性能对比是在固定节点数的情况下进行对比，但是对于需要<yandex>

    <clickhouse_remote_servers>
        <!-- 2分片无复制 -->
        <cluster_2shard_1replicas>
            <!-- 数据分片1 -->
            <shard>
                <replica>
                    <host>192.168.1.119</host>
                    <port>9000</port>
                </replica>
            </shard>
    
            <!-- 数据分片2 -->
            <shard>
                <replica>
                    <host>192.168.1.201</host>
                    <port>9000</port>
                </replica>
            </shard>
    
        </cluster_2shard_1replicas>
    </clickhouse_remote_servers>
    
    <!-- ZK  -->
    <zookeeper-servers>
        <node index="1">
          <host>192.168.1.109</host>
          <port>2181</port>
        </node>
    </zookeeper-servers>
    
    <!-- 数据压缩算法  -->
    <clickhouse_compression>
        <case>
          <min_part_size>10000000000</min_part_size>
          <min_part_size_ratio>0.01</min_part_size_ratio>
          <method>lz4</method>
        </case>
    </clickhouse_compression>

</yandex>增加新节点的情况，两款数据库对此支持程度不相同。

ClickHouse的分布式表的问题：必须要在所有节点上创建本地表（这里的例子是`MergeTree`）和分布式表（`Distrubuted`），否则向分布式表插入时会出错。ClickHouse的分布式表因此扩展性也比较差，除了要手动增加节点之外，由于可能会遗漏一些节点的表而出错，扩展时不适合做查询。此外，由于增加了新节点后，数据无法自动重平衡，只能调整新节点的分片权重来缓解该问题。总的来说，ClickHouse的分区可扩展性和可靠性较差，不支持更精细的分区。

## 附录

部分数据
- [DolphinDB TAQ](data/TAQ.csv)
- [ClickHouse TAQ](data/new_TAQ.csv)
- [ClicHouse数据转换脚本](script/clickhouse/csv_transfer.py)

DolphinDB
- [集群配置](docker/dolphindb/config/cluster.cfg)
- [Dockerfile](docker/dolphindb/Dockerfile)
- [docker-compose](docker/dolphindb/docker-compose.yml)
- [测试脚本](script/dolphindb/taq2.txt)

ClickHouse
- [集群配置](docker/clickhouse/env/config/metrika.xml)
- [服务端 Dockerfile](docker/clickhouse/Dockerfile)
- [服务端 docker-compose](docker/clickhouse/docker-compose.yml)
- [客户端 Dockerfile](docker/clickhouse/client/Dockerfile)
- [客户端 docker-compose](docker/clickhouse/client/docker-compose.yml)
- [测试脚本](script/clickhouse/taq2.sql)
