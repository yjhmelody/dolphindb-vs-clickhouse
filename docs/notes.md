# ClickHouse 速记

ClickHouse 不支持事务，不支持update和delete

## Clickhouse MergeTree

MergeTree 类似 LSM-Tree, 但是没有内存表，不记录log
直接按照主键排序分块写入磁盘
异步merge，与写入不冲突，最大merge到月维度
不支持删除和修改

高性能读取：按照主键查询（最左原则），
稀疏索引定位区间：不适合点对点查询，适合范围查询，有大量的IO
稀疏索引可以节省大量索引空间，这个索引始终放在内存中。


## ClickHouse 缺点

可扩展性和可靠性差。

默认情况下，INSERT 语句仅等待一个副本写入成功后返回。如果数据只成功写入一个副本后该副本所在的服务器不再存在，则存储的数据会丢失。要启用数据写入多个副本才确认返回，使用 insert_quorum 选项。

## ClickHouse Distrubuted 引擎

- 本身不存储数据
- 写入数据时，做数据转发
- 查询数据时，作为中间件，聚合数据

## ClickHouse Config

ClickHouse有几核心的配置文件：

- config.xml 端口配置、本地机器名配置、内存设置等
- metrika.xml 集群配置、ZK配置、分片配置等
- users.xml 权限、配额设置

ClickHouse主要使用向量化查询执行和有限的运行时代码生成支持(仅GROUP BY内部循环第一阶段被编译)。

## Traps

- metrika.xml 在 /etc/下
- 如果要修改数据库各种数据存放的位置，记得要修改目录所有者为clickhouse

ClickHouse cluster is a homogenous cluster. Steps to set up:

1. Install ClickHouse server on all machines of the cluster
2. Set up cluster configs in configuration file
3. Create local tables on each instance
4. Create a Distributed table

start/stop/status ClickHouse

```sh
sudo service clickhouse-sever [start/stop/status]
```

ClickHouse needs ZooKeeper to build cluster

- 分布式+高可用方案1, 考虑数据的安全性，即副本, MergeTree + Distributed + 集群复制
- 分布式+高可用方案2, ReplicatedMergeTree + Distributed, 仅仅是把MergeTree引擎替换为ReplicatedMergeTree引擎, ReplicatedMergeTree里，共享同一个ZK路径的表，会相互，注意是，相互同步数据

- 主键并不是唯一的，可以插入主键相同的数据行。
- 主键是有序数据的稀疏索引。
- 组成主键的列的数量，并没有明确规定。过长的主键通常来说没啥用。
- 过长的主键，会拖慢写入性能，并且会造成过多的内存占用。
- 过长的主键，并不会对查询性能有太大的影响。
- 综合来讲，使用索引，总是会比全表扫描要高效一些的。
- index_granularity=8192对于大多数场景都是比较好的选择。


主键和索引在查询中的表现

我们以 (CounterID, Date) 以主键。排序好的索引的图示会是下面这样：
```
全部数据  :     [-------------------------------------------------------------------------]
CounterID:      [aaaaaaaaaaaaaaaaaabbbbcdeeeeeeeeeeeeefgggggggghhhhhhhhhiiiiiiiiikllllllll]
Date:           [1111111222222233331233211111222222333211111112122222223111112223311122333]
标记:            |      |      |      |      |      |      |      |      |      |      |
                a,1    a,2    a,3    b,3    e,2    e,3    g,1    h,2    i,1    i,3    l,3
标记号:          0      1      2      3      4      5      6      7      8      9      10
```
如果指定查询如下：
- CounterID in ('a', 'h')，服务器会读取标记号在 [0, 3) 和 [6, 8) 区间中的数据。
- CounterID IN ('a', 'h') AND Date = 3，服务器会读取标记号在 [1, 3) 和 [7, 8) 区间中的数据。
- Date = 3，服务器会读取标记号在 [1, 10] 区间中的数据。

上面例子可以看出使用索引通常会比全表描述要高效。

稀疏索引会引起额外的数据读取。当读取主键单个区间范围的数据时，每个数据块中最多会多读 index_granularity * 2 行额外的数据。大部分情况下，当 index_granularity = 8192 时，ClickHouse的性能并不会降级。

稀疏索引让你能操作有巨量行的表。因为这些索引是常驻内存（RAM）的。

ClickHouse 不要求主键惟一。所以，你可以插入多条具有相同主键的行。


## ClickHouse增加分片

When you add a new shard, old data is not moved to it automatically. Recommended approach is indeed to "play with the weights" as you have put it, i.e. increase the weight of the new node until the volume of data is even. But if you want to rebalance the data immediately, you can use the ALTER TABLE RESHARD command. Read the docs carefully and keep in mind various limitations of this command, e.g. it is not atomic.

## 清理缓存

清除页面缓存（PageCache）
```
sync; echo 1 > /proc/sys/vm/drop_caches       
```

清理目录项和inode
```
sync; echo 2 > /proc/sys/vm/drop_caches
```

清除页面缓存，目录项和inode
sync; echo 3 > /proc/sys/vm/drop_caches 
```