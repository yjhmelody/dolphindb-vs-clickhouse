#!/usr/bin/env python
import csv
import sys
import re

def load_csv(path: str, out):
    with open(path) as csv_file:
        reader = csv.reader(csv_file)
        keys = reader.__next__()

        for row in reader:
            convert_csv(row)
            out.write(','.join(row))
            out.write('\n')


def convert_csv(row: list):
    '''
    date: yyyymmdd -> yyyy-mm-dd
    time类型的hh左填充0并拼接date数据
    str添加引号
    '''
    
    date_idx = 1
    time_idx = 2
    sep = '-'
    row[date_idx] = row[date_idx][:4] + sep +  row[date_idx][4:6] + sep + row[date_idx][6:]
    row[time_idx] = row[time_idx] if row[time_idx][0] == '0' else '0' + row[time_idx]
    row[time_idx] = '"' + row[date_idx] + ' ' + row[time_idx] + '"'


if __name__ == "__main__":
    for path in sys.argv[1:]:
        load_csv(path, sys.stdout)