# Dokcer 环境下并发导入脚本

load_csv() {
    starttime="$i start time:"$(date +%Y-%m-%d\ %H:%M:%S)
    echo $starttime 
    echo $starttime >> time.txt

    for filename in /hdd/hdd$1/data/*.csv; do
        echo "loading $filename ..."
        sudo docker run -it yandex/clickhouse-client --use_client_time_zone true --host $clickhouseip --port 1900$1 --query="INSERT INTO taq FORMAT CSV" < $filename
    done

    endtime="$i end time:"$(date +"%Y-%m-%d %H:%M:%S")
    echo $endtime 
    echo $endtime >> time.txt
}


load_csv2() {
    for i in 1 2 3 4 5 6 7; do
        sudo load_csv $i &
    done
}

load_csv2