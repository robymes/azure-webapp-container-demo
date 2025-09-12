#!/bin/bash

# API Testing Script for FastAPI Application

# Configuration
BASE_URL="${1:-http://localhost:8000}"  # Use provided URL or default to localhost

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    log_test "$description"
    echo "URL: $method $BASE_URL$endpoint"
    
    if [[ -n "$data" ]]; then
        echo "Data: $data"
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    else
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X "$method" "$BASE_URL$endpoint")
    fi
    
    # Extract HTTP code and body
    http_code=$(echo "$response" | tail -n1 | cut -d: -f2)
    body=$(echo "$response" | head -n -1)
    
    echo "Response Code: $http_code"
    echo "Response Body: $body"
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        log_info "✅ Test passed"
    else
        log_error "❌ Test failed"
    fi
    
    echo "----------------------------------------"
}

main() {
    echo "=========================================="
    echo "    FastAPI Application Test Suite"
    echo "=========================================="
    echo "Base URL: $BASE_URL"
    echo "=========================================="
    echo
    
    # Test 1: Health Check (Root)
    test_endpoint "GET" "/" "" "Root endpoint health check"
    
    # Test 2: Detailed Health Check
    test_endpoint "GET" "/health" "" "Detailed health check with storage info"
    
    # Test 3: Write File
    test_endpoint "POST" "/write-file" \
        '{"content":"Hello World from API test!","filename":"api-test.txt"}' \
        "Write file with specified filename"
    
    # Test 4: Write File (auto-generated filename)
    test_endpoint "POST" "/write-file" \
        '{"content":"Hello World with auto filename!"}' \
        "Write file with auto-generated filename"
    
    # Test 5: List Files
    test_endpoint "GET" "/list-files" "" "List all files in persistent storage"
    
    # Test 6: Read File
    test_endpoint "GET" "/read-file/api-test.txt" "" "Read specific file content"
    
    # Test 7: Read Non-existent File (Error Case)
    test_endpoint "GET" "/read-file/nonexistent.txt" "" "Read non-existent file (should fail)"
    
    # Test 8: Invalid Write Request (Error Case)
    test_endpoint "POST" "/write-file" \
        '{"invalid":"data"}' \
        "Invalid write request (should fail)"
    
    echo "=========================================="
    echo "           Test Suite Complete"
    echo "=========================================="
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "FastAPI Application Test Script"
    echo
    echo "This script tests all API endpoints of the FastAPI application."
    echo
    echo "Usage: $0 [BASE_URL]"
    echo "       $0 --help"
    echo
    echo "Examples:"
    echo "  $0                                    # Test localhost:8000"
    echo "  $0 https://myapp.azurewebsites.net   # Test Azure deployment"
    exit 0
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    log_error "curl is not installed. Please install curl to run tests."
    exit 1
fi

# Run tests
main "$@"