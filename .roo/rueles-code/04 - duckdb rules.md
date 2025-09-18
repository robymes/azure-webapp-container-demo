# DuckDB and DuckLake Implementation Standards

## Overview

This document establishes best practices and implementation standards for using DuckDB and DuckLake (Delta Lake integration) in Python applications. These guidelines ensure optimal performance, data integrity, and maintainable code.

## Table of Contents

1. [DuckDB Connection Management](#duckdb-connection-management)
2. [Query Best Practices](#query-best-practices)
3. [Data Type Handling](#data-type-handling)
4. [Performance Optimization](#performance-optimization)
5. [DuckLake Extension](#ducklake-extension)
6. [External Parquet Data Management](#external-parquet-data-management)
7. [Library Integrations](#library-integrations)
8. [Error Handling](#error-handling)
9. [Security Considerations](#security-considerations)
10. [Testing Guidelines](#testing-guidelines)
11. [Code Examples](#code-examples)

## DuckDB Connection Management

### 1. Connection Patterns

**✅ DO: Use context managers for connections**
```python
import duckdb

# Preferred: Context manager ensures proper cleanup
with duckdb.connect('database.db') as conn:
    result = conn.execute("SELECT * FROM table").fetchall()
```

**❌ DON'T: Leave connections open without proper cleanup**
```python
# Avoid: Manual connection management
conn = duckdb.connect('database.db')
result = conn.execute("SELECT * FROM table").fetchall()
# Missing conn.close()
```

### 2. Connection Configuration

**✅ DO: Configure connections appropriately**
```python
# Set appropriate memory limits and thread count
conn = duckdb.connect(':memory:', config={
    'memory_limit': '2GB',
    'threads': 4,
    'max_memory': '80%'
})
```

### 3. Connection Pooling

**✅ DO: Implement connection pooling for multi-threaded applications**
```python
from threading import Lock
from typing import Dict, Any

class DuckDBConnectionPool:
    def __init__(self, database_path: str, max_connections: int = 10):
        self.database_path = database_path
        self.max_connections = max_connections
        self._connections = []
        self._lock = Lock()
    
    def get_connection(self) -> duckdb.DuckDBPyConnection:
        with self._lock:
            if self._connections:
                return self._connections.pop()
            return duckdb.connect(self.database_path)
    
    def return_connection(self, conn: duckdb.DuckDBPyConnection):
        with self._lock:
            if len(self._connections) < self.max_connections:
                self._connections.append(conn)
            else:
                conn.close()
```

## Query Best Practices

### 1. Parameterized Queries

**✅ DO: Use parameterized queries to prevent SQL injection**
```python
# Safe parameterized query
user_id = 123
result = conn.execute(
    "SELECT * FROM users WHERE id = ?", 
    [user_id]
).fetchall()
```

**❌ DON'T: Use string concatenation for queries**
```python
# Dangerous: SQL injection vulnerability
user_id = 123
query = f"SELECT * FROM users WHERE id = {user_id}"
result = conn.execute(query).fetchall()
```

### 2. Query Optimization

**✅ DO: Use EXPLAIN to analyze query performance**
```python
# Analyze query execution plan
explain_result = conn.execute("EXPLAIN SELECT * FROM large_table WHERE condition").fetchall()
print(explain_result)
```

**✅ DO: Use appropriate indexes and constraints**
```python
# Create indexes for frequently queried columns
conn.execute("CREATE INDEX idx_user_email ON users(email)")
conn.execute("CREATE INDEX idx_order_date ON orders(order_date)")
```

### 3. Batch Operations

**✅ DO: Use batch operations for bulk data processing**
```python
# Efficient batch insert
data = [(1, 'Alice'), (2, 'Bob'), (3, 'Charlie')]
conn.executemany("INSERT INTO users (id, name) VALUES (?, ?)", data)
```

## Data Type Handling

### 1. Type Mapping

**✅ DO: Use appropriate Python-DuckDB type mappings**
```python
from typing import Union, List, Dict, Any
import datetime
import decimal

# Recommended type mappings
TYPE_MAPPINGS = {
    'INTEGER': int,
    'BIGINT': int,
    'DOUBLE': float,
    'VARCHAR': str,
    'DATE': datetime.date,
    'TIMESTAMP': datetime.datetime,
    'DECIMAL': decimal.Decimal,
    'BOOLEAN': bool
}
```

### 2. NULL Handling

**✅ DO: Handle NULL values explicitly**
```python
# Check for NULL values
result = conn.execute("SELECT name FROM users WHERE id = ?", [user_id]).fetchone()
name = result[0] if result and result[0] is not None else "Unknown"
```

### 3. Array and JSON Support

**✅ DO: Leverage DuckDB's array and JSON capabilities**
```python
# Working with arrays
conn.execute("CREATE TABLE array_table (id INTEGER, tags INTEGER[])")
conn.execute("INSERT INTO array_table VALUES (1, [1, 2, 3])")

# Working with JSON
conn.execute("SELECT json_extract(data, '$.name') FROM json_table")
```

## Performance Optimization

### 1. Memory Management

**✅ DO: Configure memory settings based on data size**
```python
# For large datasets
conn.execute("SET memory_limit='4GB'")
conn.execute("SET max_memory='80%'")
```

### 2. Parallel Processing

**✅ DO: Utilize DuckDB's parallel processing capabilities**
```python
# Enable parallel processing
conn.execute("SET threads=8")
```

### 3. Columnar Storage Benefits

**✅ DO: Structure queries to leverage columnar storage**
```python
# Efficient: Select only needed columns
result = conn.execute("SELECT name, email FROM users WHERE active = true").fetchall()

# Less efficient: Select all columns
result = conn.execute("SELECT * FROM users WHERE active = true").fetchall()
```

## DuckLake Extension

### 1. DuckLake Extension Overview

**DuckLake** is a DuckDB extension that provides lakehouse capabilities, allowing DuckDB to work efficiently with data lake architectures. It enables features like data versioning, metadata management, and optimized storage formats for large-scale analytics.

**✅ DO: Install and load the DuckLake extension properly**
```python
import duckdb

# Connect to DuckDB and install DuckLake extension
conn = duckdb.connect()

# Install the DuckLake extension
conn.execute("INSTALL ducklake")
conn.execute("LOAD ducklake")

# Verify the extension is loaded
extensions = conn.execute("""
    SELECT extension_name, loaded
    FROM duckdb_extensions()
    WHERE extension_name = 'ducklake'
""").fetchall()

if extensions and extensions[0][1]:
    print("DuckLake extension loaded successfully")
else:
    print("Failed to load DuckLake extension")
```

### 2. DuckLake Storage Configuration

**✅ DO: Configure DuckLake storage backends properly**
```python
# Configure local storage for DuckLake
conn.execute("SET ducklake.storage_path = '/path/to/lakehouse/data'")
conn.execute("SET ducklake.metadata_path = '/path/to/lakehouse/metadata'")

# Configure S3 storage backend
conn.execute("SET ducklake.storage_backend = 's3'")
conn.execute("SET ducklake.s3_endpoint = 's3://my-bucket/lakehouse/'")
conn.execute("SET ducklake.s3_region = 'us-west-2'")

# Configure Azure storage backend
conn.execute("SET ducklake.storage_backend = 'azure'")
conn.execute("SET ducklake.azure_account = 'mystorageaccount'")
conn.execute("SET ducklake.azure_container = 'lakehouse'")

# Configure compression and format options
conn.execute("SET ducklake.default_compression = 'snappy'")
conn.execute("SET ducklake.default_format = 'parquet'")
conn.execute("SET ducklake.enable_statistics = true")
```

### 3. Creating DuckLake Tables

**✅ DO: Create DuckLake-managed tables with proper schema**
```python
# Create a DuckLake table with versioning
conn.execute("""
    CREATE TABLE users_lake (
        id INTEGER PRIMARY KEY,
        name VARCHAR NOT NULL,
        email VARCHAR,
        created_at TIMESTAMP NOT NULL,
        age INTEGER,
        metadata JSON
    ) USING DUCKLAKE
    PARTITIONED BY (DATE_TRUNC('month', created_at))
    CLUSTERED BY (id)
    WITH (
        compression = 'zstd',
        target_file_size = '128MB',
        enable_versioning = true
    )
""")

# Create table with custom properties
conn.execute("""
    CREATE TABLE orders_lake (
        order_id BIGINT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        order_date DATE NOT NULL,
        status VARCHAR DEFAULT 'pending'
    ) USING DUCKLAKE
    PARTITIONED BY (order_date)
    WITH (
        retention_days = 365,
        auto_optimize = true,
        bloom_filter_columns = ['user_id', 'order_id']
    )
""")
```

### 4. Data Operations with DuckLake

**✅ DO: Use DuckLake-specific data operations**
```python
# Insert data with automatic versioning
conn.execute("""
    INSERT INTO users_lake (id, name, email, created_at, age)
    VALUES
        (1, 'Alice Johnson', 'alice@example.com', '2023-01-15'::TIMESTAMP, 28),
        (2, 'Bob Smith', 'bob@example.com', '2023-01-16'::TIMESTAMP, 34),
        (3, 'Carol Davis', 'carol@example.com', '2023-01-17'::TIMESTAMP, 29)
""")

# Bulk insert from existing table
conn.execute("""
    INSERT INTO users_lake
    SELECT * FROM staging_users
    WHERE created_at >= '2023-01-01'
""")

# Update with version tracking
conn.execute("""
    UPDATE users_lake
    SET age = age + 1, email = 'newemail@example.com'
    WHERE id = 1
""")

# Merge/Upsert operations
conn.execute("""
    MERGE INTO users_lake AS target
    USING staging_users AS source
    ON target.id = source.id
    WHEN MATCHED THEN
        UPDATE SET name = source.name, email = source.email
    WHEN NOT MATCHED THEN
        INSERT (id, name, email, created_at, age)
        VALUES (source.id, source.name, source.email, source.created_at, source.age)
""")
```

### 5. Querying DuckLake Tables

**✅ DO: Leverage DuckLake query optimizations**
```python
# Standard queries with automatic optimization
result = conn.execute("""
    SELECT
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as user_count,
        AVG(age) as avg_age
    FROM users_lake
    WHERE created_at >= '2023-01-01'
    GROUP BY month
    ORDER BY month
""").fetchall()

# Query with partition pruning
result = conn.execute("""
    SELECT * FROM orders_lake
    WHERE order_date BETWEEN '2023-06-01' AND '2023-06-30'
      AND status = 'completed'
""").fetchall()

# Complex analytics query
result = conn.execute("""
    SELECT
        u.name,
        COUNT(o.order_id) as order_count,
        SUM(o.amount) as total_spent,
        MAX(o.order_date) as last_order
    FROM users_lake u
    LEFT JOIN orders_lake o ON u.id = o.user_id
    WHERE u.created_at >= '2023-01-01'
    GROUP BY u.id, u.name
    HAVING total_spent > 1000
    ORDER BY total_spent DESC
""").fetchall()
```

### 6. Version Management and Time Travel

**✅ DO: Use DuckLake's versioning capabilities**
```python
# Query current version
current_data = conn.execute("SELECT * FROM users_lake").fetchall()

# Query specific version
conn.execute("SET ducklake.read_version = 5")
historical_data = conn.execute("SELECT * FROM users_lake").fetchall()
conn.execute("RESET ducklake.read_version")

# Query at specific timestamp
conn.execute("SET ducklake.read_timestamp = '2023-06-15 10:30:00'")
snapshot_data = conn.execute("SELECT * FROM users_lake").fetchall()
conn.execute("RESET ducklake.read_timestamp")

# Get table version history
version_history = conn.execute("""
    SELECT version, timestamp, operation, records_added, records_deleted
    FROM ducklake_history('users_lake')
    ORDER BY version DESC
    LIMIT 10
""").fetchall()

# Compare versions
comparison = conn.execute("""
    WITH current_count AS (
        SELECT COUNT(*) as cnt FROM users_lake
    ),
    previous_count AS (
        SELECT COUNT(*) as cnt FROM users_lake
        AT VERSION 5
    )
    SELECT
        current_count.cnt as current_records,
        previous_count.cnt as previous_records,
        current_count.cnt - previous_count.cnt as difference
    FROM current_count, previous_count
""").fetchall()
```

### 7. Table Maintenance and Optimization

**✅ DO: Perform regular DuckLake table maintenance**
```python
# Optimize table storage
conn.execute("OPTIMIZE users_lake")

# Compact small files
conn.execute("""
    OPTIMIZE users_lake
    WITH (operation = 'compact', target_file_size = '256MB')
""")

# Z-order clustering for better query performance
conn.execute("""
    OPTIMIZE users_lake
    WITH (operation = 'z_order', columns = ['created_at', 'id'])
""")

# Vacuum old versions (remove files older than retention period)
conn.execute("VACUUM users_lake RETAIN 168 HOURS")  # Keep 7 days

# Update table statistics
conn.execute("ANALYZE users_lake")

# Check table health and statistics
table_stats = conn.execute("""
    SELECT
        table_name,
        current_version,
        total_files,
        total_size_bytes,
        avg_file_size_mb,
        partition_count
    FROM ducklake_table_stats('users_lake')
""").fetchall()
```

### 8. Schema Evolution

**✅ DO: Handle schema evolution properly**
```python
# Add new column
conn.execute("""
    ALTER TABLE users_lake
    ADD COLUMN phone_number VARCHAR
""")

# Add column with default value
conn.execute("""
    ALTER TABLE users_lake
    ADD COLUMN preferences JSON DEFAULT '{}'
""")

# Modify column properties (if supported)
conn.execute("""
    ALTER TABLE users_lake
    ALTER COLUMN email SET NOT NULL
""")

# Check schema history
schema_changes = conn.execute("""
    SELECT version, timestamp, schema_changes
    FROM ducklake_schema_history('users_lake')
    ORDER BY version DESC
""").fetchall()
```

### 9. Metadata and Catalog Operations

**✅ DO: Query DuckLake metadata effectively**
```python
# List all DuckLake tables
ducklake_tables = conn.execute("""
    SELECT table_name, created_at, current_version, storage_backend
    FROM ducklake_tables()
""").fetchall()

# Get detailed table information
table_info = conn.execute("""
    SELECT * FROM ducklake_table_info('users_lake')
""").fetchall()

# Check partition information
partitions = conn.execute("""
    SELECT partition_value, file_count, total_size_bytes
    FROM ducklake_partitions('users_lake')
    ORDER BY partition_value
""").fetchall()

# View table properties
properties = conn.execute("""
    SELECT property_name, property_value
    FROM ducklake_table_properties('users_lake')
""").fetchall()
```

### 10. Error Handling and Troubleshooting

**✅ DO: Implement robust error handling for DuckLake operations**
```python
def safe_ducklake_operation(conn, operation_sql):
    try:
        result = conn.execute(operation_sql).fetchall()
        return result
    except duckdb.Error as e:
        error_msg = str(e).lower()
        if "ducklake" in error_msg:
            if "version" in error_msg:
                print(f"DuckLake versioning error: {e}")
                # Handle version-related errors
            elif "schema" in error_msg:
                print(f"DuckLake schema error: {e}")
                # Handle schema-related errors
            elif "storage" in error_msg:
                print(f"DuckLake storage error: {e}")
                # Handle storage backend errors
            else:
                print(f"General DuckLake error: {e}")
        raise
    except Exception as e:
        print(f"Unexpected error in DuckLake operation: {e}")
        raise

# Validate DuckLake table health
def check_table_health(conn, table_name):
    try:
        # Check if table exists and is accessible
        conn.execute(f"SELECT COUNT(*) FROM {table_name} LIMIT 1")
        
        # Check for corrupted files
        corruption_check = conn.execute(f"""
            SELECT COUNT(*) as corrupted_files
            FROM ducklake_file_health('{table_name}')
            WHERE status = 'corrupted'
        """).fetchone()
        
        if corruption_check[0] > 0:
            print(f"Warning: {corruption_check[0]} corrupted files found in {table_name}")
            return False
        
        return True
    except Exception as e:
        print(f"Table health check failed for {table_name}: {e}")
        return False

# Usage examples
try:
    # Safe query execution
    result = safe_ducklake_operation(conn, "SELECT * FROM users_lake LIMIT 10")
    
    # Health check
    if check_table_health(conn, "users_lake"):
        print("Table is healthy")
    else:
        print("Table has issues - consider running OPTIMIZE or VACUUM")
        
except Exception as e:
    print(f"Operation failed: {e}")
```

### 11. Performance Best Practices

**✅ DO: Follow DuckLake performance optimization guidelines**
```python
# Configure optimal settings for DuckLake
conn.execute("SET ducklake.parallel_reads = true")
conn.execute("SET ducklake.cache_size = '1GB'")
conn.execute("SET ducklake.prefetch_enabled = true")

# Use appropriate data types
conn.execute("""
    CREATE TABLE optimized_table (
        id BIGINT PRIMARY KEY,              -- Use BIGINT for large ID ranges
        name VARCHAR(100),                  -- Specify VARCHAR length when known
        amount DECIMAL(12,2),              -- Use DECIMAL for precise monetary values
        created_at TIMESTAMP,              -- Use TIMESTAMP for time-based partitioning
        category ENUM('A', 'B', 'C'),      -- Use ENUM for limited value sets
        is_active BOOLEAN                   -- Use BOOLEAN instead of VARCHAR for flags
    ) USING DUCKLAKE
    PARTITIONED BY (DATE_TRUNC('day', created_at))
    CLUSTERED BY (category, id)
""")

# Optimize query patterns
def efficient_batch_insert(conn, data_batches):
    """Insert data in optimized batches"""
    conn.execute("BEGIN TRANSACTION")
    try:
        for batch in data_batches:
            # Use prepared statements for better performance
            conn.executemany("""
                INSERT INTO users_lake (id, name, email, created_at, age)
                VALUES (?, ?, ?, ?, ?)
            """, batch)
        conn.execute("COMMIT")
    except Exception as e:
        conn.execute("ROLLBACK")
        raise

# Monitor performance
def monitor_query_performance(conn, query):
    """Monitor DuckLake query performance"""
    conn.execute("SET enable_profiling = true")
    start_time = time.time()
    
    result = conn.execute(query).fetchall()
    
    end_time = time.time()
    execution_time = end_time - start_time
    
    # Get query profile
    profile = conn.execute("SELECT * FROM pragma_profile_output()").fetchall()
    
    print(f"Query executed in {execution_time:.2f} seconds")
    print("Query profile:", profile)
    
    conn.execute("SET enable_profiling = false")
    return result
```

**❌ DON'T: Common DuckLake mistakes to avoid**
```python
# Don't forget to load the extension
# conn.execute("SELECT * FROM users_lake")  # Will fail if extension not loaded

# Don't ignore version management
# conn.execute("DELETE FROM users_lake WHERE id = 1")  # Consider using soft deletes with versioning

# Don't skip table optimization
# # Large tables without regular OPTIMIZE will have poor performance

# Don't use inappropriate partition columns
# # Avoid partitioning on high-cardinality columns like ID
```

## External Parquet Data Management

### 1. Reading Parquet Files

**✅ DO: Use DuckDB's native Parquet support for optimal performance**
```python
# Direct Parquet file reading
result = conn.execute("SELECT * FROM 'path/to/file.parquet'").fetchall()

# Reading from S3 or remote locations
conn.execute("INSTALL httpfs")
conn.execute("LOAD httpfs")
result = conn.execute("SELECT * FROM 's3://bucket/path/file.parquet'").fetchall()

# Reading multiple Parquet files with glob patterns
result = conn.execute("SELECT * FROM 'data/*.parquet'").fetchall()
```

**✅ DO: Leverage partitioned Parquet datasets**
```python
# Reading partitioned datasets
result = conn.execute("""
    SELECT * FROM read_parquet('data/year=*/month=*/*.parquet',
                              hive_partitioning=true)
    WHERE year = 2023 AND month = 12
""").fetchall()
```

### 2. Writing Parquet Files

**✅ DO: Configure appropriate Parquet writing options**
```python
# Write with compression and row group size optimization
conn.execute("""
    COPY (SELECT * FROM large_table)
    TO 'output.parquet'
    (FORMAT PARQUET, COMPRESSION 'snappy', ROW_GROUP_SIZE 100000)
""")

# Write partitioned Parquet files
conn.execute("""
    COPY (SELECT * FROM sales_data)
    TO 'partitioned_output'
    (FORMAT PARQUET, PARTITION_BY (year, month))
""")
```

### 3. Parquet Schema Management

**✅ DO: Handle schema evolution properly**
```python
# Check Parquet file schema
schema_info = conn.execute("DESCRIBE SELECT * FROM 'file.parquet'").fetchall()

# Handle missing columns gracefully
conn.execute("""
    SELECT
        id,
        name,
        COALESCE(new_column, 'default_value') as new_column
    FROM 'legacy_data.parquet'
""")
```

**✅ DO: Optimize data types for Parquet storage**
```python
# Use appropriate data types before writing
conn.execute("""
    CREATE TABLE optimized_table AS
    SELECT
        id::INTEGER,
        name::VARCHAR,
        amount::DECIMAL(10,2),
        created_at::TIMESTAMP
    FROM source_table
""")

conn.execute("COPY optimized_table TO 'optimized.parquet' (FORMAT PARQUET)")
```

### 4. Performance Optimization for Parquet

**✅ DO: Use column pruning and predicate pushdown**
```python
# Column pruning - only read needed columns
result = conn.execute("""
    SELECT name, amount
    FROM 'large_file.parquet'
    WHERE created_at > '2023-01-01'
""").fetchall()

# Use appropriate filters for partition elimination
result = conn.execute("""
    SELECT * FROM 'partitioned_data/*.parquet'
    WHERE year = 2023  -- This will eliminate unnecessary partitions
""").fetchall()
```

### 5. Parquet Metadata Management

**✅ DO: Query Parquet metadata for optimization**
```python
# Get Parquet file metadata
metadata = conn.execute("SELECT * FROM parquet_metadata('file.parquet')").fetchall()

# Get schema information
schema = conn.execute("SELECT * FROM parquet_schema('file.parquet')").fetchall()

# Check file statistics
stats = conn.execute("PRAGMA table_info('file.parquet')").fetchall()
```

## Library Integrations

### 1. PyArrow Integration

**✅ DO: Use PyArrow for advanced Parquet operations**
```python
import pyarrow as pa
import pyarrow.parquet as pq
import duckdb

# Convert PyArrow table to DuckDB
arrow_table = pq.read_table('data.parquet')
result = conn.execute("SELECT * FROM arrow_table WHERE column > 100").fetchall()

# Convert DuckDB result to PyArrow
duckdb_result = conn.execute("SELECT * FROM table").arrow()
```

**✅ DO: Leverage PyArrow for complex data transformations**
```python
import pyarrow.compute as pc

# Use PyArrow compute functions with DuckDB
def process_with_arrow(conn, table_name: str):
    # Get data as Arrow table
    arrow_table = conn.execute(f"SELECT * FROM {table_name}").arrow()
    
    # Apply PyArrow transformations
    filtered = pc.filter(arrow_table, pc.greater(arrow_table['value'], 100))
    
    # Register back with DuckDB
    conn.register('processed_data', filtered)
    return conn.execute("SELECT * FROM processed_data").fetchall()
```

**✅ DO: Use PyArrow for schema validation**
```python
import pyarrow as pa

def validate_schema(conn, table_name: str, expected_schema: pa.Schema):
    table_arrow = conn.execute(f"SELECT * FROM {table_name} LIMIT 0").arrow()
    
    if not table_arrow.schema.equals(expected_schema):
        raise ValueError(f"Schema mismatch for table {table_name}")
```

### 2. Polars Integration

**✅ DO: Use Polars for data preprocessing before DuckDB**
```python
import polars as pl
import duckdb

# Process data with Polars, then use in DuckDB
df = pl.read_parquet('large_dataset.parquet')
processed = df.filter(pl.col('status') == 'active').with_columns([
    pl.col('amount').cast(pl.Float64),
    pl.col('date').str.strptime(pl.Date, '%Y-%m-%d')
])

# Register Polars DataFrame with DuckDB
conn.register('polars_data', processed.to_arrow())
result = conn.execute("SELECT * FROM polars_data WHERE amount > 1000").fetchall()
```

**✅ DO: Use Polars lazy evaluation with DuckDB**
```python
# Create lazy Polars query
lazy_df = pl.scan_parquet('data/*.parquet').filter(
    pl.col('year') == 2023
).group_by('category').agg([
    pl.col('amount').sum().alias('total_amount'),
    pl.col('id').count().alias('count')
])

# Convert to Arrow and use in DuckDB
arrow_result = lazy_df.collect().to_arrow()
conn.register('aggregated_data', arrow_result)
```

**✅ DO: Choose between Polars and DuckDB based on use case**
```python
def choose_processing_engine(data_size: int, operation_type: str):
    """
    Guidelines for choosing between Polars and DuckDB:
    - Use Polars for: Complex data transformations, when working with Rust ecosystem
    - Use DuckDB for: SQL-heavy workloads, analytical queries, when SQL familiarity is key
    """
    if operation_type == 'complex_transformations' and data_size < 1_000_000:
        return 'polars'  # Better for complex transformations on smaller datasets
    elif operation_type == 'analytical_sql':
        return 'duckdb'  # Better for SQL-heavy analytical workloads
    else:
        return 'duckdb'  # Default to DuckDB for most cases
```

### 3. Ibis Integration

**✅ DO: Use Ibis for cross-engine compatibility**
```python
import ibis
from ibis import _

# Create Ibis DuckDB backend
ibis_conn = ibis.duckdb.connect(':memory:')

# Create table reference
table = ibis_conn.read_parquet('data.parquet')

# Use Ibis expressions
result = (table
    .filter(_.amount > 1000)
    .group_by(_.category)
    .aggregate(
        total_amount=_.amount.sum(),
        avg_amount=_.amount.mean(),
        count=_.count()
    )
    .execute()
)
```

**✅ DO: Use Ibis for portable analytical code**
```python
def create_analytical_pipeline(backend_conn, table_name: str):
    """
    Create a portable analytical pipeline using Ibis
    that can work with different backends (DuckDB, PostgreSQL, etc.)
    """
    table = backend_conn.table(table_name)
    
    return (table
        .filter(_.status == 'completed')
        .group_by([_.region, _.product_category])
        .aggregate([
            _.revenue.sum().name('total_revenue'),
            _.quantity.sum().name('total_quantity'),
            _.order_id.nunique().name('unique_orders')
        ])
        .order_by(_.total_revenue.desc())
    )

# Use with DuckDB
duckdb_backend = ibis.duckdb.connect('analytics.db')
result = create_analytical_pipeline(duckdb_backend, 'sales_data').execute()
```

### 4. Library Interoperability Best Practices

**✅ DO: Create unified data processing pipelines**
```python
class UnifiedDataProcessor:
    def __init__(self, duckdb_path: str = ':memory:'):
        self.conn = duckdb.connect(duckdb_path)
        
    def process_with_polars_and_duckdb(self, parquet_path: str):
        # Step 1: Initial processing with Polars (efficient for transformations)
        df = pl.read_parquet(parquet_path)
        cleaned = df.drop_nulls().filter(pl.col('amount') > 0)
        
        # Step 2: Register with DuckDB for SQL analytics
        self.conn.register('cleaned_data', cleaned.to_arrow())
        
        # Step 3: Complex analytics with DuckDB SQL
        result = self.conn.execute("""
            SELECT
                category,
                SUM(amount) as total_amount,
                COUNT(*) as transaction_count,
                AVG(amount) as avg_amount,
                PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) as median_amount
            FROM cleaned_data
            GROUP BY category
            ORDER BY total_amount DESC
        """).fetchall()
        
        return result
    
    def arrow_to_duckdb_pipeline(self, arrow_table: pa.Table):
        # Register Arrow table with DuckDB
        self.conn.register('arrow_input', arrow_table)
        
        # Process with DuckDB
        processed = self.conn.execute("""
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY category ORDER BY amount DESC) as rank
            FROM arrow_input
        """).arrow()
        
        return processed
```

**✅ DO: Optimize memory usage across libraries**
```python
import gc

def memory_efficient_processing(large_parquet_path: str):
    # Process in chunks to manage memory
    chunk_size = 1000000
    
    with duckdb.connect(':memory:') as conn:
        # Set memory limits
        conn.execute("SET memory_limit='2GB'")
        
        # Process large files in chunks
        conn.execute(f"""
            CREATE TABLE results AS
            SELECT category, SUM(amount) as total
            FROM read_parquet('{large_parquet_path}')
            GROUP BY category
        """)
        
        # Get results and clean up
        result = conn.execute("SELECT * FROM results").fetchall()
        
    # Force garbage collection
    gc.collect()
    return result
```

**✅ DO: Create library selection guidelines**
```python
class LibrarySelector:
    @staticmethod
    def recommend_library(use_case: str, data_size: int, team_skills: list) -> str:
        """
        Recommend the best library combination based on use case
        
        Args:
            use_case: Type of data processing needed
            data_size: Approximate number of rows
            team_skills: List of team's technical skills
            
        Returns:
            Recommended library or combination
        """
        recommendations = {
            'etl_pipeline': {
                'small': 'polars',  # < 1M rows
                'medium': 'duckdb + polars',  # 1M - 100M rows
                'large': 'duckdb + pyarrow'  # > 100M rows
            },
            'analytical_queries': {
                'any_size': 'duckdb' if 'sql' in team_skills else 'ibis + duckdb'
            },
            'cross_platform': {
                'any_size': 'ibis'
            },
            'real_time_processing': {
                'small': 'polars',
                'large': 'pyarrow + duckdb'
            }
        }
        
        size_category = ('small' if data_size < 1_000_000
                        else 'medium' if data_size < 100_000_000
                        else 'large')
        
        if use_case in recommendations:
            use_case_rec = recommendations[use_case]
            return use_case_rec.get(size_category, use_case_rec.get('any_size', 'duckdb'))
        
        return 'duckdb'  # Default recommendation
```

## Error Handling

### 1. Exception Handling

**✅ DO: Implement comprehensive error handling**
```python
import duckdb
import logging

def safe_query_execution(conn: duckdb.DuckDBPyConnection, query: str, params=None):
    try:
        if params:
            return conn.execute(query, params).fetchall()
        return conn.execute(query).fetchall()
    except duckdb.Error as e:
        logging.error(f"DuckDB error: {e}")
        raise
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        raise
```

### 2. Connection Error Handling

**✅ DO: Handle connection failures gracefully**
```python
def get_connection_with_retry(database_path: str, max_retries: int = 3):
    for attempt in range(max_retries):
        try:
            return duckdb.connect(database_path)
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            logging.warning(f"Connection attempt {attempt + 1} failed: {e}")
            time.sleep(2 ** attempt)  # Exponential backoff
```

## Security Considerations

### 1. Input Validation

**✅ DO: Validate all inputs before query execution**
```python
def validate_table_name(table_name: str) -> bool:
    # Only allow alphanumeric characters and underscores
    return table_name.replace('_', '').isalnum()

def safe_table_query(conn, table_name: str):
    if not validate_table_name(table_name):
        raise ValueError("Invalid table name")
    
    return conn.execute(f"SELECT * FROM {table_name}").fetchall()
```

### 2. File Path Security

**✅ DO: Validate file paths for Delta Lake operations**
```python
import os
from pathlib import Path

def validate_delta_path(path: str) -> bool:
    try:
        resolved_path = Path(path).resolve()
        # Ensure path is within allowed directories
        allowed_dirs = ['/data', '/warehouse']
        return any(str(resolved_path).startswith(allowed_dir) for allowed_dir in allowed_dirs)
    except Exception:
        return False
```

## Testing Guidelines

### 1. Unit Testing

**✅ DO: Write comprehensive unit tests**
```python
import unittest
import tempfile
import os

class TestDuckDBOperations(unittest.TestCase):
    def setUp(self):
        self.temp_db = tempfile.NamedTemporaryFile(delete=False)
        self.conn = duckdb.connect(self.temp_db.name)
        
    def tearDown(self):
        self.conn.close()
        os.unlink(self.temp_db.name)
        
    def test_basic_operations(self):
        self.conn.execute("CREATE TABLE test (id INTEGER, name VARCHAR)")
        self.conn.execute("INSERT INTO test VALUES (1, 'test')")
        result = self.conn.execute("SELECT * FROM test").fetchall()
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0], (1, 'test'))
```

### 2. Integration Testing

**✅ DO: Test Delta Lake integration**
```python
def test_delta_lake_operations():
    with tempfile.TemporaryDirectory() as temp_dir:
        delta_path = os.path.join(temp_dir, 'delta_table')
        
        # Test writing to Delta table
        conn.execute(f"COPY (SELECT 1 as id, 'test' as name) TO '{delta_path}' (FORMAT DELTA)")
        
        # Test reading from Delta table
        result = conn.execute(f"SELECT * FROM delta_scan('{delta_path}')").fetchall()
        assert len(result) == 1
```

## Code Examples

### 1. Complete Application Example

```python
import duckdb
import logging
from contextlib import contextmanager
from typing import List, Dict, Any, Optional

class DuckDBManager:
    def __init__(self, database_path: str):
        self.database_path = database_path
        self.logger = logging.getLogger(__name__)
        
    @contextmanager
    def get_connection(self):
        conn = None
        try:
            conn = duckdb.connect(self.database_path)
            yield conn
        except Exception as e:
            self.logger.error(f"Database error: {e}")
            raise
        finally:
            if conn:
                conn.close()
                
    def execute_query(self, query: str, params: Optional[List] = None) -> List[tuple]:
        with self.get_connection() as conn:
            if params:
                return conn.execute(query, params).fetchall()
            return conn.execute(query).fetchall()
            
    def execute_delta_query(self, delta_path: str, query_filter: str = "") -> List[tuple]:
        with self.get_connection() as conn:
            conn.execute("INSTALL delta")
            conn.execute("LOAD delta")
            
            base_query = f"SELECT * FROM delta_scan('{delta_path}')"
            if query_filter:
                base_query += f" WHERE {query_filter}"
                
            return conn.execute(base_query).fetchall()
```

### 2. Data Pipeline Example

```python
class DuckDBDataPipeline:
    def __init__(self, db_manager: DuckDBManager):
        self.db_manager = db_manager
        
    def process_data(self, source_table: str, target_delta_path: str):
        # Extract and transform data
        with self.db_manager.get_connection() as conn:
            # Load extensions
            conn.execute("INSTALL delta")
            conn.execute("LOAD delta")
            
            # Process data with transformations
            processed_query = f"""
                SELECT 
                    id,
                    UPPER(name) as name,
                    created_at,
                    CURRENT_TIMESTAMP as processed_at
                FROM {source_table}
                WHERE active = true
            """
            
            # Write to Delta Lake
            conn.execute(f"""
                COPY ({processed_query}) 
                TO '{target_delta_path}' 
                (FORMAT DELTA, OVERWRITE_OR_IGNORE true)
            """)
```

### 3. Multi-Library Integration Example

```python
import duckdb
import polars as pl
import pyarrow as pa
import ibis
from typing import Union, Dict, Any

class AdvancedAnalyticsEngine:
    def __init__(self, database_path: str = ':memory:'):
        self.conn = duckdb.connect(database_path)
        self.ibis_conn = ibis.duckdb.connect(database_path)
        
    def load_and_prepare_data(self, parquet_files: list) -> str:
        """Load multiple Parquet files and prepare for analysis"""
        # Use Polars for initial data cleaning and preparation
        dataframes = []
        for file_path in parquet_files:
            df = pl.read_parquet(file_path)
            # Clean and standardize
            cleaned = (df
                .drop_nulls()
                .filter(pl.col('amount') > 0)
                .with_columns([
                    pl.col('date').str.strptime(pl.Date, '%Y-%m-%d'),
                    pl.col('category').str.to_uppercase()
                ])
            )
            dataframes.append(cleaned)
        
        # Combine all dataframes
        combined = pl.concat(dataframes)
        
        # Register with DuckDB
        table_name = 'prepared_data'
        self.conn.register(table_name, combined.to_arrow())
        
        return table_name
    
    def analyze_with_ibis(self, table_name: str) -> Dict[str, Any]:
        """Perform analysis using Ibis for portability"""
        table = self.ibis_conn.table(table_name)
        
        # Complex analytical queries using Ibis
        results = {}
        
        # Time series analysis
        results['monthly_trends'] = (
            table
            .mutate(month=table.date.strftime('%Y-%m'))
            .group_by('month')
            .aggregate([
                table.amount.sum().name('total_amount'),
                table.amount.mean().name('avg_amount'),
                table.id.count().name('transaction_count')
            ])
            .order_by('month')
            .execute()
        )
        
        # Category analysis
        results['category_analysis'] = (
            table
            .group_by('category')
            .aggregate([
                table.amount.sum().name('total_revenue'),
                table.amount.quantile(0.5).name('median_amount'),
                table.id.nunique().name('unique_customers')
            ])
            .order_by(ibis.desc('total_revenue'))
            .execute()
        )
        
        return results
    
    def export_results(self, analysis_results: Dict[str, Any], output_dir: str):
        """Export results using PyArrow for efficient storage"""
        for analysis_name, result_df in analysis_results.items():
            # Convert to Arrow table
            arrow_table = pa.Table.from_pandas(result_df)
            
            # Write optimized Parquet file
            output_path = f"{output_dir}/{analysis_name}.parquet"
            pa.parquet.write_table(
                arrow_table,
                output_path,
                compression='snappy',
                row_group_size=100000
            )
            
    def run_full_pipeline(self, parquet_files: list, output_dir: str) -> Dict[str, Any]:
        """Run the complete analytics pipeline"""
        # Step 1: Load and prepare data with Polars
        table_name = self.load_and_prepare_data(parquet_files)
        
        # Step 2: Analyze with Ibis (portable SQL)
        results = self.analyze_with_ibis(table_name)
        
        # Step 3: Export with PyArrow
        self.export_results(results, output_dir)
        
        # Step 4: Run additional DuckDB-specific optimizations
        optimization_results = self.conn.execute(f"""
            SELECT
                category,
                COUNT(*) as record_count,
                MIN(date) as earliest_date,
                MAX(date) as latest_date,
                SUM(amount) as total_amount,
                APPROX_QUANTILE(amount, 0.5) as median_amount,
                STDDEV(amount) as amount_stddev
            FROM {table_name}
            GROUP BY category
            ORDER BY total_amount DESC
        """).fetchall()
        
        results['detailed_stats'] = optimization_results
        
        return results
```

### 4. Performance Monitoring Example

```python
import time
import psutil
import logging
from contextlib import contextmanager

class PerformanceMonitor:
    def __init__(self, conn: duckdb.DuckDBPyConnection):
        self.conn = conn
        self.logger = logging.getLogger(__name__)
        
    @contextmanager
    def monitor_query(self, query_name: str):
        """Monitor query performance and resource usage"""
        start_time = time.time()
        start_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
        
        try:
            yield
        finally:
            end_time = time.time()
            end_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
            
            execution_time = end_time - start_time
            memory_used = end_memory - start_memory
            
            self.logger.info(f"""
            Query Performance Report: {query_name}
            Execution Time: {execution_time:.2f} seconds
            Memory Used: {memory_used:.2f} MB
            Peak Memory: {end_memory:.2f} MB
            """)
    
    def optimize_parquet_query(self, parquet_path: str, columns: list = None):
        """Demonstrate optimized Parquet querying with monitoring"""
        column_list = ', '.join(columns) if columns else '*'
        
        with self.monitor_query(f"Parquet Query - {parquet_path}"):
            # Get query plan
            plan = self.conn.execute(f"""
                EXPLAIN SELECT {column_list}
                FROM '{parquet_path}'
                WHERE date >= '2023-01-01'
            """).fetchall()
            
            self.logger.info(f"Query Plan: {plan}")
            
            # Execute optimized query
            result = self.conn.execute(f"""
                SELECT {column_list}
                FROM '{parquet_path}'
                WHERE date >= '2023-01-01'
            """).fetchall()
            
            return result
```

## Conclusion

Following these best practices ensures:
- Optimal performance and resource utilization
- Data integrity and consistency
- Secure and maintainable code
- Effective integration with Delta Lake features
- Proper error handling and testing coverage
- Efficient external Parquet data management
- Seamless integration with complementary libraries (PyArrow, Polars, Ibis)
- Memory-efficient processing of large datasets
- Cross-platform analytical code portability

### Library Selection Guidelines Summary

| Use Case | Data Size | Recommended Approach |
|----------|-----------|---------------------|
| ETL Pipelines | < 1M rows | Polars |
| ETL Pipelines | 1M - 100M rows | DuckDB + Polars |
| ETL Pipelines | > 100M rows | DuckDB + PyArrow |
| Analytical Queries | Any size | DuckDB (or Ibis + DuckDB for portability) |
| Cross-platform | Any size | Ibis |
| Real-time Processing | Small datasets | Polars |
| Real-time Processing | Large datasets | PyArrow + DuckDB |
| Complex Transformations | Any size | Polars → DuckDB |
| Parquet-heavy Workloads | Any size | DuckDB + PyArrow |

Regular review and updates of these standards should be conducted as DuckDB, DuckLake, and the broader Python data ecosystem evolve with new features and improvements.