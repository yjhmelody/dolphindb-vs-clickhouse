from clickhouse_driver import Client
import pandas as pd
import numpy as np
from typing import *

import time

# 13344ms 13286ms 13157ms 
# 13480ms 13682ms 
if __name__ == '__main__':
    client = Client(host='115.239.209.224', port=19001)
    start = time.time()

    symbols_top = client.execute('''
    SELECT symbol, count(*) FROM taq5
    WHERE
        toDate(time) = '2007-08-01'
        AND toYYYYMMDDhhmmss(time) % 1000000 BETWEEN 093000 AND 155959
        AND 0 < bid
        AND bid < ofr
        AND ofr < bid*1.2
    GROUP BY symbol
    ORDER BY count(*) DESC
    LIMIT 500
    ''')

    symbols: List[str] = [symbol for (symbol, count) in symbols_top]

    sym_str = 'AND symbol in ('
    for i in range(0, len(symbols)-1):
        sym_str +=  "'"+ symbols[i] + "'" + ','

    sym_str += "'" + symbols[len(symbols) - 1] + "'" + ')'
    data: List = client.execute(
        '''
        SELECT symbol, floor(toYYYYMMDDhhmmss(time) % 10000 / 100) AS minute, avg(bid + ofr)/2.0 AS price FROM taq5
        WHERE
            toDate(time) = '2007-08-01'
            -- AND symbol in syms
            AND 0 < bid
            AND bid < ofr
            AND ofr < bid*1.2
            AND toYYYYMMDDhhmmss(time) % 1000000 BETWEEN 93000 AND 155959
        '''
        + sym_str +
        '''
        group by (minute, symbol)
        '''
    )

    symbol = [symbol for (symbol, _, _) in data]
    minute = [minute for (_, minute, _) in data]
    price = [price for (_, _, price) in data]

    df = pd.DataFrame({
        'symbol': symbol,
        'minute': minute,
        'price': price
    })

    print(df.pivot(index='minute', columns='symbol', values='price'))
    end = time.time()
    print(end - start)