# Homelab ELK Stack

A production-ready ELK (Elasticsearch, Logstash, Kibana) stack with Filebeat for centralized logging in a homelab environment.

## 🏗️ Architecture

- **Elasticsearch**: Search and analytics engine for log storage
- **Logstash**: Multi-pipeline log processing with device type classification
- **Kibana**: Web interface for log visualization and analysis  
- **Filebeat**: Lightweight log shipper for container logs

## 📁 Project Structure

```
elk-stack/
├── config/                   # Service configurations
│   ├── elasticsearch.yml    # Elasticsearch settings
│   ├── filebeat.yml         # Filebeat configuration
│   ├── kibana.yml           # Kibana settings
│   ├── logstash.yml         # Logstash daemon configuration
│   └── pipelines.yml        # Multi-pipeline setup
├── pipelines/               # Logstash pipeline configurations
│   ├── docker.conf         # Container log processing
│   └── main.conf           # Syslog and network log processing
├── scripts/                # Utility scripts
│   └── monitor-storage.sh  # Storage monitoring
├── templates/              # Elasticsearch index templates (future)
├── docker-compose.yml      # Main orchestration file
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Minimum 4GB RAM available for ELK stack
- Storage mounted at `/mnt/elk-storage/` (or modify paths in docker-compose.yml)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd elk-stack
   ```

2. **Create storage directories** (if using custom paths):
   ```bash
   sudo mkdir -p /mnt/elk-storage/{elasticsearch,logstash,kibana}
   sudo chown -R 1000:1000 /mnt/elk-storage/
   ```

3. **Deploy the stack**:
   ```bash
   docker-compose up -d
   ```

4. **Verify services**:
   ```bash
   # Check service status
   docker-compose ps
   
   # Check Elasticsearch health
   curl http://localhost:9200/_cluster/health?pretty
   
   # Check Logstash pipelines
   curl http://localhost:9600/_node/stats/pipelines?pretty
   ```

## 📊 Access Points

- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200
- **Logstash API**: http://localhost:9600

## 📝 Log Sources

### Current Inputs

- **Syslog**: Port 514 (UDP/TCP) - Network device logs
- **Beats**: Port 5044 - Filebeat container logs
- **GELF**: Port 12201 - Docker container logs
- **TCP JSON**: Port 5000 - Application logs

### Supported Device Types

- **Proxmox**: Virtualization platform logs
- **UniFi**: Network device logs (including CEF format)
- **Docker**: Container application logs
- **System**: SSH, kernel, systemd logs

## 🔧 Configuration

### Multi-Pipeline Architecture

The stack uses separate Logstash pipelines for optimal performance:

- **Main Pipeline** (`pipelines/main.conf`): Handles syslog and network device logs
- **Docker Pipeline** (`pipelines/docker.conf`): Processes container logs from Filebeat and GELF

### Index Strategy

Logs are organized by device type and date:
- `homelab-logs-proxmox-YYYY.MM.dd`
- `homelab-logs-unifi-YYYY.MM.dd` 
- `homelab-logs-docker-YYYY.MM.dd`
- `homelab-logs-system-YYYY.MM.dd`

## 📈 Monitoring

### Health Checks

All services include health checks:
- **Elasticsearch**: Cluster health endpoint
- **Logstash**: Node stats endpoint  
- **Kibana**: Status API endpoint
- **Filebeat**: Output test

### Storage Monitoring

Use the included script to monitor storage usage:
```bash
./scripts/monitor-storage.sh
```

## 🔒 Security

**Current Status**: Security is disabled for initial setup.

**Production Recommendations**:
- Enable X-Pack security
- Configure TLS/SSL certificates
- Set up authentication and authorization
- Implement network segmentation

## 🛠️ Management Commands

### Service Management
```bash
# Start all services
docker-compose up -d

# Stop all services  
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Restart specific service
docker-compose restart [service-name]
```

### Maintenance
```bash
# Check configuration syntax
docker-compose config

# Update images
docker-compose pull

# View pipeline statistics
curl http://localhost:9600/_node/stats/pipelines?pretty
```

## 📋 Troubleshooting

### Common Issues

1. **Elasticsearch won't start**:
   - Check available memory (minimum 1GB heap)
   - Verify storage permissions (UID 1000)
   - Check disk space

2. **Logstash parsing errors**:
   - Check pipeline logs: `docker-compose logs logstash`
   - Validate pipeline syntax
   - Review grok patterns

3. **No logs appearing**:
   - Verify log sources are sending to correct ports
   - Check Logstash input statistics
   - Confirm Elasticsearch is accepting data

### Log Locations

- **Container logs**: `docker-compose logs [service]`
- **Service logs**: Check health check endpoints
- **Pipeline errors**: Logstash container logs

## 🔄 Updates and Maintenance

### Regular Maintenance
- Monitor storage usage
- Review log retention policies  
- Update Docker images
- Check for configuration drift

### Backup Strategy
- Configuration: Version controlled in Git
- Data: Regular Elasticsearch snapshots recommended
- Monitor: Set up alerting for failures

## 🎯 Future Enhancements

- [ ] Index Lifecycle Management (ILM) policies
- [ ] Security hardening (X-Pack Security)
- [ ] Alerting and monitoring
- [ ] Additional log sources
- [ ] Performance optimization
- [ ] Backup automation

## 📚 Additional Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Logstash Documentation](https://www.elastic.co/guide/en/logstash/current/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Filebeat Documentation](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)

## 📄 License

This project is for personal/homelab use. Adjust according to your needs.