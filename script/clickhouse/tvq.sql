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
PARTITION BY toYYYYMM(date)
ORDER BY (symbol, date)
SETTINGS index_granularity=8192;

-- 创建分布式表
CREATE TABLE taq AS taq_local
ENGINE = Distributed(cluster_2shard_replicas, default, taq_local, rand());

-- INSERT INTO taq_local VALUES ('A', '2007-08-01', toDateTime('2007-08-01 016:24:34' , 'UTC'), 1, 0, 1, 0, 12,'P', NULL);

INSERT INTO taq VALUES ('A', '2007-08-01', '2017-08-01 06:24:34', 1, 0, 1, 0, 12,'P', NULL);

SELECT * FROM taq_local ORDER BY time ASC;

SELECT * FROM taq ORDER BY time ASC;

-- symbol,date,time,bid,ofr,bidsiz,ofrsiz,mode,ex,mmid
-- A,20070801,6:24:34,1,0,  1,      0,     12,  P,



--------- 查询
-- 1. 点查询：按股票代码、时间查询
SELECT * FROM taq
WHERE
	symbol = 'IBM'
    AND date = toDate('2007-08-07')
;
-- times: 116.748 ms  149.129 ms  165.471 ms
-- 连续查询 10.742 ms  11.612 ms  7.174 ms
-- 内存 136.3 0.3



-- 2. 范围查询：查询某时间段内的某些股票的所有记录
SELECT symbol, time, bid, ofr FROM taq
WHERE
	symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDate('2007-08-07 09:40:00')
	AND bid > 20
;
-- times: 182.99 ms  210.585 ms  208.487 ms
-- 连续查询 67.443 ms  65.755 ms  66.841 ms
-- 内存 744.3  264.3



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
-- times: 173.155 ms  199.938 ms  187.943 ms
-- 连续查询 27.077 ms  22.249 ms  28.478 ms
-- 内存 588.3 0.3



-- 4. 聚合查询. 单分区维度
SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq
WHERE
	date = toDate('2007-08-02')
	AND symbol = 'IBM'
	AND ofr > bid
GROUP BY toStartOfMinute(time)
;
-- times: 45.3 ms  101.986 ms  74.189 ms
-- 连续查询 16.361 ms  32.176 ms  12.529 ms
-- 内存 0.3 72.3 MB



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
-- times: 136.7 ms  166.143 m  157.184 ms
-- 连续查询 46.203 ms  45.151 ms  45.131 ms
-- 内存 364.3  0.3



-- 6. 经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
SELECT symbol, time, bid, ofr FROM taq
where
	symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00')
	AND bid > 0
    AND ofr > bid
;
-- times: 1476.851 ms  1505.925 ms  1546.055 ms
-- 连续查询 1429.415 ms  1463.056 ms  1424.289 ms
-- 内存 168.3  168.3



-- 7. 经典查询：按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，查询 (各个股票 每分钟) [平均变化幅度]
SELECT avg( (ofr - bid) / (ofr + bid) ) * 2 AS spread FROM taq
WHERE
	time BETWEEN toDateTime('2007-08-01 09:30:00') AND toDateTime('2007-08-01 16:00:00')
	AND bid > 0
  AND ofr > bid
GROUP BY symbol, toStartOfMinute(time) as minute
;
-- times: 6579.806 ms  6561.861 ms  6793.162 ms
-- 连续查询 6143.717 ms 5999.691 ms  6455.538 ms
-- 内存 1,537.6  1,423.1



-- 8. 经典查询：计算某天 (每个股票 每分钟) 最大卖出与最小买入价之差
SELECT max(ofr) - min(bid) AS gap
FROM taq
WHERE
	date IN toDate('2007-08-03')
	AND bid > 0
	AND ofr > bid
GROUP BY symbol, toStartOfMinute(time) AS minute
;
-- times: 4413.58 ms  4313.455 ms  4344.721 ms
-- 连续查询 4057.016 ms 4058.613 ms 4145.638 ms
-- 内存 	5,040.6  3,888.5



-- 9. 经典查询：按 [股票代码、日期段、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价
SELECT avg(ofr + bid) / 2.0 AS avg_price
FROM taq
WHERE
	symbol = 'IBM'
	AND date BETWEEN toDate('2007-08-01') AND toDate('2007-08-07')
    AND ((toHour(time) AS hour BETWEEN 10 AND 16) OR (hour = 9 AND toMinute(time) >= 30)
-- 	AND time BETWEEN 09:30:00 : 16:00:00
GROUP BY date, toStartOfMinute(time) AS minute
;
-- times: 146.258 ms 133.078 ms  177.921 ms
-- 连续查询 28.464 ms  23.873 ms  24.132 ms
-- 内存 196.3 308.3



-- 10. 经典查询：按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价
select avg(ofr + bid) / 2.0 as avg_price
from taq
where
	date between 2007.08.05 : 2007.08.07,
	time between 09:30:00 : 16:00:00
group by symbol, date
-- times: 11138.148 ms  3845.77 ms  3991.298 ms
-- 连续查询 1961.145 ms  2068.212 ms  1993.328 ms
-- 内存 8,962.8  11,900.9



-- 11. 经典查询：计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序
select wavg(bid, bidsiz) as vwab
from taq
where date between 2007.08.05 : 2007.08.06
group by date, symbol
	having sum(bidsiz) > 0
order by date desc, symbol
-- times: 2664.635 ms  1357.005 ms 1465.089 ms
-- 连续查询 676.901 ms  630.876 ms  632.98 ms
-- 内存 3,322.5  4,240.6
