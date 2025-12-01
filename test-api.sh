#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

GATEWAY_URL="http://localhost:5921"

echo -e "${YELLOW}=== API Testing Script ===${NC}\n"

# Test 1: Gateway Health Check
echo -e "${YELLOW}Test 1: Gateway Health Check${NC}"
response=$(curl -s -w "\n%{http_code}" ${GATEWAY_URL}/health)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Gateway is healthy${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Gateway health check failed (HTTP $http_code)${NC}"
    echo "Response: $body"
fi
echo ""

# Test 2: Backend Health Check via Gateway
echo -e "${YELLOW}Test 2: Backend Health Check (via Gateway)${NC}"
response=$(curl -s -w "\n%{http_code}" ${GATEWAY_URL}/api/health)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Backend is healthy${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Backend health check failed (HTTP $http_code)${NC}"
    echo "Response: $body"
fi
echo ""

# Test 3: Create a Product
echo -e "${YELLOW}Test 3: Create a Product${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST ${GATEWAY_URL}/api/products \
    -H 'Content-Type: application/json' \
    -d '{"name":"Test Product","price":99.99}')
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "201" ]; then
    echo -e "${GREEN}✓ Product created successfully${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Product creation failed (HTTP $http_code)${NC}"
    echo "Response: $body"
fi
echo ""

# Test 4: Get All Products
echo -e "${YELLOW}Test 4: Get All Products${NC}"
response=$(curl -s -w "\n%{http_code}" ${GATEWAY_URL}/api/products)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Products retrieved successfully${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Failed to retrieve products (HTTP $http_code)${NC}"
    echo "Response: $body"
fi
echo ""

# Test 5: Security Test - Direct Backend Access (Should Fail)
echo -e "${YELLOW}Test 5: Security Test - Direct Backend Access${NC}"
echo "Attempting to access backend directly (should fail)..."
response=$(curl -s -w "\n%{http_code}" --connect-timeout 5 http://localhost:3847/api/products 2>&1)
http_code=$(echo "$response" | tail -n1)

if [[ "$response" == *"Connection refused"* ]] || [[ "$response" == *"Failed to connect"* ]] || [ "$http_code" != "200" ]; then
    echo -e "${GREEN}✓ Security test passed - Backend is not directly accessible${NC}"
else
    echo -e "${RED}✗ Security test failed - Backend is accessible directly!${NC}"
    echo "Response: $response"
fi
echo ""

# Test 6: Create Multiple Products
echo -e "${YELLOW}Test 6: Create Multiple Products${NC}"
products=(
    '{"name":"Laptop","price":1299.99}'
    '{"name":"Mouse","price":29.99}'
    '{"name":"Keyboard","price":79.99}'
)

for product in "${products[@]}"; do
    response=$(curl -s -w "\n%{http_code}" -X POST ${GATEWAY_URL}/api/products \
        -H 'Content-Type: application/json' \
        -d "$product")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "201" ]; then
        echo -e "${GREEN}✓ Created: $product${NC}"
    else
        echo -e "${RED}✗ Failed to create: $product${NC}"
    fi
done
echo ""

# Test 7: Verify All Products
echo -e "${YELLOW}Test 7: Verify All Products${NC}"
response=$(curl -s ${GATEWAY_URL}/api/products)
count=$(echo "$response" | jq '. | length' 2>/dev/null)

if [ ! -z "$count" ] && [ "$count" -gt 0 ]; then
    echo -e "${GREEN}✓ Total products in database: $count${NC}"
    echo "$response" | jq '.'
else
    echo -e "${RED}✗ No products found or error occurred${NC}"
    echo "Response: $response"
fi
echo ""

# Test 8: Input Validation Tests
echo -e "${YELLOW}Test 8: Input Validation Tests${NC}"

# Test invalid name
echo "Testing invalid name (empty string)..."
response=$(curl -s -w "\n%{http_code}" -X POST ${GATEWAY_URL}/api/products \
    -H 'Content-Type: application/json' \
    -d '{"name":"","price":99.99}')
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ Correctly rejected empty name${NC}"
else
    echo -e "${RED}✗ Should have rejected empty name (HTTP $http_code)${NC}"
fi

# Test invalid price
echo "Testing invalid price (negative)..."
response=$(curl -s -w "\n%{http_code}" -X POST ${GATEWAY_URL}/api/products \
    -H 'Content-Type: application/json' \
    -d '{"name":"Test","price":-10}')
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ Correctly rejected negative price${NC}"
else
    echo -e "${RED}✗ Should have rejected negative price (HTTP $http_code)${NC}"
fi
echo ""

echo -e "${YELLOW}=== Testing Complete ===${NC}"
