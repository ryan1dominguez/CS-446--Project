const express = require('express');
const app = express();
const port = 3000;

app.use(express.json());

let orders = [];
let orderCounter = 1;

app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        region: process.env.AWS_REGION || 'local',
        timestamp: new Date().toISOString()
    });
});

app.get('/', (req, res) => {
    res.json({
        message: 'Disater Recovery Order Processing System',
        region: process.env.AWS_REGION || 'local',
        version: '1.0.0',
        endpoints: {
            health: '/health',
            orders: 'api/orders'
        }
    });
});

app.post('/api/orders', (req, res) => {
    const order = {
        orderId: `ORD-${orderCounter}`,
        status: 'created',
        region: process.env.AWS_REGION || 'local',
        timestamp: new Date().toISOString(),
        data: req.body
    };

    orders.push(order);
    orderCounter++;
    res.status(201).json(order);
});

app.get('/api/orders', (req, res) => {
    res.json({
        count: orders.length,
        region: process.env.AWS_REGION || 'local',
        orders: orders
    });
});

app.get('/api/orders/:id', (req, res) => {
    const orderId = req.params.id;
    const order = orders.find(o => o.orderId === orderId);

    if (order){
        res.json(order);
    } else {
        res.status(404).json({
            error: 'Order not found'
        });
    }
});

app.listen(port, () => {
    console.log(`Order Processing API running on port ${port}`);
    console.log(`Health check: http://localhost:${port}/health`);
    console.log(`Region: ${process.env.AWS_REGION || 'local'}`);
});