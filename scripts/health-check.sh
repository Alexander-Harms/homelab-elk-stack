#!/bin/bash

# ELK Stack Health Check Script
# Comprehensive health verification for Elasticsearch, Logstash, Kibana, and Filebeat

echo "=================================================="
echo "🔍 ELK Stack Health Check - $(date)"
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service endpoints
ELASTICSEARCH_URL="http://localhost:9200"
KIBANA_URL="http://localhost:5601"
LOGSTASH_URL="http://localhost:9600"

# Function to check if service is responding
check_service() {
    local service_name=$1
    local url=$2
    local timeout=${3:-5}
    
    echo -n "🔄 Checking $service_name... "
    if curl -s --max-time $timeout "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ ONLINE${NC}"
        return 0
    else
        echo -e "${RED}❌ OFFLINE${NC}"
        return 1
    fi
}

# Function to check Docker container status
check_container() {
    local container_name=$1
    echo -n "🐳 Checking container $container_name... "
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name.*Up"; then
        status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container_name" | awk '{print $2,$3}')
        echo -e "${GREEN}✅ $status${NC}"
        return 0
    else
        echo -e "${RED}❌ NOT RUNNING${NC}"
        return 1
    fi
}

echo -e "\n${BLUE}📦 CONTAINER STATUS${NC}"
echo "===================="
check_container "elasticsearch"
check_container "logstash" 
check_container "kibana"
check_container "filebeat"

echo -e "\n${BLUE}🌐 SERVICE CONNECTIVITY${NC}"
echo "========================="
check_service "Elasticsearch" "$ELASTICSEARCH_URL"
ELASTICSEARCH_OK=$?

check_service "Kibana" "$KIBANA_URL/api/status"
KIBANA_OK=$?

check_service "Logstash API" "$LOGSTASH_URL"
LOGSTASH_OK=$?

# Detailed Elasticsearch Health Check
if [ $ELASTICSEARCH_OK -eq 0 ]; then
    echo -e "\n${BLUE}🔍 ELASTICSEARCH DETAILED HEALTH${NC}"
    echo "===================================="
    
    # Cluster Health
    echo "📊 Cluster Health:"
    cluster_health=$(curl -s "$ELASTICSEARCH_URL/_cluster/health?pretty")
    if [ $? -eq 0 ]; then
        echo "$cluster_health" | jq -r '. | "Status: \(.status), Nodes: \(.number_of_nodes), Active Shards: \(.active_shards), Unassigned Shards: \(.unassigned_shards)"'
        
        # Check if cluster is green
        status=$(echo "$cluster_health" | jq -r '.status')
        case $status in
            "green")
                echo -e "${GREEN}✅ Cluster Status: GREEN - All good!${NC}"
                ;;
            "yellow") 
                echo -e "${YELLOW}⚠️  Cluster Status: YELLOW - Some replica shards unassigned${NC}"
                ;;
            "red")
                echo -e "${RED}❌ Cluster Status: RED - Some primary shards unassigned!${NC}"
                ;;
        esac
    else
        echo -e "${RED}❌ Failed to get cluster health${NC}"
    fi
    
    # Node Info
    echo -e "\n📡 Node Information:"
    curl -s "$ELASTICSEARCH_URL/_cat/nodes?v&h=name,heap.percent,ram.percent,cpu,load_1m,disk.used_percent,node.role"
    
    # Index Information  
    echo -e "\n📚 Index Information:"
    curl -s "$ELASTICSEARCH_URL/_cat/indices?v&h=index,health,status,docs.count,store.size&s=store.size:desc" | head -10
    
    # Recent indices with homelab logs
    echo -e "\n🏠 Homelab Log Indices:"
    curl -s "$ELASTICSEARCH_URL/_cat/indices/homelab-logs-*?v&h=index,health,docs.count,store.size&s=index:desc" | head -10
    
else
    echo -e "${RED}❌ Elasticsearch not accessible - skipping detailed checks${NC}"
fi

# Logstash Health Check
if [ $LOGSTASH_OK -eq 0 ]; then
    echo -e "\n${BLUE}⚙️  LOGSTASH HEALTH${NC}"
    echo "==================="
    
    # Pipeline Stats
    echo "📈 Pipeline Statistics:"
    pipeline_stats=$(curl -s "$LOGSTASH_URL/_node/stats/pipelines?pretty")
    if [ $? -eq 0 ]; then
        echo "$pipeline_stats" | jq -r '.pipelines | to_entries[] | "Pipeline: \(.key), Events In: \(.value.events.in), Events Out: \(.value.events.out)"'
    else
        echo -e "${RED}❌ Failed to get pipeline stats${NC}"
    fi
    
    # JVM Stats
    echo -e "\n💾 JVM Information:"
    curl -s "$LOGSTASH_URL/_node/stats/jvm?pretty" | jq -r '.jvm.mem | "Heap Used: \(.heap_used_percent)%, Non-Heap Used: \(.non_heap_used_in_bytes / 1024 / 1024 | floor)MB"'
    
else
    echo -e "${RED}❌ Logstash not accessible - skipping detailed checks${NC}"
fi

# Kibana Health Check  
if [ $KIBANA_OK -eq 0 ]; then
    echo -e "\n${BLUE}📊 KIBANA HEALTH${NC}"
    echo "================"
    
    kibana_status=$(curl -s "$KIBANA_URL/api/status")
    if [ $? -eq 0 ]; then
        overall_status=$(echo "$kibana_status" | jq -r '.status.overall.state // "unknown"')
        case $overall_status in
            "green")
                echo -e "${GREEN}✅ Kibana Status: GREEN - All services operational${NC}"
                ;;
            "yellow")
                echo -e "${YELLOW}⚠️  Kibana Status: YELLOW - Some services degraded${NC}"
                ;;
            "red")
                echo -e "${RED}❌ Kibana Status: RED - Critical services down${NC}"
                ;;
            *)
                echo -e "${YELLOW}⚠️  Kibana Status: $overall_status${NC}"
                ;;
        esac
    else
        echo -e "${RED}❌ Failed to get Kibana status${NC}"
    fi
else
    echo -e "${RED}❌ Kibana not accessible - skipping detailed checks${NC}"
fi

# Storage Check
echo -e "\n${BLUE}💾 STORAGE USAGE${NC}"
echo "================"
if [ -d "/mnt/elk-storage" ]; then
    df -h /mnt/elk-storage | awk 'NR==2 {printf "ELK Storage: %s used of %s (%s)\n", $3, $2, $5}'
    usage=$(df /mnt/elk-storage | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $usage -gt 85 ]; then
        echo -e "${RED}⚠️  WARNING: Storage usage above 85%${NC}"
    elif [ $usage -gt 70 ]; then
        echo -e "${YELLOW}⚠️  NOTICE: Storage usage above 70%${NC}"
    else
        echo -e "${GREEN}✅ Storage usage is healthy${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  ELK storage mount not found at /mnt/elk-storage${NC}"
fi

# Log ingestion test
echo -e "\n${BLUE}📝 LOG INGESTION TEST${NC}"
echo "====================="
if [ $ELASTICSEARCH_OK -eq 0 ]; then
    # Count recent documents (last hour)
    recent_docs=$(curl -s "$ELASTICSEARCH_URL/homelab-logs-*/_count?q=@timestamp:[now-1h TO now]" | jq -r '.count // 0' 2>/dev/null)
    if [[ "$recent_docs" =~ ^[0-9]+$ ]]; then
        echo "📊 Documents indexed in last hour: $recent_docs"
        if [ $recent_docs -gt 0 ]; then
            echo -e "${GREEN}✅ Log ingestion is active${NC}"
        else
            echo -e "${YELLOW}⚠️  No recent log ingestion detected${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Could not determine recent document count${NC}"
        # Fallback: show total document count for today
        today_docs=$(curl -s "$ELASTICSEARCH_URL/homelab-logs-*-$(date +%Y.%m.%d)/_count" | jq -r '.count // 0' 2>/dev/null)
        if [[ "$today_docs" =~ ^[0-9]+$ ]] && [ $today_docs -gt 0 ]; then
            echo "📊 Documents indexed today: $today_docs"
            echo -e "${GREEN}✅ Log ingestion is active (based on today's data)${NC}"
        fi
    fi
    
    # Show latest log entry
    echo -e "\n📋 Latest Log Entry:"
    latest_log=$(curl -s "$ELASTICSEARCH_URL/homelab-logs-*/_search?size=1&sort=@timestamp:desc" 2>/dev/null)
    if [ $? -eq 0 ]; then
        timestamp=$(echo "$latest_log" | jq -r '.hits.hits[0]._source["@timestamp"] // "unknown"' 2>/dev/null)
        service_name=$(echo "$latest_log" | jq -r '.hits.hits[0]._source.service.name // "unknown"' 2>/dev/null)
        device_type=$(echo "$latest_log" | jq -r '.hits.hits[0]._source.device_type // "unknown"' 2>/dev/null)
        echo "Time: $timestamp, Service: $service_name, Device: $device_type"
    else
        echo -e "${YELLOW}⚠️  Could not retrieve latest log entry${NC}"
    fi
else
    echo -e "${RED}❌ Cannot test log ingestion - Elasticsearch unavailable${NC}"
fi

# Network connectivity test
echo -e "\n${BLUE}🌐 NETWORK PORTS${NC}"
echo "================"
ports=("9200:Elasticsearch" "5601:Kibana" "9600:Logstash-API" "5044:Logstash-Beats" "1514:Syslog-Remapped" "5000:Logstash-TCP" "12201:GELF")
for port_info in "${ports[@]}"; do
    port=$(echo $port_info | cut -d: -f1)
    service=$(echo $port_info | cut -d: -f2)
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✅ Port $port ($service) is listening${NC}"
    else
        echo -e "${RED}❌ Port $port ($service) is not listening${NC}"
    fi
done

# Summary
echo -e "\n${BLUE}📋 HEALTH SUMMARY${NC}"
echo "=================="
services_ok=0
total_services=4

[ $ELASTICSEARCH_OK -eq 0 ] && ((services_ok++))
[ $LOGSTASH_OK -eq 0 ] && ((services_ok++))  
[ $KIBANA_OK -eq 0 ] && ((services_ok++))
docker ps -q -f name=filebeat | grep -q . && ((services_ok++))

echo "Services Online: $services_ok/$total_services"

if [ $services_ok -eq $total_services ]; then
    echo -e "${GREEN}🎉 All ELK stack services are healthy!${NC}"
    exit 0
elif [ $services_ok -gt 2 ]; then
    echo -e "${YELLOW}⚠️  ELK stack partially operational${NC}"
    exit 1
else
    echo -e "${RED}❌ ELK stack has critical issues${NC}"
    exit 2
fi
