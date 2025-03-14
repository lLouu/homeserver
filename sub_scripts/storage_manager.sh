#!/bin/bash

## storage
HOT_USAGE=$(df "/mnt/hot" | awk '{print $5}' | sed 's/%//')

if [ "$HOT_USAGE" -ge "90" ]; then
   threshold=3
elif [ "$HOT_USAGE" -ge "80" ]; then
   threshold=8
elif [ "$HOT_USAGE" -ge "65" ]; then
   threshold=15
else
   threshold=30
fi

find "/mnt/hot" -type f -atime +$threshold -exec mv {} "/mnt/cold" \; 2>/dev/null
find "/mnt/cold" -type f -atime -$threshold -exec mv {} "/mnt/hot" \; 2>/dev/null

## temp
HOT_USAGE=$(df "/mnt/temp_hot" | awk '{print $5}' | sed 's/%//')

if [ "$HOT_USAGE" -ge "90" ]; then
   threshold=1
elif [ "$HOT_USAGE" -ge "80" ]; then
   threshold=3
elif [ "$HOT_USAGE" -ge "65" ]; then
   threshold=5
else
   threshold=7
fi

find "/mnt/temp_hot" -type f -atime +$threshold -exec mv {} "/mnt/temp_cold" \; 2>/dev/null
find "/mnt/temp_cold" -type f -atime -$threshold -exec mv {} "/mnt/temp_hot" \; 2>/dev/null

