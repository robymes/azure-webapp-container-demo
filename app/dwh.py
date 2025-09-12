import duckdb
import os
import toml

def load_config():
    """Load configuration from config.toml file"""
    try:
        with open('config.toml', 'r') as f:
            return toml.load(f)
    except FileNotFoundError:
        raise FileNotFoundError("Configuration file 'config.toml' not found")
    except toml.TomlDecodeError as e:
        raise ValueError(f"Invalid TOML in configuration file: {e}")

def setup_ducklake(config):
    """Initialize DuckLake extension and create/attach database"""
    conn = duckdb.connect()
    
    # Install DuckLake extension
    conn.execute("INSTALL ducklake;")
    
    # Create or attach to DuckLake database
    ducklake_path = config['database']['ducklake_path']
    data_path = config['database']['data_path']
    
    conn.execute(f"ATTACH 'ducklake:{ducklake_path}' AS ecommerce_db (DATA_PATH '{data_path}');")
    conn.execute("USE ecommerce_db;")
    
    return conn

def create_tables_if_not_exist(conn, config):
    """Create DuckLake tables from existing Parquet files if they don't exist"""
    
    # Get table names from config
    table_names = list(config['tables'].values())
    table_names_str = "', '".join(table_names)
    
    # Check if tables already exist
    tables_exist = conn.execute(f"""
        SELECT COUNT(*) as count FROM information_schema.tables
        WHERE table_name IN ('{table_names_str}')
    """).fetchone()[0]
    
    expected_tables = len(config['tables'])
    if tables_exist < expected_tables:
        print("Creating DuckLake tables from Parquet files...")
        
        # Build parquet file paths from config
        base_path = config['parquet_files']['base_path']
        parquet_files = {}
        for table_key, filename in config['parquet_files']['files'].items():
            table_name = config['tables'][table_key]
            parquet_path = os.path.join(base_path, filename)
            parquet_files[table_name] = parquet_path
        
        for table_name, parquet_path in parquet_files.items():
            if os.path.exists(parquet_path):
                print(f"Creating table {table_name}...")
                conn.execute(f"""
                    CREATE TABLE IF NOT EXISTS {table_name} AS
                    SELECT * FROM read_parquet('{parquet_path}')
                """)
            else:
                print(f"Warning: Parquet file {parquet_path} not found")
    
    return conn

def run_analytics_query(conn, config):
    """Run the main analytics query using DuckLake tables"""
    
    # Get table names from config
    orders_table = config['tables']['orders']
    order_items_table = config['tables']['order_items']
    products_table = config['tables']['products']
    product_reviews_table = config['tables']['product_reviews']
    customers_table = config['tables']['customers']
    top_countries_limit = config['analytics']['top_countries_limit']
    
    query = f"""
        WITH product_sales AS (
            SELECT
                o.shipping_country AS country,
                oi.product_id,
                p.product_name,
                SUM(o.total_amount) AS total_sales,
                SUM(oi.quantity) AS total_quantity
            FROM {orders_table} o
            JOIN {order_items_table} oi ON o.order_id = oi.order_id
            JOIN {products_table} p ON oi.product_id = p.product_id
            GROUP BY country, oi.product_id, p.product_name
        ),
        product_ratings AS (
            SELECT
                product_id,
                AVG(rating) AS avg_rating
            FROM {product_reviews_table}
            GROUP BY product_id
        ),
        product_customers AS (
            SELECT
                oi.product_id,
                COUNT(DISTINCT o.customer_id) AS customer_count,
                100.0 * SUM(CASE WHEN c.gender = 'Male' THEN 1 ELSE 0 END) / COUNT(DISTINCT o.customer_id) AS male_percent,
                100.0 * SUM(CASE WHEN c.gender = 'Female' THEN 1 ELSE 0 END) / COUNT(DISTINCT o.customer_id) AS female_percent
            FROM {orders_table} o
            JOIN {order_items_table} oi ON o.order_id = oi.order_id
            JOIN {customers_table} c ON o.customer_id = c.customer_id
            GROUP BY oi.product_id
        ),
        ranked_sales AS (
            SELECT ps.*, pr.avg_rating, pc.customer_count, pc.male_percent, pc.female_percent,
                RANK() OVER (PARTITION BY ps.country ORDER BY ps.total_sales DESC) AS rank
            FROM product_sales ps
            LEFT JOIN product_ratings pr ON ps.product_id = pr.product_id
            LEFT JOIN product_customers pc ON ps.product_id = pc.product_id
        ),
        top_countries AS (
            SELECT country, MAX(total_sales) AS max_sales
            FROM product_sales
            GROUP BY country
            ORDER BY max_sales DESC
            LIMIT {top_countries_limit}
        )
        SELECT rs.country, rs.product_name, rs.total_sales, rs.total_quantity, rs.avg_rating,
            rs.customer_count, rs.male_percent, rs.female_percent
        FROM ranked_sales rs
        JOIN top_countries tc ON rs.country = tc.country
        WHERE rs.rank = 1
        ORDER BY rs.total_sales DESC;
    """
    
    return conn.execute(query).df()

def init_dwh():
    try:
        # Load configuration
        config = load_config()
        print("Configuration loaded successfully")
        
        # Setup DuckLake
        conn = setup_ducklake(config)
        print("DuckLake database initialized successfully")
        
        # Create tables if they don't exist
        conn = create_tables_if_not_exist(conn, config)
        
        # Close connection
        conn.close()
        
    except Exception as e:
        print(f"Error: {e}")
        raise

def execute_query():
    """Main execution function"""
    try:
        # Load configuration
        config = load_config()
        print("Configuration loaded successfully")
        
        # Setup DuckLake
        conn = setup_ducklake(config)
        print("DuckLake database initialized successfully")
        
        # Run analytics query
        print("Running analytics query...")
        result = run_analytics_query(conn, config)
        
        # Display results
        results_title = config['display']['results_title']
        print(f"\n{results_title}")
        
        # Close connection
        conn.close()
        return result
        
    except Exception as e:
        print(f"Error: {e}")
        raise