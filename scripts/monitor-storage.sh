#!/bin/bash

# Check Proxmox mount usage
USAGE=$(df /mnt/elk-storage | awk 'NR==2 {print $5}' | sed 's/%//')
THRESHOLD=80

if [ $USAGE -gt $THRESHOLD ]; then
    echo "WARNING: ELK storage at ${USAGE}% capacity"
    # Send alert (you can add email/webhook here)
    
    # Show largest indices
    curl -s "http://192.168.1.32:9200/_cat/indices?s=store.size:desc&v" | head -10
fi

# Show current usage
echo "Current ELK storage usage: ${USAGE}%"
curl -s "http://192.168.1.32:9200/_cat/allocation?v"
