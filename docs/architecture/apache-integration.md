# Apache Project Integration Guide

## Overview

DGSN integrates with the Apache ecosystem for data lakehouse, query federation, and stream processing. This document covers Iceberg, Trino, Spark, Flink, and Airflow integration patterns.

## Architecture

```
+-------------------+     +------------------+     +------------------+
|   Airflow DAGs    | --> |   Spark/Flink    | --> |   Iceberg Tables |
| (Scheduling/ETL)  |     | (Processing)     |     | (Data Lakehouse) |
+-------------------+     +------------------+     +--------+---------+
                                                           |
                                                  +--------+---------+
                                                  |    Trino (SQL)    |
                                                  | (Federated Query) |
                                                  +--+----+----+------+
                                                     |    |    |
                                          +----------+ +--+--+ +---------+
                                          |  Grafana  | |  ML  | | Python |
                                          | (BI)      | |(PyTorch)| (API) |
                                          +----------+ +------+ +---------+
```

## Apache Iceberg

### Table Formats

DGSN uses Iceberg v2 format for all analytical data:

| Table | Format | Partitioning | Compression |
|-------|--------|-------------|-------------|
| `dgsn_receipts.receipts_v1` | Parquet v2 | Day(timestamp) | ZSTD |
| `dgsn_telemetry.station_metrics` | Parquet v2 | Hour(timestamp) | ZSTD |
| `dgsn_scheduling.passes` | Parquet v2 | Month(start_time) | ZSTD |

### Schema Evolution

Iceberg supports backward-compatible schema changes:

```sql
-- Add new column
ALTER TABLE dgsn_receipts.receipts_v1 ADD COLUMN processing_latency_ms bigint;

-- Rename column
ALTER TABLE dgsn_receipts.receipts_v1 RENAME COLUMN signal_strength_db TO rssi_db;

-- Drop column (v2 only)
ALTER TABLE dgsn_receipts.receipts_v1 DROP COLUMN chain_depth;
```

### Time Travel

```sql
-- Query as of specific timestamp
SELECT * FROM dgsn_receipts.receipts_v1
  FOR TIMESTAMP AS OF TIMESTAMP '2024-06-01 00:00:00';

-- Query by snapshot ID
SELECT * FROM dgsn_receipts.receipts_v1
  FOR SYSTEM_VERSION AS OF 847284920184729;
```

### Compaction

```sql
-- Trigger compaction via Trino
ALTER TABLE dgsn_receipts.receipts_v1 EXECUTE optimize;

-- With file size target (default 512MB)
ALTER TABLE dgsn_receipts.receipts_v1 EXECUTE optimize (file_size_threshold => '256MB');
```

## Apache Trino

### Catalog Configuration

See `configs/trino/trino-config.yaml` for full catalog definitions.

### Federated Queries

```sql
-- Cross-catalog join: Iceberg + PostgreSQL
SELECT r.receipt_id, s.name, r.timestamp
FROM dgsn_iceberg.dgsn_receipts.receipts_v1 r
JOIN dgsn_postgres.public.stations s
  ON r.station_id = s.station_id
WHERE r.timestamp >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR;

-- Redis cache lookup with Iceberg historical data
SELECT r.*
FROM dgsn_iceberg.dgsn_telemetry.station_metrics r
WHERE r.station_id IN (
  SELECT value FROM dgsn_redis.public.active_stations
);
```

### Performance Tuning

```sql
-- Set session properties
SET SESSION dgsn_iceberg.statistics_enabled = true;
SET SESSION hash_partition_count = 10;
SET SESSION join_distribution_type = 'PARTITIONED';
```

## Apache Spark

### Reading Iceberg Tables

```python
# spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.0

from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("dgsn-etl") \
    .config("spark.sql.catalog.dgsn", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.dgsn.type", "rest") \
    .config("spark.sql.catalog.dgsn.uri", "http://polaris:8181/api/catalog") \
    .config("spark.sql.catalog.dgsn.warehouse", "s3://dgsn-iceberg/warehouse") \
    .config("spark.sql.catalog.dgsn.s3.endpoint", "http://minio:9000") \
    .config("spark.sql.catalog.dgsn.s3.path.style.access", "true") \
    .getOrCreate()

df = spark.table("dgsn.dgsn_receipts.receipts_v1") \
    .filter("verified = true") \
    .groupBy("station_id") \
    .count()

df.show()
```

### MERGE (Upsert)

```python
from pyspark.sql import Row

updates = spark.createDataFrame([
    Row(receipt_id="rec-001", verified=True, chain_depth=3),
])

target = spark.table("dgsn.dgsn_receipts.receipts_v1")

target.merge(
    updates,
    condition="target.receipt_id = updates.receipt_id"
).whenMatchedUpdate(set={
    "verified": "updates.verified",
    "chain_depth": "updates.chain_depth"
}).whenNotMatchedInsertAll().execute()
```

## Apache Flink

### Streaming Ingestion

```java
// Flink SQL job for real-time receipt ingestion
TableEnvironment tEnv = TableEnvironment.create(EnvironmentSettings.inStreamingMode());

tEnv.executeSql("CREATE CATALOG dgsn_iceberg WITH (" +
    "'type'='iceberg'," +
    "'catalog-type'='rest'," +
    "'uri'='http://polaris:8181/api/catalog'" +
    ")");

tEnv.executeSql("CREATE TABLE receipts_source (" +
    "receipt_id STRING, station_id STRING, timestamp TIMESTAMP(3), " +
    "signal_hash BINARY, merkle_root BINARY, " +
    "signature BINARY, verified BOOLEAN, " +
    "WATERMARK FOR timestamp AS timestamp - INTERVAL '5' SECOND" +
    ") WITH (" +
    "'connector'='kafka'," +
    "'topic'='dgsn.receipts'," +
    "'properties.bootstrap.servers'='kafka:9092'," +
    "'format'='json'" +
    ")");

tEnv.executeSql("INSERT INTO dgsn_iceberg.dgsn_receipts.receipts_v1 " +
    "SELECT * FROM receipts_source");
```

## Apache Airflow

### DAG Example: Daily Receipt Verification

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

default_args = {
    'owner': 'dgsn',
    'depends_on_past': False,
    'email_on_failure': True,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'dgsn_receipt_verification',
    default_args=default_args,
    description='Daily receipt chain verification and metrics',
    schedule_interval='0 2 * * *',
    start_date=datetime(2024, 6, 1),
    catchup=False,
    tags=['dgsn', 'receipts'],
) as dag:

    verify_receipts = SparkSubmitOperator(
        task_id='verify_receipts',
        application='/opt/dgsn/etl/verify_receipts.py',
        conn_id='spark_default',
        application_args=[
            '--date', '{{ ds }}',
            '--min-verification-threshold', '0.95',
        ],
        packages='org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.0',
    )

    compute_metrics = SparkSubmitOperator(
        task_id='compute_daily_metrics',
        application='/opt/dgsn/etl/compute_metrics.py',
        conn_id='spark_default',
        application_args=['--date', '{{ ds }}'],
    )

    verify_receipts >> compute_metrics
```

## Operational Procedures

### Adding a New Iceberg Table

```bash
# 1. Define schema in configs/iceberg/iceberg-catalog.yaml
# 2. Create table through Trino:
trino-cli --server http://localhost:8080 \
  --catalog dgsn_iceberg \
  --execute "CREATE TABLE dgsn_receipts.anomalies_v1 (...) WITH (format='PARQUET')"
# 3. Verify in Polaris catalog API
curl http://polaris:8181/api/catalog/v1/namespaces/dgsn_receipts/tables
```

### Query Performance Tuning

```sql
-- Analyze table for statistics
ANALYZE dgsn_iceberg.dgsn_receipts.receipts_v1;

-- Check query plan
EXPLAIN (TYPE DISTRIBUTED, FORMAT JSON)
SELECT station_id, count(*) FROM dgsn_iceberg.dgsn_receipts.receipts_v1
WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY station_id;
```

### Monitoring

- **Trino**: Port 8080 (Web UI), metrics on port 9091
- **Iceberg**: Polaris API health at `/api/management/v1/health`
- **Spark**: Spark History Server on port 18080
- **Flink**: Job Manager dashboard on port 8081
- **Airflow**: Web UI on port 8080
