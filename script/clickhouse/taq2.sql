-- 7节点
SELECT * FROM system.clusters;
SELECT * FROM system.zookeeper WHERE path = '/clickhouse';
SELECT memory_usage, query, peak_memory_usage FROM system.processes;


DROP TABLE IF EXISTS taq_local;
DROP TABLE IF EXISTS taq;

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
ORDER BY (toYYYYMMDD(time), symbol)
SETTINGS index_granularity=8192;

CREATE TABLE IF NOT EXISTS taq AS taq_local
ENGINE = Distributed(cluster_7shard_1replicas, default, taq_local, rand());

-------------------------- 第二种分区---------------------------------

DROP TABLE IF EXISTS taq_local2;
DROP TABLE IF EXISTS taq2;

CREATE TABLE IF NOT EXISTS taq_local2 (
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

CREATE TABLE IF NOT EXISTS taq2 AS taq_local2
ENGINE = Distributed(cluster_7shard_1replicas, default, taq_local2, rand());


-------------------------- 第三种分区---------------------------------

DROP TABLE IF EXISTS taq_local3;
DROP TABLE IF EXISTS taq3;

CREATE TABLE IF NOT EXISTS taq_local3 (
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
ORDER BY symbol
SETTINGS index_granularity=8192;

CREATE TABLE IF NOT EXISTS taq3 AS taq_local3
ENGINE = Distributed(cluster_7shard_1replicas, default, taq_local3, rand());

-------------------------- 第四种分区---------------------------------

DROP TABLE IF EXISTS taq_local4;
DROP TABLE IF EXISTS taq4;

CREATE TABLE IF NOT EXISTS taq_local4 (
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
ORDER BY symbol
SETTINGS index_granularity=8192;

CREATE TABLE IF NOT EXISTS taq4 AS taq_local4
ENGINE = Distributed(cluster_7shard_1replicas, default, taq_local4, toYYYYMMDD(time));

------------------------------------------------------------------------

INSERT INTO taq_local VALUES ('A', '2007-08-01', '2007-08-01 06:24:34', 1, 0, 1, 0, 12,'P', NULL);

SELECT * FROM taq_local ORDER BY time ASC;

SELECT * FROM taq ORDER BY time ASC;

--- 查看内存占用
select value / 1024 / 1024 / 1024 from system.metrics
where metric = 'MemoryTracking';

--------------------------------- 查询 ------------------------------------------

-- 0. 数量查询
-- 数量： 10486785993

SELECT count(*) FROM taq;
-- 一次: 11.985s 12.487s 12.106s
-- 连续查询 687ms 676ms 665ms

SELECT count(*) FROM taq2;
-- 一次: 14.938s 14.847s 15.708s
-- 连续 631ms 643ms 644ms

SELECT count(*) FROM taq3;
-- 一次: 10.051s 10.553s 10.177s
-- 连续 660ms 634ms 658ms

SELECT count(*) FROM taq4;
-- 一次: 13.955s 14.127s 13.386s
-- 连续 641ms 638ms 634ms


-- 1. 点查询：按股票代码、时间查询
SELECT * FROM taq WHERE symbol = 'IBM' AND toDate(time) = '2007-08-07';
-- 一次: 1.935s
-- 连续查询 1.737s 1.762s 1.902s

SELECT * FROM taq2 WHERE symbol = 'IBM' AND toDate(time) = '2007-08-07';
-- 一次: 286ms 328ms 289ms
-- 连续 237ms 210ms 187ms

SELECT * FROM taq3 WHERE symbol = 'IBM' AND toDate(time) = '2007-08-07';
-- 一次: 1.452s 899ms
-- 连续 170ms 174ms 167ms

SELECT * FROM taq4 WHERE symbol = 'IBM' AND toDate(time) = '2007-08-07';
-- 一次: 1.431s 493ms
-- 连续  210ms 222ms 218ms


-- 2. 范围查询：查询某时间段内的某些股票的所有记录
SELECT symbol, time, bid, ofr FROM taq WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 10.138s  9.601s  9.647s
-- 连续查询 9.686s

SELECT symbol, time, bid, ofr FROM taq2 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 690ms 626ms 756ms
-- 连续 442ms 397ms 430ms

SELECT symbol, time, bid, ofr FROM taq3 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 1.109s 900ms
-- 连续 408ms 399ms 416ms

SELECT symbol, time, bid, ofr FROM taq4 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 1.451s 578ms
-- 连续 364ms 341ms 360ms



--- 可能需要重新测试
-- 3. top 1000 + 排序: 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序
SELECT * FROM taq WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= '2007-08-07 07:36:37' AND time < '2007-08-08 00:00:00' AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 402ms
-- 连续查询 90ms 88ms 99ms

SELECT * FROM taq2 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 554ms 526ms 426ms
-- 连续 98ms 88ms 85ms

SELECT * FROM taq3 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 721ms 837ms 1.327s
-- 连续 84ms 83ms 85ms

SELECT * FROM taq4 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 1.132s 921ms
-- 连续 130ms 104ms 104ms


-- 4. 聚合查询. 单分区维度
SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 625ms
-- 连续查询 102ms 99ms 99ms

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq2 WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 100ms 98ms
-- 连续 38ms 35ms 37ms

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq3 WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 104ms 392ms
-- 连续  34ms 36ms 37ms

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq4 WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 145ms 130ms 230ms
-- 连续 31ms 35ms 36ms



-- 5. 聚合查询.多分区维度 + 排序
SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq WHERE time BETWEEN toDateTime('2007-08-07 09:00:00')  AND toDateTime('2007-08-07 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次:  112ms
-- 连续查询 77ms 68ms 84ms

SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq2 WHERE time BETWEEN toDateTime('2007-08-07 09:00:00')  AND toDateTime('2007-08-07 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 162ms 109ms 296ms
-- 连续 141ms 104ms 134ms

SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq3 WHERE time BETWEEN toDateTime('2007-08-07 09:00:00')  AND toDateTime('2007-08-07 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 180ms 214ms
-- 连续 98ms 94ms 93ms

SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq4 WHERE time BETWEEN toDateTime('2007-08-07 09:00:00')  AND toDateTime('2007-08-07 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 572ms 191ms
-- 连续 97ms 159ms 147ms



-- 6. 经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
SELECT symbol, time, bid, ofr FROM taq where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 0.223s
-- 连续查询 17ms 18ms 20ms

SELECT symbol, time, bid, ofr FROM taq2 where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 194ms 201ms 195ms
-- 连续 196ms 183ms 186ms

SELECT symbol, time, bid, ofr FROM taq3 where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 160ms 307ms
-- 连续 163ms 177ms 206ms

SELECT symbol, time, bid, ofr FROM taq4 where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 377ms 236ms  296ms
-- 连续 204ms 214ms 198ms



--- 7. 窗口函数查询：查询某种股票某天时间的差值（s)
SELECT symbol, time, runningDifference(time) AS time_diff FROM taq WHERE symbol = 'YHOO' AND date = '2007-08-07' ORDER BY time ASC
-- 一次: 4.319s
-- 连续查询  278ms 246ms 263ms

SELECT symbol, time, runningDifference(time) AS time_diff FROM taq2 WHERE symbol = 'YHOO' AND date = '2007-08-07' ORDER BY time ASC
-- 一次: 423ms 318ms 297ms
-- 连续  172ms 238ms 196ms

SELECT symbol, time, runningDifference(time) AS time_diff FROM taq3 WHERE symbol = 'YHOO' AND date = '2007-08-07' ORDER BY time ASC
-- 一次: 468ms 541ms 268ms
-- 连续  203ms 186ms 188ms

SELECT symbol, time, runningDifference(time) AS time_diff FROM taq4 WHERE symbol = 'YHOO' AND date = '2007-08-07' ORDER BY time ASC
-- 一次: 635ms 400ms 402ms
-- 连续  217ms 227ms 193ms


-- 8. 经典查询：计算某天 (每个股票 每分钟) 最大卖出与最小买入价之差
SELECT max(ofr) - min(bid) AS gap FROM taq WHERE toDate(time) IN '2007-08-03' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 26.899s  26.597s  25.920s
-- 连续查询  7.736s 7.420s 8.156s

SELECT max(ofr) - min(bid) AS gap FROM taq2 WHERE toDate(time) IN '2007-08-03' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 59.279s 57.330s 58.140s
-- 连续 5.226s 5.262s 5.312s

SELECT max(ofr) - min(bid) AS gap FROM taq3 WHERE toDate(time) IN '2007-08-03' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 43.342s 42.274s 40.171s
-- 连续 5.312s 5.199s 5.249s

SELECT max(ofr) - min(bid) AS gap FROM taq4 WHERE toDate(time) IN '2007-08-03' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 28.794s 30.370s 30.184s
-- 连续 4.475s 4.508s 4.378s



--------------------------------------- 下面逻辑需要改写 -----------------------------------------


-- 经典查询：按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，查询 (各个股票 每分钟) [平均变化幅度]
SELECT avg( (ofr - bid) / (ofr + bid) ) * 2 AS spread FROM taq
WHERE
	time BETWEEN toDateTime('2007-08-01 09:30:00') AND toDateTime('2007-08-01 16:00:00')
	AND bid > 0
  AND ofr > bid
GROUP BY symbol, toStartOfMinute(time) as minute
;
-- 一次:
-- 连续查询




-- 经典查询：按 [股票代码、日期段、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价
SELECT avg(ofr + bid) / 2.0 AS avg_price
FROM taq
WHERE
	symbol = 'IBM'
	AND toDate(time) BETWEEN toDate('2007-08-01') AND toDate('2007-08-07')
    AND ((toHour(time) AS hour BETWEEN 10 AND 16) OR (hour = 9 AND toMinute(time) >= 30)
-- 	AND time BETWEEN 09:30:00 : 16:00:00
GROUP BY date, toStartOfMinute(time) AS minute
;
-- 一次:
-- 连续查询



-- 经典查询：按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价
SELECT avg(ofr + bid) / 2.0 AS avg_price
FROM taq
WHERE
	time BETWEEN '2007-08-05 09:30:00' AND '2007-08-07 16:00:00'
GROUP BY symbol, toYYYYMMDD(time)
;
-- 一次:
-- 连续查询



-- 经典查询：计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序
-- 没有wavg
select wavg(bid, bidsiz) as vwab
from taq
where toDate(time) between '2007-08-05'  AND '2007-08-06'
group by toDate(time), symbol
	having sum(bidsiz) > 0
order by toDate(time) desc, symbol
-- 一次:
-- 连续查询