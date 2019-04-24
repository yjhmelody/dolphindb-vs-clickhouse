for filename in TAQ/*.csv; do
        python3 csv_transfer.py $filename > NEW_TAQ/$filename
done 
