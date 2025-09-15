# 📊 Data Warehouse Documentation

This document covers the DuckDB data warehouse integration, analytics capabilities, and configuration for the FastAPI application.

## Overview

The application integrates DuckDB as an embedded analytical database with DuckLake extension for data lakehouse functionality. It provides e-commerce analytics with sample data and pre-built queries.

## 🗃️ Database Architecture

### DuckDB Integration
- **Database Engine**: DuckDB - High-performance analytical database
- **Extension**: DuckLake - Data lakehouse with ACID transactions
- **Storage**: Persistent storage via Azure Files mount at `/data`
- **Configuration**: TOML-based flexible configuration

### Data Structure
```
/data/
├── ecommerce_analytics.ducklake    # Main DuckDB database
├── lakehouse/                      # Data lakehouse directory
└── archive/parquet/               # Parquet files storage
    ├── customers.parquet
    ├── products.parquet
    ├── orders.parquet
    ├── order_items.parquet
    └── product_reviews.parquet
```

## 📋 Configuration

### TOML Configuration File
Location: [`app/config.toml`](../app/config.toml)

```toml
[database]
ducklake_path = "/data/ecommerce_analytics.ducklake"
data_path = "/data/lakehouse/"

[parquet_files]
base_path = "/data/archive/parquet/"

[parquet_files.files]
customers = "customers.parquet"
products = "products.parquet"
orders = "orders.parquet"
order_items = "order_items.parquet"
product_reviews = "product_reviews.parquet"

[tables]
customers = "customers"
products = "products"
orders = "orders"
order_items = "order_items"
product_reviews = "product_reviews"

[analytics]
top_countries_limit = 10
```

### Configuration Parameters

#### Database Settings
- `ducklake_path`: Path to the main DuckDB database file
- `data_path`: Directory for lakehouse data storage

#### Parquet Configuration
- `base_path`: Base directory for Parquet files
- `files`: Mapping of logical names to Parquet filenames

#### Analytics Settings
- `top_countries_limit`: Number of top countries to include in analytics queries

## 🚀 Initialization

### Automatic Initialization
Initialize the data warehouse via API endpoint:

```bash
curl -X POST https://your-app.azurecontainerapps.io/init-dwh
```

### Manual Initialization
```python
from dwh import DataWarehouse

# Initialize with custom config
dwh = DataWarehouse(config_path="/app/config.toml")
await dwh.initialize_database()
```

### Initialization Process
1. **Database Creation**: Creates DuckDB database with DuckLake extension
2. **Table Schema**: Defines table structures for e-commerce data
3. **Sample Data**: Generates realistic sample data for testing
4. **Indexes**: Creates indexes for optimized query performance

## 📊 Data Schema

### Customers Table
```sql
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    gender VARCHAR,
    country VARCHAR,
    registration_date DATE
);
```

**Sample Data**: 5,000 customers with demographic information

### Products Table
```sql
CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR,
    category VARCHAR,
    price DECIMAL(10,2),
    description TEXT
);
```

**Sample Data**: 500 products across multiple categories

### Orders Table
```sql
CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    order_date DATE,
    total_amount DECIMAL(10,2),
    status VARCHAR,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
```

**Sample Data**: 10,000 orders with realistic date distribution

### Order Items Table
```sql
CREATE TABLE order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
```

**Sample Data**: 25,000 order items

### Product Reviews Table
```sql
CREATE TABLE product_reviews (
    review_id INTEGER PRIMARY KEY,
    product_id INTEGER,
    customer_id INTEGER,
    rating INTEGER,
    review_text TEXT,
    review_date DATE,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
```

**Sample Data**: 15,000 product reviews

## 📈 Analytics Queries

### Pre-built Analytics
The application includes pre-built analytics queries accessible via `/query` endpoint:

#### Customer Demographics by Country
```sql
SELECT 
    c.country,
    COUNT(DISTINCT c.customer_id) as total_customers,
    COUNT(CASE WHEN c.gender = 'Male' THEN 1 END) as male_customers,
    COUNT(CASE WHEN c.gender = 'Female' THEN 1 END) as female_customers,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(AVG(o.total_amount), 2) as avg_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.country
ORDER BY total_customers DESC
LIMIT 10;
```

#### Sales Performance by Category
```sql
SELECT 
    p.category,
    COUNT(DISTINCT oi.order_id) as total_orders,
    SUM(oi.quantity) as total_quantity_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) as total_revenue,
    ROUND(AVG(oi.unit_price), 2) as avg_price
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;
```

#### Customer Segmentation by Order Frequency
```sql
SELECT 
    CASE 
        WHEN order_count >= 10 THEN 'High Frequency'
        WHEN order_count >= 5 THEN 'Medium Frequency'
        ELSE 'Low Frequency'
    END as customer_segment,
    COUNT(*) as customer_count,
    ROUND(AVG(total_spent), 2) as avg_lifetime_value
FROM (
    SELECT 
        c.customer_id,
        COUNT(o.order_id) as order_count,
        COALESCE(SUM(o.total_amount), 0) as total_spent
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
) customer_stats
GROUP BY customer_segment
ORDER BY avg_lifetime_value DESC;
```

## 🔧 Advanced Features

### DuckLake Extension
- **ACID Transactions**: Ensures data consistency
- **Time Travel**: Query historical data states
- **Schema Evolution**: Modify table schemas without data loss
- **Compaction**: Automatic file optimization

### Parquet Integration
- **Direct Querying**: Query Parquet files without importing
- **Column Pruning**: Read only required columns
- **Predicate Pushdown**: Filter data at file level
- **Compression**: Efficient storage with compression

### Performance Optimization
- **Columnar Storage**: Optimized for analytical queries
- **Vectorized Execution**: Fast query processing
- **Parallel Processing**: Multi-threaded query execution
- **Memory Management**: Efficient memory usage

## 🔧 Custom Queries

### Execute Custom Queries
```python
import duckdb

# Connect to database
conn = duckdb.connect("/data/ecommerce_analytics.ducklake")

# Execute custom query
result = conn.execute("""
    SELECT country, COUNT(*) as customers
    FROM customers 
    WHERE registration_date >= '2023-01-01'
    GROUP BY country
    ORDER BY customers DESC
""").fetchall()

# Close connection
conn.close()
```

### Query Examples

#### Top Products by Revenue
```sql
SELECT 
    p.product_name,
    p.category,
    SUM(oi.quantity * oi.unit_price) as total_revenue,
    COUNT(DISTINCT oi.order_id) as order_count
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 20;
```

#### Monthly Sales Trend
```sql
SELECT 
    DATE_TRUNC('month', order_date) as month,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value
FROM orders
WHERE order_date >= '2023-01-01'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;
```

#### Customer Retention Analysis
```sql
WITH customer_orders AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', order_date) as order_month,
        COUNT(*) as orders_in_month
    FROM orders
    GROUP BY customer_id, DATE_TRUNC('month', order_date)
),
retention_data AS (
    SELECT 
        order_month,
        COUNT(DISTINCT customer_id) as active_customers,
        COUNT(DISTINCT CASE 
            WHEN LAG(order_month) OVER (PARTITION BY customer_id ORDER BY order_month) = order_month - INTERVAL '1 month'
            THEN customer_id 
        END) as retained_customers
    FROM customer_orders
    GROUP BY order_month
)
SELECT 
    order_month,
    active_customers,
    retained_customers,
    ROUND(retained_customers::FLOAT / active_customers * 100, 2) as retention_rate
FROM retention_data
ORDER BY order_month;
```

## 📊 Data Export and Import

### Export Data
```python
# Export to Parquet
conn.execute("""
    COPY (SELECT * FROM customers) 
    TO '/data/exports/customers_backup.parquet'
    (FORMAT PARQUET)
""")

# Export to CSV
conn.execute("""
    COPY (SELECT * FROM orders WHERE order_date >= '2024-01-01') 
    TO '/data/exports/recent_orders.csv'
    (HEADER, DELIMITER ',')
""")
```

### Import Data
```python
# Import from Parquet
conn.execute("""
    CREATE TABLE new_customers AS 
    SELECT * FROM read_parquet('/data/imports/new_customers.parquet')
""")

# Import from CSV
conn.execute("""
    CREATE TABLE imported_data AS 
    SELECT * FROM read_csv_auto('/data/imports/data.csv')
""")
```

## 🔍 Monitoring and Maintenance

### Database Statistics
```sql
-- Table sizes
SELECT 
    table_name,
    estimated_size,
    column_count
FROM duckdb_tables()
WHERE schema_name = 'main';

-- Query performance
EXPLAIN ANALYZE SELECT * FROM customers WHERE country = 'United States';
```

### Maintenance Operations
```python
# Vacuum database (cleanup)
conn.execute("VACUUM;")

# Analyze tables (update statistics)
conn.execute("ANALYZE;")

# Check database integrity
result = conn.execute("PRAGMA integrity_check;").fetchone()
```

## 🐛 Troubleshooting

### Common Issues

1. **Database File Not Found**
   ```bash
   # Check mount status
   ls -la /data/
   
   # Reinitialize if needed
   curl -X POST https://your-app.azurecontainerapps.io/init-dwh
   ```

2. **Query Performance Issues**
   ```sql
   -- Check query plan
   EXPLAIN SELECT * FROM large_table WHERE condition;
   
   -- Create indexes
   CREATE INDEX idx_customer_country ON customers(country);
   ```

3. **Memory Issues**
   ```python
   # Limit memory usage
   conn.execute("SET memory_limit='1GB';")
   
   # Use streaming for large results
   for batch in conn.execute("SELECT * FROM large_table").fetchmany(1000):
       process(batch)
   ```

### Performance Tuning

#### Optimize Query Performance
```sql
-- Use appropriate indexes
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- Partition large tables by date
CREATE TABLE orders_2024 AS 
SELECT * FROM orders WHERE order_date >= '2024-01-01';
```

#### Memory Configuration
```python
# Configure DuckDB settings
conn.execute("SET threads=4;")
conn.execute("SET memory_limit='2GB';")
conn.execute("SET max_memory='4GB';")
```

## 🔗 Integration Examples

### FastAPI Integration
```python
from fastapi import FastAPI, HTTPException
import duckdb
import toml

app = FastAPI()

@app.get("/analytics/sales-by-category")
async def sales_by_category():
    try:
        conn = duckdb.connect("/data/ecommerce_analytics.ducklake")
        result = conn.execute("""
            SELECT category, SUM(quantity * unit_price) as revenue
            FROM products p
            JOIN order_items oi ON p.product_id = oi.product_id
            GROUP BY category
            ORDER BY revenue DESC
        """).fetchall()
        
        return {"results": [{"category": row[0], "revenue": row[1]} for row in result]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
```

### Jupyter Notebook Integration
```python
import duckdb
import pandas as pd
import matplotlib.pyplot as plt

# Connect to database
conn = duckdb.connect("/data/ecommerce_analytics.ducklake")

# Query data into DataFrame
df = conn.execute("""
    SELECT country, COUNT(*) as customers
    FROM customers
    GROUP BY country
    ORDER BY customers DESC
    LIMIT 10
""").df()

# Visualize
df.plot(x='country', y='customers', kind='bar')
plt.title('Top 10 Countries by Customer Count')
plt.show()
```

## 🔗 Related Documentation

- [API Documentation](api.md)
- [Azure Deployment](azure-deployment.md)
- [Security Configuration](security.md)
- [Troubleshooting Guide](troubleshooting.md)

## 📚 Additional Resources

- [DuckDB Documentation](https://duckdb.org/docs/)
- [DuckLake Extension](https://github.com/duckdb/duckdb/blob/master/extension/delta/README.md)
- [Parquet Format Specification](https://parquet.apache.org/docs/)
- [Analytics Best Practices](https://duckdb.org/docs/guides/performance/overview)