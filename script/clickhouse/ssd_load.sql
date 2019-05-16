DROP TABLE IF EXISTS taq_local5;
DROP TABLE IF EXISTS taq5;

CREATE TABLE IF NOT EXISTS test_table_local (
    date Date,
    id FixedString(2),
) ENGINE = MergeTree()
PARTITION BY date
ORDER BY symbol
SETTINGS index_granularity=8192;

CREATE TABLE IF NOT EXISTS test_table_local AS test_table 
ENGINE = Distributed(cluster_7shard_1replicas, default, test_table_local, toYYYYMMDD(time));


login(`admin,`123456)
dbName = "dfs://db9"
tableName = "mt1"

ids= symbol(string(1..30))
days = 2019.01.01..2019.01.30

maxtricNum = 270
colNames = [`date,`id]
colTypes= [DATE,STRING]
for(i in 1..maxtricNum){
	colNames.append!("p" + string(i))
	colTypes.append!(LONG)
}


db1=database("",VALUE,days)
db2=database("",VALUE,ids)
db=database(dbName,COMPO,[db1,db2])
t = table(100:100,colNames,colTypes)
createPartitionedTable(db,t,tableName,`date`id)


n = 1000
basicTable = table(n:n,colNames,colTypes)
basicTable[`id] = take(ids,n)

for(i in 2..(colNames.size()-1)){
	basicTable[colNames[i]] = i*i
}

for(i in 1..100){
	basicTable[`date] = 2019.01.01
	database(dbName).loadTable(tableName).append!(basicTable)	
}