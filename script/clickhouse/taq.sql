SELECT * FROM system.clusters;
SELECT * FROM system.zookeeper WHERE path = '/clickhouse';
SELECT memory_usage, query, peak_memory_usage FROM system.processes;

DROP TABLE IF EXISTS taq_local;
DROP TABLE IF EXISTS taq;

-- 对于 CREATE， DROP， ALTER，以及RENAME查询，系统支持其运行在整个集群上
-- MergeTree() 参数
--     date-column — 类型为 Date 的列名。ClickHouse 会自动依据这个列按月创建分区。分区名格式为 "YYYYMM" 。
--     sampling_expression — 采样表达式。
--     (primary, key) — 主键。类型 — Tuple()
--     index_granularity — 索引粒度。即索引中相邻『标记』间的数据行数。设为 8192 可以适用大部分场景。

-- 默认情况下主键跟排序键（由ORDER BY子句指定）相同。因此，大部分情况下不需要再专⻔指定一个PRIMARY KEY子句。

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
PARTITION BY toYYYYMM(time)
ORDER BY (symbol, toYYYYMM(time))
SETTINGS index_granularity=8192;


-- 另外一种模式
CREATE TABLE IF NOT EXISTS taq_local3 (
    symbol String,
    time DateTime,
    bid Float64,
    ofr Float64,
    bidSiz Int32,
    ofrsiz Int32,
    mode Int32,
    ex FixedString(1),
    mmid Nullable(String)
) ENGINE = MergeTree()
PARTITION BY (toDate(time), symbol)
ORDER BY (toYYYYMMDD(time), symbol)
SETTINGS index_granularity=8192;

-- 创建分布式表
CREATE TABLE taq AS taq_local
ENGINE = Distributed(cluster_2shard_replicas, default, taq_local, rand());

-- INSERT INTO taq_local VALUES ('A', '2007-08-01', toDateTime('2007-08-01 016:24:34' , 'UTC'), 1, 0, 1, 0, 12,'P', NULL);
-- INSERT INTO taq VALUES ('A', '2007-08-01', '2017-08-01 06:24:34', 1, 0, 1, 0, 12,'P', NULL);

SELECT * FROM taq_local ORDER BY time ASC;

SELECT * FROM taq ORDER BY time ASC;


-- 2节点并发插入分布式表
-- times: 42mins 58s  52mins 48s



---------------------------- 查询
SELECT count(*) FROM taq;
-- 23s 546ms  20s 191ms
-- 连续查询 455ms 461ms 462ms

--- 查看内存占用
select value / 1024 / 1024 / 1024 from system.metrics where metric = 'MemoryTracking';

-- 1. 点查询：按股票代码、时间查询
SELECT * FROM taq
WHERE
	symbol = 'IBM'
    AND date = toDate('2007-08-07')
;
-- times: 138 ms  141 ms  147ms
-- 连续查询  145ms  144ms  144ms



-- 2. 范围查询：查询某时间段内的某些股票的所有记录
SELECT symbol, time, bid, ofr FROM taq
WHERE
	symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07'
	AND bid > 20
;
--- or ?
SELECT symbol, time, bid, ofr FROM taq
WHERE
	symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND toYYYYMMDD(time) BETWEEN 20070803 AND 20070807
	AND bid > 20
;
-- times: 764 ms  789 ms  767 ms
-- 连续查询 792 ms  802 ms  799 ms



-- 3. top 1000 + 排序: 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序
SELECT * FROM taq
WHERE
	symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND date = toDate('2007-08-07')
	AND time >= toDateTime('2007-08-07 07:36:37')
    AND time < toDateTime('2007-08-08 00:00:00')
	AND ofr > bid
ORDER BY (ofr - bid) DESC
LIMIT 1000
;
-- times: 55 ms 80 ms  42ms
-- 连续查询 48ms  41ms  41ms



-- 4. 聚合查询. 单分区维度
SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq
WHERE
	toDate(time) = toDate('2007-08-02')
	AND symbol = 'IBM'
	AND ofr > bid
GROUP BY toStartOfMinute(time)
;

---- or

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq
WHERE
	toYYYYMMDD(time) = 20070802
	AND symbol = 'IBM'
	AND ofr > bid
GROUP BY toStartOfMinute(time)
;
-- times: 19 ms  26ms  24ms
-- 连续查询 22ms 29ms  27ms




-- 5. 聚合查询.多分区维度 + 排序
SELECT
	stddevPop(bid) 	AS std_bid,
	sum(bidSiz) AS sum_bidsiz
FROM taq
WHERE
	time BETWEEN toDateTime('2007-08-07 09:00:00')  AND toDateTime('2007-08-07 21:00:00')
	AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND bid >= 20
	AND ofr > 20
GROUP BY symbol, toStartOfMinute(time) AS minute_time
ORDER BY symbol ASC , minute_time ASC
;

------ or

SELECT
	stddevPop(bid) 	AS std_bid,
	sum(bidSiz) AS sum_bidsiz
FROM taq
WHERE
	toYYYYMMDDhhmmss(time) BETWEEN 20070807090000  AND 20070807210000
	AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND bid >= 20
	AND ofr > 20
GROUP BY symbol, toStartOfMinute(time) AS minute_time
ORDER BY symbol ASC , minute_time ASC
;
-- times:  116ms 118ms
-- 连续查询 87ms  59ms  66ms




-- 6. 经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
SELECT symbol, time, bid, ofr FROM taq
where
	symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00')
	AND bid > 0
    AND ofr > bid
;
-- times: 185 ms  177 ms  183ms
-- 连续查询 194ms  191ms 171ms




-- 8. 经典查询：计算某天 (每个股票 每分钟) 最大卖出与最小买入价之差
SELECT max(ofr) - min(bid) AS gap
FROM taq
WHERE
	toDate(time) IN toDate('2007-08-03')
	AND bid > 0
	AND ofr > bid
GROUP BY symbol, toStartOfMinute(time) AS minute
;

----- or

SELECT max(ofr) - min(bid) AS gap
FROM taq
WHERE
	toYYYYMMDD(time) IN 20070803
	AND bid > 0
	AND ofr > bid
GROUP BY symbol, toStartOfMinute(time) AS minute
;
-- times: 23s 812ms  29s 471ms
-- 连续查询 7s 608ms  7s 514ms  7s 504ms




--------------------------------------- 下面逻辑不一致 -----------------------------------------


-- 7. 经典查询：按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，查询 (各个股票 每分钟) [平均变化幅度]
SELECT avg( (ofr - bid) / (ofr + bid) ) * 2 AS spread FROM taq
WHERE
	time BETWEEN toDateTime('2007-08-01 09:30:00') AND toDateTime('2007-08-01 16:00:00')
	AND bid > 0
  AND ofr > bid
GROUP BY symbol, toStartOfMinute(time) as minute
;
-- times:
-- 连续查询
-- 内存 1,537.6  1,423.1



-- 9. 经典查询：按 [股票代码、日期段、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价
SELECT avg(ofr + bid) / 2.0 AS avg_price
FROM taq
WHERE
	symbol = 'IBM'
	AND toDate(time) BETWEEN toDate('2007-08-01') AND toDate('2007-08-07')
    AND ((toHour(time) AS hour BETWEEN 10 AND 16) OR (hour = 9 AND toMinute(time) >= 30)
-- 	AND time BETWEEN 09:30:00 : 16:00:00
GROUP BY date, toStartOfMinute(time) AS minute
;
-- times:
-- 连续查询
-- 内存 196.3 308.3




-- 10. 经典查询：按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价
SELECT avg(ofr + bid) / 2.0 AS avg_price
FROM taq
WHERE
	time BETWEEN '2007-08-05 09:30:00' AND '2007-08-07 16:00:00'
GROUP BY symbol, toYYYYMMDD(time)
;
-- times:
-- 连续查询
-- 内存 8,962.8  11,900.9




-- 11. 经典查询：计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序
-- 没有wavg
select wavg(bid, bidsiz) as vwab
from taq
where toDate(time) between '2007-08-05'  AND '2007-08-06'
group by toDate(time), symbol
	having sum(bidsiz) > 0
order by toDate(time) desc, symbol
-- times:
-- 连续查询
-- 内存 3,322.5  4,240.6
