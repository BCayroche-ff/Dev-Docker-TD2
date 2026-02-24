const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');
const client = require('prom-client');

const app = express();
const PORT = process.env.PORT || 8080;

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:8081';
const PRODUCTS_SERVICE_URL = process.env.PRODUCTS_SERVICE_URL || 'http://localhost:8082';
const ORDERS_SERVICE_URL = process.env.ORDERS_SERVICE_URL || 'http://localhost:8083';

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register],
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path'],
  registers: [register],
});

app.use(cors());
app.use(express.json());

// Metrics middleware
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer({ method: req.method, path: req.path });
  res.on('finish', () => {
    httpRequestsTotal.inc({ method: req.method, path: req.path, status: res.statusCode });
    end();
  });
  next();
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'api-gateway', timestamp: new Date().toISOString() });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Proxy routes (pathFilter pour que http-proxy-middleware gere le routing, pas Express)
app.use('/api/auth', createProxyMiddleware({
  target: AUTH_SERVICE_URL,
  changeOrigin: true,
  pathRewrite: { '^/api/auth': '' },
  on: { proxyReq: (proxyReq, req) => { proxyReq.path = req.originalUrl.replace(/^\/api\/auth/, '') || '/'; } },
}));

app.use('/api/products', createProxyMiddleware({
  target: PRODUCTS_SERVICE_URL,
  changeOrigin: true,
  on: { proxyReq: (proxyReq, req) => { proxyReq.path = req.originalUrl.replace(/^\/api\/products/, '/products'); } },
}));

app.use('/api/orders', createProxyMiddleware({
  target: ORDERS_SERVICE_URL,
  changeOrigin: true,
  on: { proxyReq: (proxyReq, req) => { proxyReq.path = req.originalUrl.replace(/^\/api\/orders/, '/orders'); } },
}));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`API Gateway running on port ${PORT}`);
});
