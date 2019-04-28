-- 6节点

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
PARTITION BY toYYYYMMDD(time)
ORDER BY (toYYYYMMDD(time), symbol)
SETTINGS index_granularity=8192;


-- 创建分布式表
CREATE TABLE IF NOT EXISTS taq AS taq_local
ENGINE = Distributed(cluster_8shard_1replicas, default, taq_local, rand());


INSERT INTO taq_local VALUES ('A', '2007-08-01', '2007-08-01 06:24:34', 1, 0, 1, 0, 12,'P', NULL);

SELECT * FROM taq_local ORDER BY time ASC;

SELECT * FROM taq ORDER BY time ASC;



--- 查看内存占用
select value / 1024 / 1024 / 1024 from system.metrics
where metric = 'MemoryTracking';


--------------------------------- 查询 ------------------------------------------
SELECT count(*) FROM taq;
-- 23s 546ms 
-- 11.985s 12.487s 12.106s
-- 连续查询 687ms 676ms 665ms



--- 窗口函数查询：查询某种股票时间的差值（s)
SELECT symbol, time, runningDifference(time) AS time_diff FROM taq WHERE symbol = 'YHOO' AND date = '2007-08-07' ORDER BY time ASC
;
-- times: 4.319s
-- 连续查询  278ms 246ms 263ms



-- 1. 点查询：按股票代码、时间查询
SELECT * FROM taq WHERE symbol = 'IBM' AND date = '2007-08-07';
-- times: 967ms
-- 连续查询  236ms 253ms 260ms



-- 2. 范围查询：查询某时间段内的某些股票的所有记录
SELECT symbol, time, bid, ofr FROM taq WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND toDate(time) BETWEEN '2007-08-03' AND '2007-08-07' AND bid > 20
;
----- or 
SELECT symbol, time, bid, ofr FROM taq
WHERE
	symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO')
	AND toYYYYMMDD(time) BETWEEN 20070803 AND 20070807
	AND bid > 20
;
-- times: 4.670s
-- 连续查询 485ms 491ms 486ms



-- 3. top 1000 + 排序: 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序
SELECT * FROM taq WHERE symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND date = toDate('2007-08-07') AND time >= toDateTime('2007-08-07 07:36:37') AND time < toDateTime('2007-08-08 00:00:00') AND ofr > bid ORDER BY (ofr - bid) DESC LIMIT 1000
;
-- times: 402ms
-- 连续查询 90ms 88ms 99ms



-- 4. 聚合查询. 单分区维度
SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq WHERE toDate(time) = toDate('2007-08-02') AND symbol = 'IBM' AND ofr > bid GROUP BY toStartOfMinute(time)
;
---- or
SELECT max(bid) as max_bid, min(ofr) AS min_ofr FROM taq
WHERE
	toYYYYMMDD(time) = 20070802
	AND symbol = 'IBM'
	AND ofr > bid
GROUP BY toStartOfMinute(time)
;
-- times: 625ms
-- 连续查询 102ms 99ms 99ms




-- 5. 聚合查询.多分区维度 + 排序
SELECT stddevPop(bid) AS std_bid, sum(bidSiz) AS sum_bidsiz FROM taq WHERE time BETWEEN toDateTime('2007-08-07 09:00:00')  AND toDateTime('2007-08-07 21:00:00') AND symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND bid >= 20 AND ofr > 20 GROUP BY symbol, toStartOfMinute(time) AS minute_time ORDER BY symbol ASC , minute_time ASC
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
-- times:  112ms
-- 连续查询 77ms 68ms 84ms




-- 6. 经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
SELECT symbol, time, bid, ofr FROM taq where symbol IN ('IBM', 'MSFT', 'GOOG', 'YHOO') AND time BETWEEN '2007-08-03 09:30:00' AND '2007-08-03 14:30:00' AND bid > 0 AND ofr > bid
;
-- times: 0.223s
-- 连续查询 17ms 18ms 20ms




-- 8. 经典查询：计算某天 (每个股票 每分钟) 最大卖出与最小买入价之差
SELECT max(ofr) - min(bid) AS gap FROM taq WHERE toDate(time) IN toDate('2007-08-03') AND bid > 0 AND ofr > bid GROUP BY symbol, toStartOfMinute(time) AS minute
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
-- times: 26ms 899ms   26s 597ms   25s 920ms
-- 连续查询  7.736s 7.420s 8.156s





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
