# Edge API - Cloudflare Workers

A serverless HTTP API deployed on Cloudflare's global edge network.

## Lab 17 - DevOps Core Course

This project demonstrates edge computing concepts using Cloudflare Workers, including:
- Global edge deployment
- Serverless architecture
- Environment variables and secrets
- Persistent state with Workers KV
- Observability and rollbacks

## Quick Start

### Prerequisites
- Node.js 18+
- npm
- Cloudflare account

### Setup

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Authenticate with Cloudflare**
   ```bash
   npx wrangler login
   ```

3. **Create KV namespace**
   ```bash
   npx wrangler kv namespace create SETTINGS
   ```
   
   Update `wrangler.jsonc` with the returned namespace ID.

4. **Add secrets**
   ```bash
   npx wrangler secret put API_TOKEN
   npx wrangler secret put ADMIN_EMAIL
   ```

### Development

```bash
# Run locally
npm run dev

# Test endpoints
curl http://localhost:8787/health
curl http://localhost:8787/edge
curl http://localhost:8787/counter
```

### Deployment

```bash
# Deploy to production
npm run deploy

# View logs
npm run tail

# View deployments
npm run deployments

# Rollback if needed
npm run rollback
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | App information and available routes |
| `GET /health` | Health check |
| `GET /edge` | Edge metadata (colo, country, city, etc.) |
| `GET /counter` | KV-backed persistent counter |
| `GET /config` | Configuration information |

## Project Structure

```
edge-api/
├── src/
│   └── index.ts          # Worker source code
├── wrangler.jsonc        # Worker configuration
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── WORKERS.md            # Detailed documentation
└── README.md             # This file
```

## Configuration

### Environment Variables (wrangler.jsonc)
- `APP_NAME` - Application name
- `COURSE_NAME` - Course identifier

### Secrets (via CLI)
- `API_TOKEN` - API authentication token
- `ADMIN_EMAIL` - Admin contact email

### KV Namespace
- `SETTINGS` - Persistent key-value storage

## Documentation

See [WORKERS.md](./WORKERS.md) for:
- Detailed deployment guide
- API examples
- Kubernetes vs Workers comparison
- Observability setup
- Best practices

## Resources

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Workers KV](https://developers.cloudflare.com/kv/)
- [Workers Examples](https://developers.cloudflare.com/workers/examples/)

## License

MIT
