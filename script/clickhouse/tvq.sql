USE TAQ;

DROP TABLE IF EXISTS taq_local;
DROP TABLE IF EXISTS taq_all;

-- 对于 CREATE， DROP， ALTER，以及RENAME查询，系统支持其运行在整个集群上
-- MergeTree() 参数
--     date-column — 类型为 Date 的列名。ClickHouse 会自动依据这个列按月创建分区。分区名格式为 "YYYYMM" 。
--     sampling_expression — 采样表达式。
--     (primary, key) — 主键。类型 — Tuple()
--     index_granularity — 索引粒度。即索引中相邻『标记』间的数据行数。设为 8192 可以适用大部分场景。


USE TAQ;
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
CREATE TABLE taq_all AS taq_local
ENGINE = Distributed(cluster_2shard_2replicas, default, taq_local, rand());

INSERT INTO taq_local VALUES ('A', '2007-08-01', toDateTime('2007-08-01 06:24:34' , 'UTC'), 1, 0, 1, 0, 12,'P', NULL);

INSERT INTO taq_local VALUES ('A', '2007-08-01', '2017-08-01 06:24:34', 1, 0, 1, 0, 12,'P', NULL);


SELECT * FROM taq_local;
-- symbol,date,time,bid,ofr,bidsiz,ofrsiz,mode,ex,mmid
-- A,20070801,6:24:34,1,0,  1,      0,     12,  P,



--------- 查询



-- 1. 点查询：按股票代码、时间查询