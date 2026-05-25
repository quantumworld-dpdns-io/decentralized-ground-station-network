# Redis Operations Runbook

## Overview

DGSN uses Redis 7.x for caching, session state, pub/sub messaging, and real-time telemetry. This runbook covers Sentinel-based HA and Cluster mode operations.

## Architecture

```
        +------------------+
        |   Application    |
        +--------+---------+
                 |
        +--------+---------+
        |  Redis Sentinel   |  (3 nodes, quorum=2)
        +--+----+----+-----+
           |    |    |
     +-----+ +--+--+ +-----+
     | M1  | | M2  | | M3  |  (master/replica pairs)
     | R1  | | R2  | | R3  |
     +-----+ +-----+ +-----+
```

## Sentinel Mode (Default)

### Configuration Files
- `configs/redis/redis.conf` - Redis node config
- `configs/redis/sentinel.conf` - Sentinel config

### Starting Sentinel
```bash
redis-sentinel /etc/redis/sentinel.conf
```

### Checking Sentinel Status
```bash
redis-cli -p 26379 SENTINEL masters
redis-cli -p 26379 SENTINEL replicas dgsn-master
redis-cli -p 26379 SENTINEL get-master-addr-by-name dgsn-master
```

### Manual Failover
```bash
redis-cli -p 26379 SENTINEL failover dgsn-master
```

## Cluster Mode

### Configuration Files
- `configs/redis/cluster.conf`

### Creating a Cluster
```bash
# On each node, start Redis with cluster config
redis-server /etc/redis/cluster.conf

# On one node, create the cluster (min 6 nodes)
redis-cli --cluster create \
  10.0.1.10:6379 10.0.1.11:6379 10.0.1.12:6379 \
  10.0.2.10:6379 10.0.2.11:6379 10.0.2.12:6379 \
  --cluster-replicas 1
```

### Cluster Status
```bash
redis-cli -c -a <password> CLUSTER INFO
redis-cli -c -a <password> CLUSTER NODES
redis-cli -c -a <password> CLUSTER SLOTS
```

### Resharding
```bash
redis-cli --cluster rebalance \
  --cluster-use-empty-masters \
  127.0.0.1:6379
```

### Adding a Node
```bash
redis-cli --cluster add-node \
  new-node:6379 existing-node:6379
```

## Health Checks

### Connectivity
```bash
redis-cli -a <password> PING
# Expected: PONG
```

### Replication Lag
```bash
redis-cli -a <password> INFO replication
# Check: master_repl_offset, slave_repl_offset
```

### Memory Usage
```bash
redis-cli -a <password> INFO memory
# Check: used_memory, maxmemory, evicted_keys
```

### Slow Queries
```bash
redis-cli -a <password> SLOWLOG GET 10
```

## Common Procedures

### Restarting a Sentinel Node
```bash
redis-cli -p 26379 SHUTDOWN
redis-sentinel /etc/redis/sentinel.conf
```

### Resetting Sentinel State
```bash
redis-cli -p 26379 SENTINEL RESET dgsn-master
```

### Promoting a Replica to Master (Manual)
```bash
redis-cli -p 26379 SENTINEL failover dgsn-master
# Wait for completion
redis-cli -p 26379 SENTINEL get-master-addr-by-name dgsn-master
```

### Flushing Cache (with care)
```bash
# Flush current DB only
redis-cli -a <password> FLUSHDB

# Flush all databases
redis-cli -a <password> FLUSHALL
```

## Monitoring

### Key Metrics
- `connected_clients` - Active connections
- `used_memory` / `maxmemory` - Memory pressure
- `evicted_keys` - Eviction rate (warning if >100/s)
- `repl_backlog_histlen` - Replication buffer
- `instantaneous_ops_per_sec` - Throughput
- `total_net_input_bytes` / `total_net_output_bytes` - Bandwidth

### Prometheus Integration
Redis metrics are scraped via `redis-exporter:9121` job in Prometheus.

### Grafana Dashboard
Available at `configs/grafana/dashboards/` (import manually).

## Backup and Restore

### RDB Backup
```bash
# Trigger save
redis-cli -a <password> SAVE
# Copy dump.rdb from /data directory
cp /data/dump.rdb /backup/redis/dump-$(date +%Y%m%d).rdb
```

### AOF Rewrite
```bash
redis-cli -a <password> BGREWRITEAOF
```

### Restore from RDB
```bash
# Stop Redis, replace dump.rdb, start Redis
systemctl stop redis
cp /backup/redis/dump-20240101.rdb /data/dump.rdb
systemctl start redis
```

## Troubleshooting

### High Memory Usage
```bash
# Check memory stats
redis-cli MEMORY STATS
# Find largest keys
redis-cli --bigkeys
# Consider increasing maxmemory or tuning eviction policy
```

### Replication Issues
```bash
# Check replication status
redis-cli INFO replication
# Re-sync replica
redis-cli -p 6380 REPLICAOF master-ip 6379
```

### Connection Limits
```bash
# Check current connections
redis-cli CLIENT LIST
# Kill idle connections
redis-cli CLIENT KILL TYPE idle
```

### Sentinel Split-Brain
```bash
# If two sentinels elect different masters:
# 1. Identify the correct master
# 2. Demote incorrect master
redis-cli -p 26379 SENTINEL failover dgsn-master
# 3. Force reconfiguration
redis-cli -p 26379 SENTINEL RESET dgsn-master
```
