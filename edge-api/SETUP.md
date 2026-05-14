# Setup Guide - Edge API

This guide walks through the complete setup process for Lab 17.

## Step-by-Step Setup

### 1. Create Cloudflare Account

1. Go to https://dash.cloudflare.com/sign-up
2. Create a free account
3. Verify your email
4. Navigate to Workers & Pages section

### 2. Install Dependencies

```bash
cd edge-api
npm install
```

This installs:
- `wrangler` - Cloudflare Workers CLI
- `@cloudflare/workers-types` - TypeScript types
- `typescript` - TypeScript compiler

### 3. Authenticate with Cloudflare

```bash
npx wrangler login
```

This will:
- Open a browser window
- Ask you to authorize Wrangler
- Save authentication token locally

Verify authentication:
```bash
npx wrangler whoami
```

Expected output:
```
 ⛅️ wrangler 3.57.0
-------------------
Getting User settings...
👋 You are logged in with an OAuth Token, associated with the email '<your-email>@example.com'!
┌──────────────────────────┬──────────────────────────────────┐
│ Account Name             │ Account ID                        │
├──────────────────────────┼──────────────────────────────────┤
│ <Your Account>           │ <your-account-id>                │
└──────────────────────────┴──────────────────────────────────┘
```

### 4. Create KV Namespace

```bash
npx wrangler kv namespace create SETTINGS
```

Expected output:
```
🌀 Creating namespace with title "edge-api-SETTINGS"
✨ Success!
Add the following to your configuration file in your kv_namespaces array:
{ binding = "SETTINGS", id = "abc123def456..." }
```

**Important:** Copy the namespace ID and update `wrangler.jsonc`:

```jsonc
{
  "kv_namespaces": [
    {
      "binding": "SETTINGS",
      "id": "abc123def456..."  // Replace with your actual ID
    }
  ]
}
```

### 5. Add Secrets

```bash
# Add API token
npx wrangler secret put API_TOKEN
# Enter value when prompted: my-secret-token-123

# Add admin email
npx wrangler secret put ADMIN_EMAIL
# Enter value when prompted: admin@example.com
```

Verify secrets were added:
```bash
npx wrangler secret list
```

Expected output:
```
[
  {
    "name": "API_TOKEN",
    "type": "secret_text"
  },
  {
    "name": "ADMIN_EMAIL",
    "type": "secret_text"
  }
]
```

### 6. Test Locally

```bash
npm run dev
```

Expected output:
```
⛅️ wrangler 3.57.0
-------------------
⎔ Starting local server...
[wrangler:inf] Ready on http://localhost:8787
```

Test endpoints in another terminal:

```bash
# Health check
curl http://localhost:8787/health

# Main endpoint
curl http://localhost:8787/

# Edge metadata (limited in local dev)
curl http://localhost:8787/edge

# Counter
curl http://localhost:8787/counter

# Config
curl http://localhost:8787/config
```

### 7. Deploy to Production

```bash
npm run deploy
```

Expected output:
```
⛅️ wrangler 3.57.0
-------------------
Total Upload: 1.23 KiB / gzip: 0.56 KiB
Uploaded edge-api (1.23 sec)
Published edge-api (0.45 sec)
  https://edge-api.<your-subdomain>.workers.dev
Current Deployment ID: abc123-def456-ghi789
```

**Save your Worker URL!** You'll need it for testing and documentation.

### 8. Test Production Deployment

```bash
# Replace with your actual URL
export WORKER_URL="https://edge-api.<your-subdomain>.workers.dev"

# Test all endpoints
curl $WORKER_URL/health
curl $WORKER_URL/
curl $WORKER_URL/edge
curl $WORKER_URL/counter
curl $WORKER_URL/config
```

### 9. View Logs

In one terminal, start tailing logs:
```bash
npm run tail
```

In another terminal, make requests:
```bash
curl $WORKER_URL/edge
```

You should see logs appear in the first terminal:
```
[2024-05-14 20:00:00] Request received: {
  path: '/edge',
  method: 'GET',
  colo: 'DME',
  country: 'RU'
}
```

### 10. View Dashboard

1. Go to https://dash.cloudflare.com
2. Navigate to Workers & Pages
3. Click on `edge-api`
4. Explore:
   - Metrics (requests, errors, CPU time)
   - Logs
   - Settings
   - Deployments

## Verification Checklist

- [ ] Cloudflare account created
- [ ] Wrangler authenticated (`npx wrangler whoami` works)
- [ ] KV namespace created and ID added to `wrangler.jsonc`
- [ ] Secrets added (API_TOKEN, ADMIN_EMAIL)
- [ ] Local development works (`npm run dev`)
- [ ] Worker deployed successfully
- [ ] All endpoints return correct responses
- [ ] Logs visible with `npm run tail`
- [ ] Dashboard shows metrics
- [ ] Counter persists across requests

## Common Issues

### Issue: `wrangler login` fails or times out

**Possible causes:**
- Network restrictions (VPN, firewall, regional blocks)
- Cloudflare services blocked in your region

**Solutions:**
- Try a VPN with full-tunnel mode
- Use `wrangler login --scopes-list` to see required permissions
- Check https://www.cloudflarestatus.com/ for service status

### Issue: KV namespace not working

**Check:**
- Namespace ID is correct in `wrangler.jsonc`
- Binding name matches TypeScript interface (`SETTINGS`)
- Namespace was created for the correct account

### Issue: Secrets not accessible

**Check:**
- Secrets were added with correct names
- Names match TypeScript interface (case-sensitive)
- Redeploy after adding secrets

### Issue: TypeScript errors in editor

**Solution:**
```bash
npm install
```

The `@cloudflare/workers-types` package provides types for `KVNamespace`, `ExecutionContext`, and `request.cf`.

## Next Steps

1. **Test all endpoints** and capture responses for documentation
2. **Take screenshots** of the Cloudflare dashboard
3. **Make a code change** and deploy version 2
4. **Test rollback** functionality
5. **Complete WORKERS.md** with your actual deployment details
6. **Commit to Git** (but not secrets!)

## Deployment Workflow

```bash
# Make changes to src/index.ts
vim src/index.ts

# Test locally
npm run dev

# Deploy
npm run deploy

# View logs
npm run tail

# Check deployments
npm run deployments

# Rollback if needed
npm run rollback
```

## Git Workflow

```bash
# Initialize git (if not already done)
git init

# Add files
git add .

# Commit
git commit -m "Initial Cloudflare Workers deployment"

# Note: .gitignore already excludes:
# - node_modules/
# - .wrangler/
# - .dev.vars (local secrets)
```

**Never commit:**
- Secret values
- KV namespace IDs (if sensitive)
- `.dev.vars` file
- `node_modules/`

## Resources

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI Reference](https://developers.cloudflare.com/workers/wrangler/commands/)
- [Workers KV](https://developers.cloudflare.com/kv/)
- [Workers Examples](https://developers.cloudflare.com/workers/examples/)
- [Troubleshooting](https://developers.cloudflare.com/workers/observability/troubleshooting/)
