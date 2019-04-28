# ClickHouse 速记

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

| Column | DolphinDB 数据类型    | ClickHouse 数据类型 |
| ------ | --------------------- | ------------------- |
| symbol | SYMBOL (分区第二维度) | String              |
| date   | DATE (分区第一维度)   | Date                |
| time   | SECOND                | DateTime            |
| bid    | DOUBLE                | Float64             |
| ofr    | DOUBLE                | Float64             |
| bidsiz | INT                   | Int32               |
| ofrsiz | INT                   | Int32               |
| mode   | INT                   | Int32               |
| ex     | CHAR                  | Int8                |
| mmid   | SYMBOL                | String              |


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