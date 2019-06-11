import os
import csv
import random
from typing import *
import io


def rand_csv_data(row_num: int, int_col_num: int):
    date = '2019-01-01'
    rand_string = ["A", "BB", "CCC", "DDDD", "EEEEE", "FFFFFF", "GGGGGGG"]
    rows = []
    for i in range(row_num):
        char_ = random.randint(0, min([2 ** 7 - 1, row_num]))
        short_ = random.randint(0, min([2 ** 15 - 1, row_num]))
        int_ = random.randint(0, min([2 ** 31 - 1, row_num]))
        long_ = random.randint(0, min([2 ** 63 - 1, row_num]))
        float_ = random.random()
        double_ = random.random()
        string_ = random.choice(rand_string)
        null_int_ = random.choice([0, 1])
        if null_int_ == 0:
            null_int_ = random.randint(0, min([2 ** 63 - 1, row_num]))
        else:
            null_int_ = "\\N"

        rows.append([char_, short_, int_, long_, float_, double_, string_, null_int_])

        for j in range(int_col_num):
            rows[i].append(random.randint(0, min([2 ** 63 - 1, row_num])))
    return rows


def write_csv(path: str, rows: List):
    with open(path, 'w') as file:
        writer = csv.writer(file)
        writer.writerows(rows)



if __name__ == '__main__':
    col_num = 1000000
    int_num = 50

    rows = rand_csv_data(col_num, int_num)
    write_csv('../temp/rand.csv', rows)