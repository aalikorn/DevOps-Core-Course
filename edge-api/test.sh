#!/bin/bash

# Automated test script for Edge API
# Usage: ./test.sh [WORKER_URL]
# Example: ./test.sh https://edge-api.your-subdomain.workers.dev

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

WORKER_URL="${1:-http://localhost:8787}"

echo "=========================================="
echo "Edge API Test Suite"
echo "=========================================="
echo "Testing Worker at: $WORKER_URL"
echo ""

PASSED=0
FAILED=0

# Test 1: Health Check
echo "Test 1: Health Check"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/health)
if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Health check returned 200"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Health check returned $STATUS (expected 200)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2: Main Endpoint
echo "Test 2: Main Endpoint"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/)
RESPONSE=$(curl -s $WORKER_URL/)
APP_NAME=$(echo $RESPONSE | jq -r .app)
if [ "$STATUS" -eq 200 ] && [ "$APP_NAME" = "edge-api" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Main endpoint returned 200 with correct app name"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Main endpoint failed (status: $STATUS, app: $APP_NAME)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3: Edge Metadata
echo "Test 3: Edge Metadata"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/edge)
RESPONSE=$(curl -s $WORKER_URL/edge)
COLO=$(echo $RESPONSE | jq -r .colo)
if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ PASS${NC} - Edge endpoint returned 200"
    if [ "$COLO" != "null" ] && [ ! -z "$COLO" ]; then
        echo -e "  ${YELLOW}Info:${NC} Colo: $COLO"
    else
        echo -e "  ${YELLOW}Warning:${NC} Colo data not available (may be local dev)"
    fi
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Edge endpoint returned $STATUS"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 4: Counter (Persistence)
echo "Test 4: Counter (Persistence)"
RESPONSE1=$(curl -s $WORKER_URL/counter)
VISITS1=$(echo $RESPONSE1 | jq -r .visits)
sleep 1
RESPONSE2=$(curl -s $WORKER_URL/counter)
VISITS2=$(echo $RESPONSE2 | jq -r .visits)

if [ ! -z "$VISITS1" ] && [ ! -z "$VISITS2" ] && [ "$VISITS2" -gt "$VISITS1" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Counter incremented from $VISITS1 to $VISITS2"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Counter failed (visits1: $VISITS1, visits2: $VISITS2)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: Config
echo "Test 5: Config"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/config)
RESPONSE=$(curl -s $WORKER_URL/config)
HAS_TOKEN=$(echo $RESPONSE | jq -r .hasApiToken)
if [ "$STATUS" -eq 200 ] && [ "$HAS_TOKEN" = "true" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Config endpoint returned 200 with secrets configured"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Config endpoint failed (status: $STATUS, hasToken: $HAS_TOKEN)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: 404 Not Found
echo "Test 6: 404 Not Found"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WORKER_URL/nonexistent)
if [ "$STATUS" -eq 404 ]; then
    echo -e "${GREEN}✓ PASS${NC} - 404 endpoint correctly returned 404"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - 404 endpoint returned $STATUS (expected 404)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "Total:  $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC} ✓"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC} ✗"
    exit 1
fi
