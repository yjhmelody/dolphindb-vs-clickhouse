--------------------------- 7节点 ---------------------------------------
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


-------------------------- 第五种分区---------------------------------

DROP TABLE IF EXISTS taq_local5;
DROP TABLE IF EXISTS taq5;

CREATE TABLE IF NOT EXISTS taq_local5 (
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

CREATE TABLE IF NOT EXISTS taq5 AS taq_local5
ENGINE = Distributed(cluster_7shard_1replicas, default, taq_local5, toYYYYMMDD(time));

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
-- ok
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

SELECT count(*) FROM taq5;
-- 一次: 14.674s 13.743s 16.689s
-- 连续 661ms 649ms 646ms


-- ok
-- 1. 点查询：按股票代码、时间查询
SELECT * FROM taq WHERE symbol = 'IBM' AND toDate(time) = '2007-09-07';
-- 一次: 6.740s 4.975s 6.825s
-- 连续查询 232ms 235ms 222ms

SELECT * FROM taq2 WHERE symbol = 'IBM' AND toDate(time) = '2007-09-07';
-- 一次: 556ms 613ms 642ms
-- 连续 228ms 215ms  208ms

SELECT * FROM taq3 WHERE symbol = 'IBM' AND toDate(time) = '2007-09-07';
-- 一次: 539ms 428ms 474ms
-- 连续 213ms 186ms 198ms

SELECT * FROM taq4 WHERE symbol = 'IBM' AND toDate(time) = '2007-09-07';
-- 一次: 482ms 443ms 531ms
-- 连续  210ms 170ms 215ms

SELECT * FROM taq5 WHERE symbol = 'IBM' AND toDate(time) = '2007-09-07';
-- 一次: 810ms 625ms 677ms
-- 连续  198ms 193ms 195ms



--- ok
-- 2. 范围查询：查询某时间段内的某些股票的所有记录
SELECT symbol, time, bid, ofr FROM taq WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 8.193s 8.017s 8.192s
-- 连续查询 679ms 464ms 440ms

SELECT symbol, time, bid, ofr FROM taq2 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 1.153s 0.796s 1.212s
-- 连续 442ms 397ms 430ms

SELECT symbol, time, bid, ofr FROM taq3 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 1.158s 1.149s 968ms
-- 连续 408ms 399ms 416ms

SELECT symbol, time, bid, ofr FROM taq4 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 988ms 893ms 817ms
-- 连续 364ms 341ms 360ms

SELECT symbol, time, bid, ofr FROM taq5 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
-- 一次: 868ms 976ms 1061ms
-- 连续 354ms 366ms 433ms


-- ok
-- 3. top 1000 + 排序: 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序
SELECT * FROM taq WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 777ms 857ms 644ms
-- 连续查询 104ms 92ms 88ms

SELECT * FROM taq2 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 1.093s 1.117s 1.140s
-- 连续 104ms 101ms 118ms

SELECT * FROM taq3 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 1.327s 1.152s 1.249s
-- 连续 93ms 108ms 94ms

SELECT * FROM taq4 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 1.132s 1.254s 1.124s
-- 连续 120ms 140ms 121ms

SELECT * FROM taq5 WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
-- 一次: 956ms 640ms 808ms
-- 连续 94ms 98ms 98ms



-- ok
-- 4. 聚合查询. 单分区维度
SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 4.593s 4.985s 5.092s
-- 连续查询 102ms 99ms 99ms

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq2 WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 486ms 389ms 371ms
-- 连续 38ms 35ms 37ms

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq3 WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 392ms 432ms 343ms
-- 连续  34ms 36ms 37ms

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq4 WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 230ms 253ms 293ms
-- 连续 31ms 35ms 36ms

SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq5 WHERE toDate(time) = '2007-08-02' AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
-- 一次: 135ms 126ms 189ms
-- 连续 37ms 45ms 43ms



-- ok
-- 5. 聚合查询.多分区维度 + 排序
SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq WHERE time BETWEEN toDateTime('2007-09-10 09:00:00')  AND toDateTime('2007-09-11 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 743ms 962ms 934ms
-- 连续查询 102ms 101ms 103ms

SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq2 WHERE time BETWEEN toDateTime('2007-09-10 09:00:00')  AND toDateTime('2007-09-11 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 850ms 762ms 809ms
-- 连续 177ms 134ms 109ms

SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq3 WHERE time BETWEEN toDateTime('2007-09-10 09:00:00')  AND toDateTime('2007-09-11 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 803ms 549ms 879ms
-- 连续 139ms 185ms 115ms

SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq4 WHERE time BETWEEN toDateTime('2007-09-10 09:00:00')  AND toDateTime('2007-09-11 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 773ms 767ms 742ms
-- 连续 116ms 145ms 189ms

SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq5 WHERE time BETWEEN toDateTime('2007-09-10 09:00:00')  AND toDateTime('2007-09-11 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
-- 一次: 545ms 509ms 450ms
-- 连续  115ms 127ms 104ms



-- ok
-- 6. 经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
SELECT symbol, time, bid, ofr FROM taq where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 399ms 402ms 466ms
-- 连续查询 181ms 199ms 204ms

SELECT symbol, time, bid, ofr FROM taq2 where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 746ms 688ms 746ms
-- 连续 196ms 183ms 186ms

SELECT symbol, time, bid, ofr FROM taq3 where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 754ms 702ms 758ms
-- 连续 230ms 229ms 247ms

SELECT symbol, time, bid, ofr FROM taq4 where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 630ms 616ms 671ms
-- 连续 221ms 207ms 243ms

SELECT symbol, time, bid, ofr FROM taq5 where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN toDateTime('2007-08-03 09:30:00') AND toDateTime('2007-08-03 14:30:00') AND bid > 0 AND ofr > bid
-- 一次: 337ms 206ms 280ms
-- 连续  220ms 220ms 227ms



-- ok
--- 7. 窗口函数查询：查询某种股票某天时间的差值（s)
SELECT symbol, time, runningDifference(time) AS time_diff FROM taq WHERE symbol = 'YHOO' AND date = '2007-09-04' ORDER BY time ASC
-- 一次: 4.910s 4.745s 4.791s
-- 连续查询 245ms 260ms 239ms

SELECT symbol, time, runningDifference(time) AS time_diff FROM taq2 WHERE symbol = 'YHOO' AND date = '2007-09-04' ORDER BY time ASC
-- 一次: 621ms 413ms 800ms
-- 连续  202ms 208ms 235ms

SELECT symbol, time, runningDifference(time) AS time_diff FROM taq3 WHERE symbol = 'YHOO' AND date = '2007-09-04' ORDER BY time ASC
-- 一次: 693ms 474ms 878ms
-- 连续  215ms 217ms 198ms

SELECT symbol, time, runningDifference(time) AS time_diff FROM taq4 WHERE symbol = 'YHOO' AND date = '2007-09-04' ORDER BY time ASC
-- 一次: 705ms 696ms 641ms
-- 连续 209ms 263ms 253ms

SELECT symbol, time, runningDifference(time) AS time_diff FROM taq5 WHERE symbol = 'YHOO' AND date = '2007-09-04' ORDER BY time ASC
-- 一次: 733ms 511ms 834ms
-- 连续 209ms 196ms 209ms


-- 8. 经典查询：计算某天 (每个股票 每分钟) 最大卖出与最小买入价之差
SELECT max(ofr) - min(bid) AS gap FROM taq WHERE toDate(time) IN '2007-08-01' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 34.322s 46.427s 33.590s
-- 连续查询  4.639s 4.682s 4.681s

SELECT max(ofr) - min(bid) AS gap FROM taq2 WHERE toDate(time) IN '2007-08-01' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 46.121s 50.465s 47.635s
-- 连续 5.209s 5.213s 5.263s

SELECT max(ofr) - min(bid) AS gap FROM taq3 WHERE toDate(time) IN '2007-08-01' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 41.539s 37.914s 40.033s
-- 连续 5.293s 5.205s 5.232s

SELECT max(ofr) - min(bid) AS gap FROM taq4 WHERE toDate(time) IN '2007-08-01' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 34.976s 33.037s 32.784s
-- 连续 4.910s 4.784s 4.669s

SELECT max(ofr) - min(bid) AS gap FROM taq5 WHERE toDate(time) IN '2007-08-01' AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
-- 一次: 22.295s 22.966s 24.186s
-- 连续 4.500s 4.472s 4.465s


-- 9. median 函数查询, 拿到所有股票数据后计算
SELECT median(ofr), median(bid) FROM taq4 WHERE date = '2007-08-10' AND symbol = 'IBM'
-- 一次: 334ms 313ms 308ms
-- 连续 33ms 35ms 34ms

SELECT median(ofr), median(bid) FROM taq5 WHERE date = '2007-08-10' AND symbol = 'IBM'
-- 一次: 378ms 205ms 387ms
-- 连续 45ms 43ms 43ms


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