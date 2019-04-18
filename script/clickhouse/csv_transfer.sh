for filename in ./*.csv; do
        python3.7 csv_transfer.py $filename > ../NEW_TAQ/$filename
done 
