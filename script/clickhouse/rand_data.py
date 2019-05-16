import os
import csv
import random
from typing import *
import io

col_num = 270
sql = '''
CREATE TABLE IF NOT EXISTS test_table_local (
    %s
) ENGINE = MergeTree()
PARTITION BY date
ORDER BY symbol
SETTINGS index_granularity=8192;

CREATE TABLE IF NOT EXISTS test_table_local AS test_table
ENGINE = Distributed(cluster_7shard_1replicas, default,
                     test_table_local, toYYYYMMDD(time));
'''


def rand_csv_data(col_num, row_num):
    date = '2019-01-01'
    col_names = ['date', 'id']
    for i in range(col_num):
        col_names.append('p' + str(i))
    rows = []
    for i in range(row_num):
        id = random.randint(0, 30)
        rows.append([date, id])
        for j in range(col_num):
            rows[i].append(random.randint(0, 2 ** 20))
    return (col_names, rows)


def write_csv(path: str, col_names: List, rows: List):
    with open(path, 'w') as file:
        writer = csv.writer(file)
        writer.writerow(col_names)
        writer.writerows(rows)


def create_types(col_names: List, col_types: List):
    s = ''
    for i in range(len(col_names)):
        s += '\t' + col_names[i] + ' ' + col_types[i] + ',\n'
    return s[:-2]


def create_sql(path: str, col_names: List, col_types: List):
    s = create_types(col_names, col_types)
    with open(path, 'w') as file:
        file.write(sql % (s))


if __name__ == '__main__':
    (col_names, rows) = rand_csv_data(col_num, 1000)
    write_csv('./temp/rand.csv', col_names, rows)
    col_types = ['Date', 'FixedString(2)']
    for i in range(len(col_names) - 2):
        col_types.append('Int64')
    create_sql('./temp/autogen.sql', col_names, col_types)
