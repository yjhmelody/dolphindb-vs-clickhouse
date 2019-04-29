#!/bin/bash

# 磁盘并行读写，所以必须拷贝

TAQ_PATH=/hdd/hdd0/data/TAQ

sudo cp ${TAQ_PATH}/TAQ2007080[123678].csv /hdd/hdd1/data2/

sudo cp ${TAQ_PATH}/TAQ20070809.csv /hdd/hdd2/data2/   
sudo cp ${TAQ_PATH}/TAQ2007081[03456].csv /hdd/hdd2/data2/

sudo cp ${TAQ_PATH}/TAQ20070817.csv /hdd/hdd3/data2/
sudo cp ${TAQ_PATH}/TAQ2007082[01234].csv /hdd/hdd3/data2/

sudo cp ${TAQ_PATH}/TAQ2007082[789].csv /hdd/hdd4/data2/
sudo cp ${TAQ_PATH}/TAQ2007083[01].csv /hdd/hdd4/data2/
sudo cp ${TAQ_PATH}/TAQ20070904.csv /hdd/hdd4/data2/

sudo cp ${TAQ_PATH}/TAQ2007090[567].csv /hdd/hdd5/data2/
sudo cp ${TAQ_PATH}/TAQ2007091[012].csv /hdd/hdd5/data2/

sudo cp ${TAQ_PATH}/TAQ2007091[34789].csv /hdd/hdd6/data2/
sudo cp ${TAQ_PATH}/TAQ20070920.csv /hdd/hdd6/data2/

sudo cp ${TAQ_PATH}/TAQ2007092[145678].csv /hdd/hdd7/data2/