#!/bin/bash
HOT_USAGE=$(df "/mnt/hot" | awk '{print $5}' | sed 's/%//')

threshold=30

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

