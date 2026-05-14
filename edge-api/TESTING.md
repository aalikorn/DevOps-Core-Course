# Testing Guide - Edge API

This document provides test cases and expected responses for all endpoints.

## Prerequisites

Set your Worker URL as an environment variable:
```bash
export WORKER_URL="https://edge-api.<your-subdomain>.workers.dev"
```

Or for local testing:
```bash
export WORKER_URL="http://localhost:8787"
```

## Test Cases

### 1. Health Check Endpoint

**Request:**
```bash
curl -i $WORKER_URL/health
```

**Expected Response:**
```
HTTP/2 200
content-type: application/json

{
  "status": "ok",
  "timestamp": "2024-05-14T20:00:00.000Z",
  "service": "edge-api"
}
```

**Validation:**
- Status code: 200
- Content-Type: application/json
- Response contains `status: "ok"`
- Timestamp is valid ISO 8601 format

---

### 2. Main Endpoint

**Request:**
```bash
curl -i $WORKER_URL/
```

**Expected Response:**
```
HTTP/2 200
content-type: application/json

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

**Validation:**
- Status code: 200
- Contains app name from environment variable
- Lists all available endpoints
- Version number present

---

### 3. Edge Metadata Endpoint

**Request:**
```bash
curl -i $WORKER_URL/edge
```

**Expected Response (Production):**
```
HTTP/2 200
content-type: application/json

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

**Note:** Values will vary based on your location and network.

**Validation:**
- Status code: 200
- Contains `colo` (data center code)
- Contains `country` (2-letter country code)
- Contains at least one additional field (city, asn, httpProtocol, tlsVersion)
- All values are populated (not null/undefined)

**Local Development Note:**
In local development, `request.cf` may be undefined or have limited data.

---

### 4. Counter Endpoint (Persistence Test)

**First Request:**
```bash
curl -i $WORKER_URL/counter
```

**Expected Response:**
```
HTTP/2 200
content-type: application/json

{
  "visits": 1,
  "message": "Counter incremented successfully",
  "persistent": true,
  "storage": "Workers KV"
}
```

**Second Request:**
```bash
curl -i $WORKER_URL/counter
```

**Expected Response:**
```json
{
  "visits": 2,
  "message": "Counter incremented successfully",
  "persistent": true,
  "storage": "Workers KV"
}
```

**Validation:**
- Status code: 200
- Counter increments on each request
- Value persists across requests
- Value persists after redeployment

**Persistence Test:**
```bash
# Get current count
curl $WORKER_URL/counter | jq .visits

# Deploy new version
npm run deploy

# Verify count persisted
curl $WORKER_URL/counter | jq .visits
# Should be previous count + 1, not reset to 1
```

---

### 5. Configuration Endpoint

**Request:**
```bash
curl -i $WORKER_URL/config
```

**Expected Response:**
```
HTTP/2 200
content-type: application/json

{
  "app": "edge-api",
  "course": "devops-core",
  "hasApiToken": true,
  "hasAdminEmail": true,
  "adminEmailDomain": "example.com",
  "message": "Configuration loaded from environment"
}
```

**Validation:**
- Status code: 200
- Shows environment variables (app, course)
- Confirms secrets exist without exposing values
- Shows partial secret data (email domain only)

---

### 6. 404 Not Found

**Request:**
```bash
curl -i $WORKER_URL/nonexistent
```

**Expected Response:**
```
HTTP/2 404

Not Found
```

**Validation:**
- Status code: 404
- Plain text response (not JSON)

---

## Automated Test Script

Save this as `test.sh`:

```bash
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

WORKER_URL="${1:-http://localhost:8787}"

echo "Testing Worker at: $WORKER_URL"
echo ""

# Test 1: Health Check
echo "Test 1: Health Check"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/health)
if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Health check returned 200"
else
    echo -e "${RED}✗ FAIL${NC} - Health check returned $STATUS"
fi
echo ""

# Test 2: Main Endpoint
echo "Test 2: Main Endpoint"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/)
if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Main endpoint returned 200"
else
    echo -e "${RED}✗ FAIL${NC} - Main endpoint returned $STATUS"
fi
echo ""

# Test 3: Edge Metadata
echo "Test 3: Edge Metadata"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/edge)
if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Edge endpoint returned 200"
else
    echo -e "${RED}✗ FAIL${NC} - Edge endpoint returned $STATUS"
fi
echo ""

# Test 4: Counter
echo "Test 4: Counter"
RESPONSE=$(curl -s $WORKER_URL/counter)
VISITS=$(echo $RESPONSE | jq -r .visits)
if [ ! -z "$VISITS" ] && [ "$VISITS" -gt 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Counter returned visits: $VISITS"
else
    echo -e "${RED}✗ FAIL${NC} - Counter failed"
fi
echo ""

# Test 5: Config
echo "Test 5: Config"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/config)
if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Config endpoint returned 200"
else
    echo -e "${RED}✗ FAIL${NC} - Config endpoint returned $STATUS"
fi
echo ""

# Test 6: 404
echo "Test 6: 404 Not Found"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/nonexistent)
if [ "$STATUS" -eq 404 ]; then
    echo -e "${GREEN}✓ PASS${NC} - 404 endpoint returned 404"
else
    echo -e "${RED}✗ FAIL${NC} - 404 endpoint returned $STATUS"
fi
echo ""

echo "Testing complete!"
```

**Usage:**
```bash
chmod +x test.sh

# Test local
./test.sh http://localhost:8787

# Test production
./test.sh https://edge-api.<your-subdomain>.workers.dev
```

---

## Performance Testing

### Latency Test

```bash
# Test from multiple locations using curl timing
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s $WORKER_URL/health

# Expected: < 100ms for most locations
```

### Load Test (Simple)

```bash
# Send 100 requests
for i in {1..100}; do
  curl -s $WORKER_URL/health > /dev/null &
done
wait

echo "100 requests completed"
```

### Global Distribution Test

Use a service like https://www.dotcom-tools.com/website-speed-test to test from multiple global locations.

Expected results:
- Low latency from all locations
- Consistent response times
- Different `colo` values from different regions

---

## Observability Testing

### Log Verification

1. Start log streaming:
   ```bash
   npm run tail
   ```

2. Make requests in another terminal:
   ```bash
   curl $WORKER_URL/edge
   curl $WORKER_URL/counter
   ```

3. Verify logs appear with:
   - Request path
   - Method
   - Colo
   - Country

### Metrics Verification

1. Go to Cloudflare Dashboard
2. Navigate to Workers & Pages → edge-api
3. Check metrics show:
   - Request count increasing
   - Success rate near 100%
   - CPU time < 10ms per request
   - No errors

---

## Deployment Testing

### Version 2 Deployment

1. Make a change to `src/index.ts`:
   ```typescript
   // Change version in main endpoint
   version: "2.0.0",
   ```

2. Deploy:
   ```bash
   npm run deploy
   ```

3. Test:
   ```bash
   curl $WORKER_URL/ | jq .version
   # Should return "2.0.0"
   ```

### Rollback Test

1. View deployments:
   ```bash
   npm run deployments
   ```

2. Rollback:
   ```bash
   npm run rollback
   ```

3. Verify:
   ```bash
   curl $WORKER_URL/ | jq .version
   # Should return "1.0.0"
   ```

---

## Troubleshooting

### Issue: All tests fail with connection errors

**Check:**
- Worker is deployed: `npm run deploy`
- URL is correct
- Network connectivity
- VPN settings (if applicable)

### Issue: Counter always returns 1

**Check:**
- KV namespace is created
- Namespace ID is correct in `wrangler.jsonc`
- Binding name matches code (`SETTINGS`)

### Issue: Config shows `hasApiToken: false`

**Check:**
- Secrets are added: `npx wrangler secret list`
- Secret names match code exactly (case-sensitive)
- Redeployed after adding secrets

### Issue: Edge metadata is null/undefined

**Check:**
- Testing production URL (not localhost)
- Request is going through Cloudflare network
- Using HTTPS (not HTTP)

---

## Test Results Template

Use this template to document your test results:

```markdown
## Test Results

**Date:** 2024-05-14
**Worker URL:** https://edge-api.<subdomain>.workers.dev

| Test | Status | Response Time | Notes |
|------|--------|---------------|-------|
| Health Check | ✓ PASS | 45ms | Status: ok |
| Main Endpoint | ✓ PASS | 48ms | All endpoints listed |
| Edge Metadata | ✓ PASS | 52ms | Colo: DME, Country: RU |
| Counter | ✓ PASS | 67ms | Visits: 15 |
| Config | ✓ PASS | 43ms | All vars present |
| 404 | ✓ PASS | 41ms | Correct status code |

**Persistence Test:**
- Initial counter: 15
- After redeploy: 16 ✓
- Persistence confirmed

**Global Distribution:**
- Moscow (DME): 45ms
- London (LHR): 52ms
- New York (EWR): 68ms
```
