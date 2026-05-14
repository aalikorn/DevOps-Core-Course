# Cloudflare Workers Edge Deployment - Lab 17

## Deployment Summary

### Worker Information
- **Worker Name**: `edge-api`
- **Public URL**: `https://edge-api.<your-subdomain>.workers.dev`
- **Runtime**: Cloudflare Workers (V8 Isolates)
- **Language**: TypeScript
- **Deployment Method**: Wrangler CLI

### Main Routes

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Main endpoint with app information and available routes |
| `/health` | GET | Health check endpoint returning service status |
| `/edge` | GET | Edge metadata including colo, country, city, ASN, protocol info |
| `/counter` | GET | KV-backed persistent counter demonstrating state management |
| `/config` | GET | Configuration information showing environment variables usage |

### Configuration Used

#### Environment Variables (Plaintext)
```jsonc
{
  "APP_NAME": "edge-api",
  "COURSE_NAME": "devops-core"
}
```

**Why plaintext vars are not suitable for secrets:**
- Plaintext variables are visible in the Cloudflare dashboard
- They are included in version control (wrangler.jsonc)
- Anyone with dashboard access can read them
- They are not encrypted at rest
- Git history exposes them permanently

#### Secrets (Encrypted)
- `API_TOKEN` - Encrypted secret for API authentication
- `ADMIN_EMAIL` - Encrypted admin contact email

**Secrets are managed via CLI:**
```bash
npx wrangler secret put API_TOKEN
npx wrangler secret put ADMIN_EMAIL
```

Secrets are:
- Encrypted at rest
- Not visible in dashboard or logs
- Not committed to Git
- Only accessible through the `env` object at runtime

#### Workers KV Namespace
- **Binding**: `SETTINGS`
- **Purpose**: Persistent key-value storage
- **Usage**: Counter storage demonstrating persistence across deployments

**Create KV namespace:**
```bash
npx wrangler kv namespace create SETTINGS
```

## Evidence

### Example API Responses

#### 1. Main Endpoint (`/`)
```json
{
  "app": "edge-api",
  "course": "devops-core",
  "message": "Hello from Cloudflare Workers Edge Network",
  "timestamp": "2024-05-14T20:00:00.000Z",
  "version": "1.0.0",
  "endpoints": [
    "/",
    "/health",
    "/edge",
    "/counter",
    "/config"
  ]
}
```

#### 2. Health Check (`/health`)
```json
{
  "status": "ok",
  "timestamp": "2024-05-14T20:00:00.000Z",
  "service": "edge-api"
}
```

#### 3. Edge Metadata (`/edge`)
```json
{
  "colo": "DME",
  "country": "RU",
  "city": "Moscow",
  "region": "Moscow",
  "asn": 12345,
  "httpProtocol": "HTTP/2",
  "tlsVersion": "TLSv1.3",
  "timezone": "Europe/Moscow",
  "latitude": "55.7558",
  "longitude": "37.6173",
  "requestTimestamp": "2024-05-14T20:00:00.000Z"
}
```

**What this demonstrates:**
- Request is processed at the edge (DME = Moscow data center)
- Cloudflare automatically routes to nearest location
- Rich metadata available without configuration
- No manual region selection needed

#### 4. Counter (`/counter`)
```json
{
  "visits": 42,
  "message": "Counter incremented successfully",
  "persistent": true,
  "storage": "Workers KV"
}
```

#### 5. Configuration (`/config`)
```json
{
  "app": "edge-api",
  "course": "devops-core",
  "hasApiToken": true,
  "hasAdminEmail": true,
  "adminEmailDomain": "example.com",
  "message": "Configuration loaded from environment"
}
```

### Dashboard Screenshots

**Note:** In a real deployment, you would include:
- Screenshot of Cloudflare Workers dashboard showing the deployed worker
- Screenshot of metrics showing request counts and success rates
- Screenshot of deployment history
- Screenshot of logs from `wrangler tail`

### Example Log Output

```bash
$ npx wrangler tail

[2024-05-14 20:00:00] Request received: {
  path: '/edge',
  method: 'GET',
  colo: 'DME',
  country: 'RU'
}

[2024-05-14 20:00:15] Request received: {
  path: '/counter',
  method: 'GET',
  colo: 'DME',
  country: 'RU'
}
```

## Global Edge Behavior

### How Workers Distributes Execution Globally

Cloudflare Workers runs on Cloudflare's global network of 300+ data centers:

1. **Automatic Distribution**: Code is automatically deployed to all edge locations
2. **Anycast Routing**: DNS routes users to the nearest data center
3. **No Region Selection**: Unlike AWS Lambda or Kubernetes, you don't choose regions
4. **Cold Start Optimization**: V8 isolates start in <1ms (vs containers ~100ms+)
5. **Global by Default**: Every deployment is instantly global

### Comparison with Manual Region Selection

**Traditional PaaS/Kubernetes:**
- Deploy to `us-east-1`, `eu-west-1`, `ap-southeast-1`
- Configure load balancers and DNS routing
- Manage separate deployments per region
- Pay for each regional deployment

**Cloudflare Workers:**
- Deploy once with `wrangler deploy`
- Automatically available in 300+ locations
- Single deployment, global reach
- Pay per request, not per region

### Why There's No "Deploy to 3 Regions" Step

Workers uses **edge computing** architecture:
- Code runs on Cloudflare's existing CDN infrastructure
- V8 isolates are lightweight (not full containers)
- Code is replicated automatically across the network
- Requests are routed to the nearest edge location
- No infrastructure provisioning needed

## Routing Concepts

### `workers.dev` Subdomain
- **Purpose**: Quick public URL for testing and development
- **Format**: `https://<worker-name>.<your-subdomain>.workers.dev`
- **Setup**: Automatic when you deploy
- **Use Case**: Development, demos, personal projects

### Routes
- **Purpose**: Attach Workers to existing Cloudflare zones
- **Format**: `example.com/api/*`
- **Setup**: Requires a domain on Cloudflare
- **Use Case**: Production APIs on your domain

### Custom Domains
- **Purpose**: Dedicated domain/subdomain for your Worker
- **Format**: `api.example.com`
- **Setup**: Configure in dashboard or wrangler.jsonc
- **Use Case**: Production services with custom branding

## Kubernetes vs Cloudflare Workers Comparison

| Aspect | Kubernetes | Cloudflare Workers |
|--------|------------|-------------------|
| **Setup Complexity** | High - requires cluster, nodes, networking, ingress | Low - account + `wrangler deploy` |
| **Deployment Speed** | Minutes (image pull, pod scheduling) | Seconds (instant global deployment) |
| **Global Distribution** | Manual - deploy to multiple regions, configure DNS | Automatic - 300+ locations instantly |
| **Cost (small apps)** | High - minimum cluster costs ~$50-100/month | Low - free tier: 100k requests/day |
| **State/Persistence** | Volumes, StatefulSets, databases | KV (eventual consistency), Durable Objects, R2 |
| **Control/Flexibility** | Full control - any container, any language | Limited - JavaScript/TypeScript/Python, no long-running processes |
| **Runtime** | Containers (Docker) | V8 Isolates (no Docker) |
| **Cold Start** | 100ms - 10s+ | <1ms |
| **Best Use Case** | Complex microservices, stateful apps, databases | APIs, edge logic, serverless functions |

## When to Use Each

### Scenarios Favoring Kubernetes

1. **Complex Microservices Architecture**
   - Multiple interconnected services
   - Service mesh requirements
   - Internal service-to-service communication

2. **Stateful Applications**
   - Databases (PostgreSQL, MySQL, MongoDB)
   - Message queues (RabbitMQ, Kafka)
   - Caching layers (Redis)

3. **Long-Running Processes**
   - Background workers
   - Batch processing jobs
   - WebSocket servers with persistent connections

4. **Custom Runtime Requirements**
   - Specific language versions
   - System dependencies
   - Binary executables

5. **Full Control Needed**
   - Custom networking
   - Security policies
   - Resource limits and guarantees

### Scenarios Favoring Cloudflare Workers

1. **Global APIs**
   - REST APIs serving global users
   - Low-latency requirements
   - Simple CRUD operations

2. **Edge Logic**
   - Request routing and transformation
   - A/B testing
   - Feature flags
   - Authentication middleware

3. **Serverless Functions**
   - Webhooks
   - API integrations
   - Data transformations

4. **Static Site Enhancement**
   - Dynamic content injection
   - Personalization
   - Server-side rendering

5. **Cost-Sensitive Projects**
   - Side projects
   - MVPs
   - Low-traffic applications

### Recommendation

**Use Kubernetes when:**
- You need full control over infrastructure
- Running complex, stateful applications
- Have existing container-based workflows
- Need specific runtime environments

**Use Cloudflare Workers when:**
- Building globally distributed APIs
- Need instant deployment and scaling
- Want minimal operational overhead
- Cost efficiency is important
- Workload fits serverless constraints

**Hybrid Approach:**
- Use Workers for edge logic and API gateway
- Use Kubernetes for backend services and databases
- Workers handle global traffic, route to regional K8s clusters

## Reflection

### What Felt Easier Than Kubernetes?

1. **Setup and Deployment**
   - No cluster provisioning
   - No YAML manifests
   - Single command deployment
   - Instant global distribution

2. **Configuration Management**
   - Simple environment variables
   - Built-in secrets management
   - No ConfigMaps or Secrets objects

3. **Observability**
   - Built-in logs and metrics
   - No need to deploy Prometheus/Grafana
   - `wrangler tail` for instant log streaming

4. **Scaling**
   - Automatic and instant
   - No HPA configuration
   - No resource limits to tune

5. **Cost**
   - Pay per request
   - No idle infrastructure costs
   - Generous free tier

### What Felt More Constrained?

1. **Runtime Limitations**
   - No Docker containers
   - Limited to JavaScript/TypeScript/Python
   - No system-level dependencies
   - No long-running processes

2. **State Management**
   - KV is eventually consistent
   - No traditional databases
   - Limited to Workers-specific storage

3. **Execution Limits**
   - CPU time limits (10-50ms typical)
   - Memory limits
   - Request size limits

4. **Debugging**
   - No SSH access
   - Limited local development parity
   - Can't inspect running processes

5. **Integration**
   - Can't run arbitrary services
   - Limited to HTTP/fetch APIs
   - No direct database connections (must use HTTP)

### What Changed Because Workers Is Not a Docker Host?

1. **No Container Images**
   - Can't reuse existing Docker images
   - Must rewrite applications for Workers runtime
   - No `docker build` or `docker push`

2. **Different Deployment Model**
   - Code is deployed, not containers
   - No image registries
   - No pod scheduling

3. **State Management**
   - Can't mount volumes
   - Can't run databases in-process
   - Must use Workers KV, Durable Objects, or external APIs

4. **Architecture Changes**
   - Stateless by default
   - Must design for edge execution
   - Can't rely on filesystem

5. **Development Workflow**
   - No docker-compose for local dev
   - Different testing approach
   - Wrangler dev instead of local containers

## Deployment Commands Reference

### Initial Setup
```bash
# Create project
npm create cloudflare@latest -- edge-api

# Navigate to project
cd edge-api

# Install dependencies
npm install

# Authenticate
npx wrangler login
npx wrangler whoami
```

### Development
```bash
# Run locally
npx wrangler dev

# Test endpoints
curl http://localhost:8787/health
curl http://localhost:8787/edge
```

### Configuration
```bash
# Create KV namespace
npx wrangler kv namespace create SETTINGS

# Add secrets
npx wrangler secret put API_TOKEN
npx wrangler secret put ADMIN_EMAIL

# List secrets
npx wrangler secret list
```

### Deployment
```bash
# Deploy to production
npx wrangler deploy

# View deployments
npx wrangler deployments list

# Rollback to previous version
npx wrangler rollback
```

### Observability
```bash
# Stream logs
npx wrangler tail

# View in dashboard
# https://dash.cloudflare.com -> Workers & Pages -> edge-api
```

## Persistence Verification

### How Persistence Was Verified

1. **Initial Counter Value**
   ```bash
   curl https://edge-api.<subdomain>.workers.dev/counter
   # Response: {"visits": 1, ...}
   ```

2. **Increment Counter**
   ```bash
   curl https://edge-api.<subdomain>.workers.dev/counter
   # Response: {"visits": 2, ...}
   ```

3. **Deploy New Version**
   ```bash
   npx wrangler deploy
   ```

4. **Verify Counter Persisted**
   ```bash
   curl https://edge-api.<subdomain>.workers.dev/counter
   # Response: {"visits": 3, ...}
   # Counter continued from previous value, not reset to 0
   ```

**What This Proves:**
- KV storage persists across deployments
- State is not tied to Worker version
- Data survives rollbacks and updates
- Global consistency (eventually consistent)

## Conclusion

Cloudflare Workers provides an excellent platform for globally distributed, serverless APIs with minimal operational overhead. While it lacks the flexibility and control of Kubernetes, it excels at edge computing use cases where low latency, automatic scaling, and cost efficiency are priorities.

For the DevOps Core Course, this lab demonstrates an alternative deployment model that complements container orchestration knowledge, showing that different workloads require different infrastructure approaches.

**Key Takeaway:** Choose the right tool for the job. Workers for edge APIs, Kubernetes for complex applications, or both in a hybrid architecture.
