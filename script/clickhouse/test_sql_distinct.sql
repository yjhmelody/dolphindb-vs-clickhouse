DROP TABLE IF EXISTS tbl;

CREATE TABLE IF NOT EXISTS tbl (
    char Int8,
    short Int16,
    int Int32,
    long Int64,
    float Float32,
    double Float64,
    string String,
    nullInt Nullable(Int32),
    int1 Int32,
    int2 Int32,
    int3 Int32,
    int4 Int32,
    int5 Int32,
    int6 Int32,
    int7 Int32,
    int8 Int32,
    int9 Int32,
    int10 Int32,
    int11 Int32,
    int12 Int32,
    int13 Int32,
    int14 Int32,
    int15 Int32,
    int16 Int32,
    int17 Int32,
    int18 Int32,
    int19 Int32,
    int20 Int32,
    int21 Int32,
    int22 Int32,
    int23 Int32,
    int24 Int32,
    int25 Int32,
    int26 Int32,
    int27 Int32,
    int28 Int32,
    int29 Int32,
    int30 Int32,
    int31 Int32,
    int32 Int32,
    int33 Int32,
    int34 Int32,
    int35 Int32,
    int36 Int32,
    int37 Int32,
    int38 Int32,
    int39 Int32,
    int40 Int32,
    int41 Int32,
    int42 Int32,
    int43 Int32,
    int44 Int32,
    int45 Int32,
    int46 Int32,
    int47 Int32,
    int48 Int32,
    int49 Int32,
    int50 Int32
) ENGINE = MergeTree()
ORDER BY tuple()
SETTINGS index_granularity=8192;

-- simple

SELECT DISTINCT char FROM tbl;

SELECT DISTINCT short FROM tbl;

SELECT DISTINCT int FROM tbl;

SELECT DISTINCT long FROM tbl;

SELECT DISTINCT float FROM tbl;

SELECT DISTINCT double FROM tbl;

SELECT DISTINCT string FROM tbl;

SELECT DISTINCT nullInt FROM tbl;

-- compo

SELECT DISTINCT char, short, int FROM tbl;

SELECT DISTINCT int, long, double FROM tbl;

SELECT DISTINCT short, int, long, float, double, nullInt FROM tbl;

SELECT DISTINCT string, int FROM tbl;

SELECT DISTINCT
    int1,
    int2,
    int3,
    int4,
    int5,
    int6,
    int7,
    int8,
    int9,
    int10
    FROM tbl;

SELECT DISTINCT
    int1,
    int2,
    int3,
    int4,
    int5,
    int6,
    int7,
    int8,
    int9,
    int10,
    int11,
    int12,
    int13,
    int14,
    int15,
    int16,
    int17,
    int18,
    int19,
    int20
    FROM tbl;


SELECT DISTINCT
    int1,
    int2,
    int3,
    int4,
    int5,
    int6,
    int7,
    int8,
    int9,
    int10,
    int11,
    int12,
    int13,
    int14,
    int15,
    int16,
    int17,
    int18,
    int19,
    int20,
    int21,
    int22,
    int23,
    int24,
    int25,
    int26,
    int27,
    int28,
    int29,
    int30,
    int31,
    int32,
    int33,
    int34,
    int35,
    int36,
    int37,
    int38,
    int39,
    int40,
    int41,
    int42,
    int43,
    int44,
    int45,
    int46,
    int47,
    int48,
    int49,
    int50
    FROM tbl;