const http = require('http');

const PORT = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url}`);

  if (req.url === '/health' || req.url === '/readiness') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'UP', timestamp }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'healthy',
    message: 'Hello from Cloud Run backend!',
    service: 'hello-backend',
    timestamp,
    headers: req.headers
  }));
});

server.listen(PORT, () => {
  console.log(`Hello backend server listening on port ${PORT}`);
});
