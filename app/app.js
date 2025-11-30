const express = require('express');
const { Pool } = require('pg');
const app = express();
const port = 3000;

app.use(express.json());

// Determine SSL setting for pg client.
// Priority: explicit DB_SSL env var ('true' => enable) then PGSSLMODE ('require'/'verify-ca'/'verify-full' => enable).
const dbSslEnv = process.env.DB_SSL;
const pgSslMode = process.env.PGSSLMODE;

let sslOption = false;
if (dbSslEnv === 'true') {
  sslOption = { rejectUnauthorized: false };
} else if (pgSslMode && ['require', 'verify-ca', 'verify-full'].includes(pgSslMode)) {
  sslOption = { rejectUnauthorized: false };
} else {
  sslOption = false;
}

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'orders_db',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: sslOption
});

// Test database connection and auto-create schema
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Database connection error:', err.message);
  } else {
    console.log('✅ Database connected successfully at', res.rows[0].now);
    
    // Auto-create table if it doesn't exist
    pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        status VARCHAR(50) NOT NULL DEFAULT 'created',
        region VARCHAR(50) NOT NULL,
        data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_orders_region ON orders(region);
    `, (createErr) => {
      if (createErr) {
        console.error('❌ Error creating table:', createErr.message);
      } else {
        console.log('✅ Orders table ready');
      }
    });
  }
});

app.get('/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.status(200).json({
            status: 'healthy',
            region: process.env.AWS_REGION || 'local',
            database: 'connected',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            region: process.env.AWS_REGION || 'local',
            database: 'disconnected', 
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

app.get('/', (req, res) => {
    res.json({
        message: 'Disater Recovery Order Processing System - Checkpoint 2',
        region: process.env.AWS_REGION || 'local',
        version: '3.0.0',
        database: 'PostgreSQL (RDS)',
        features: [
            'Persistent storage',
            'Multi-AZ database',
            'Data consistency across instances',
            'Databse replication'
        ],
        endpoints: {
            health: 'GET /health',
            createOrder: 'POST api/orders',
            listOrders: 'GET api/orders',
            getOrder: 'GET /api/orders/:id'
        }
    });
});

app.post('/api/orders', async (req, res) => {
  try {
    const result = await pool.query(
      `INSERT INTO orders (status, region, data, created_at) 
       VALUES ($1, $2, $3, NOW()) 
       RETURNING id, status, region, data, created_at`,
      ['created', process.env.AWS_REGION || 'local', req.body] 
    );
    
    const order = {
      orderId: `ORD-${result.rows[0].id}`,
      status: result.rows[0].status,
      region: result.rows[0].region,
      timestamp: result.rows[0].created_at,
      data: result.rows[0].data  
    };

        console.log(`Order created: ${order.orderId} in region ${order.region}`);
        res.status(201).json(order);
    } catch (error) {
        console.error('Error creating order:', error.message);
        res.status(500).json({
            error: 'Failed to create order',
            message: error.message
        });
    }
});

app.get('/api/orders', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, status, region, data, created_at FROM orders ORDER BY created_at DESC'
    );
    
    const orders = result.rows.map(row => ({
      orderId: `ORD-${row.id}`,
      status: row.status,
      region: row.region,
      timestamp: row.created_at,
      data: row.data  
    }));

        res.json({
            count: orders.length,
            region: process.env.AWS_REGION || 'local',
            database: 'PostgreSQL',
            orders: orders
        });
    } catch (error) {
        console.error('Error getting orders:', error.message);
        res.status(500).json({
            error: 'Failed to get orders',
            messge: error.message
        });
    }
});

app.get('/api/orders/:id', async (req, res) => {
    try {
        const orderId = req.params.id.replace('ORD-', '');
        const result = await pool.query(
            `SELECT id, status, region, data, created_at 
            FROM orders
            WHERE id = $1`,
            [orderId]
        );

        if(result.rows.length === 0) {
            return res.status(404).json({
                error: 'Order not found'
            });
        }

        const row = result.rows[0]

        const order = {
            orderId: `ORD-${row.id}`,
            status: row.status,
            region: row.region,
            timestamp: row.created_at,
            data: row.data  // ← Don't parse
        };

        res.json(order);
        
    } catch (error) {
        console.error('Error getting order: ', error.message);
        res.status(500).json({
            error: 'Failed to get order',
            message: error.message
        })
        
    }
});

process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    pool.end();
});

app.listen(port, () => {
    console.log(`Order Processing API running on port ${port}`);
    console.log(`Health check: http://localhost:${port}/health`);
    console.log(`Region: ${process.env.AWS_REGION || 'local'}`);
    console.log(`Database: PostgreSQL`);
});