#!/bin/bash
clear

# Colour definitions for visual appeal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Colour

# Visual header
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║              ${WHITE}NEXUS CONNECTION TEST v1.0.0${PURPLE}                  ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get server hostname
SERVER_NAME=$(hostname)
SERVER_NAME_LENGTH=${#SERVER_NAME}
PADDING=$(( (62 - SERVER_NAME_LENGTH - 2) / 2 ))
LEFT_PADDING=$(printf "%*s" $PADDING "")
RIGHT_PADDING=$(printf "%*s" $(( 62 - SERVER_NAME_LENGTH - 2 - PADDING )) "")

echo ""
echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                        ${CYAN}SERVER NAME${WHITE}                         ║${NC}"
echo -e "${WHITE}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${WHITE}║${LEFT_PADDING} ${GREEN}${SERVER_NAME}${WHITE} ${RIGHT_PADDING}║${NC}"
echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🔍 Testing Nexus Environment Configuration...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Test Results Tracking
TEST_RESULTS=()

# Test 1: Check for nexus directory
echo -e "${CYAN}📁 Test 1: Checking for nexus directory${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"
if [ -d ~/nexus ]; then
    echo -e "${GREEN}✅ ~/nexus directory exists${NC}"
    TEST_RESULTS+=("✅ Nexus directory found")
else
    echo -e "${RED}❌ ~/nexus directory not found${NC}"
    echo -e "${YELLOW}   Location would be: $(realpath ~/nexus 2>/dev/null || echo '~/nexus')${NC}"
    TEST_RESULTS+=("❌ Nexus directory missing")
fi
echo ""

# Test 2: Check for repository directories
echo -e "${CYAN}📂 Test 2: Checking for repository directories${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"

REPOS=(
    "nexus-app:Nexus Core"
    "nexus-custom:Nexus Custom"
    "nexus-implementation:Nexus Implementation"
)

for repo in "${REPOS[@]}"; do
    IFS=':' read -r repo_dir repo_name <<< "$repo"
    repo_path=~/nexus/$repo_dir
    
    if [ -d "$repo_path" ]; then
        echo -e "${GREEN}✅ $repo_name found at $repo_path${NC}"
        TEST_RESULTS+=("✅ $repo_name directory exists")
        
        # Check if it's a git repository
        if [ -d "$repo_path/.git" ]; then
            echo -e "${GREEN}   ├─ Git repository detected${NC}"
            cd "$repo_path"
            CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
            if [ -n "$CURRENT_BRANCH" ]; then
                echo -e "${GREEN}   └─ Current branch: ${CURRENT_BRANCH}${NC}"
            fi
        else
            echo -e "${YELLOW}   └─ Not a git repository${NC}"
        fi
    else
        echo -e "${RED}❌ $repo_name not found${NC}"
        echo -e "${YELLOW}   Expected at: $repo_path${NC}"
        TEST_RESULTS+=("❌ $repo_name directory missing")
    fi
done
echo ""

# Test 3: Check for docker-compose files
echo -e "${CYAN}🐳 Test 3: Checking for Docker Compose files${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"

COMPOSE_FILES=(
    "docker-compose-prod.yaml"
    "docker-compose.yaml"
    "docker-compose.yml"
)

cd ~/nexus 2>/dev/null
for compose_file in "${COMPOSE_FILES[@]}"; do
    if [ -f "$compose_file" ]; then
        echo -e "${GREEN}✅ $compose_file found${NC}"
        TEST_RESULTS+=("✅ $compose_file exists")
    else
        echo -e "${YELLOW}⚠  $compose_file not found${NC}"
    fi
done
echo ""

# Test 4: Check Git installation and version
echo -e "${CYAN}🔧 Test 4: Checking Git installation${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"
if command -v git >/dev/null 2>&1; then
    GIT_VERSION=$(git --version)
    echo -e "${GREEN}✅ Git is installed: $GIT_VERSION${NC}"
    TEST_RESULTS+=("✅ Git installed")
else
    echo -e "${RED}❌ Git is not installed${NC}"
    TEST_RESULTS+=("❌ Git not found")
fi
echo ""

# Test 5: Check for Git token
echo -e "${CYAN}🔑 Test 5: Checking for Git authentication${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"
if [ -f /git_token ]; then
    TOKEN_CONTENT=$(cat /git_token)
    TOKEN_LENGTH=${#TOKEN_CONTENT}
    if [ $TOKEN_LENGTH -gt 0 ]; then
        echo -e "${GREEN}✅ Git token file exists (/git_token)${NC}"
        echo -e "${GREEN}   └─ Token length: $TOKEN_LENGTH characters${NC}"
        TEST_RESULTS+=("✅ Git token configured")
    else
        echo -e "${YELLOW}⚠  Git token file is empty${NC}"
        TEST_RESULTS+=("⚠️  Git token file empty")
    fi
else
    echo -e "${YELLOW}⚠  No /git_token file found${NC}"
    echo -e "${CYAN}   Will use GitHub Device Flow when needed${NC}"
    TEST_RESULTS+=("⚠️  No git token (will use Device Flow)")
fi
echo ""

# Test 6: Test GitHub connectivity
echo -e "${CYAN}🌐 Test 6: Testing GitHub connectivity${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"

GITHUB_TEST=$(curl -s -o /dev/null -w "%{http_code}" https://github.com --max-time 10)
if [ "$GITHUB_TEST" = "200" ] || [ "$GITHUB_TEST" = "301" ] || [ "$GITHUB_TEST" = "302" ]; then
    echo -e "${GREEN}✅ GitHub is reachable (HTTP $GITHUB_TEST)${NC}"
    TEST_RESULTS+=("✅ GitHub connectivity OK")
else
    echo -e "${RED}❌ Cannot reach GitHub (HTTP $GITHUB_TEST)${NC}"
    TEST_RESULTS+=("❌ GitHub connectivity failed")
fi
echo ""

# Test 7: Test Git authentication (if token exists)
echo -e "${CYAN}🔐 Test 7: Testing Git authentication${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"

if [ -f /git_token ]; then
    export GIT_TOKEN=$(cat /git_token)
    if [ -n "$GIT_TOKEN" ]; then
        # Test authentication by checking access to a private repo
        echo -e "${BLUE}   Testing access to sil-repo/Nexus...${NC}"
        AUTH_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $GIT_TOKEN" \
            https://api.github.com/repos/sil-repo/Nexus \
            --max-time 10)
        
        if [ "$AUTH_TEST" = "200" ]; then
            echo -e "${GREEN}✅ Git authentication successful${NC}"
            echo -e "${GREEN}   └─ Successfully accessed sil-repo/Nexus${NC}"
            TEST_RESULTS+=("✅ Git authentication verified")
        elif [ "$AUTH_TEST" = "404" ]; then
            echo -e "${YELLOW}⚠  Token valid but repo not accessible (HTTP 404)${NC}"
            echo -e "${YELLOW}   Check repository name or permissions${NC}"
            TEST_RESULTS+=("⚠️  Token valid, repo access issue")
        elif [ "$AUTH_TEST" = "401" ]; then
            echo -e "${RED}❌ Authentication failed (HTTP 401)${NC}"
            echo -e "${RED}   Token may be invalid or expired${NC}"
            TEST_RESULTS+=("❌ Git authentication failed")
        else
            echo -e "${YELLOW}⚠  Unexpected response (HTTP $AUTH_TEST)${NC}"
            TEST_RESULTS+=("⚠️  Git auth test inconclusive")
        fi
    else
        echo -e "${YELLOW}⚠  Git token file is empty${NC}"
        TEST_RESULTS+=("⚠️  Cannot test - token empty")
    fi
else
    echo -e "${YELLOW}⚠  No git token to test${NC}"
    echo -e "${CYAN}   Device Flow authentication will be used during updates${NC}"
    TEST_RESULTS+=("⚠️  No token to test")
fi
echo ""

# Test 8: Check Docker installation
echo -e "${CYAN}🐋 Test 8: Checking Docker installation${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version 2>/dev/null)
    echo -e "${GREEN}✅ Docker is installed: $DOCKER_VERSION${NC}"
    TEST_RESULTS+=("✅ Docker installed")
    
    # Check if Docker is running
    if docker ps >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker daemon is running${NC}"
        RUNNING_CONTAINERS=$(docker ps -q | wc -l)
        echo -e "${GREEN}   └─ Running containers: $RUNNING_CONTAINERS${NC}"
        TEST_RESULTS+=("✅ Docker daemon running")
    else
        echo -e "${RED}❌ Docker daemon is not running${NC}"
        TEST_RESULTS+=("❌ Docker daemon not running")
    fi
else
    echo -e "${RED}❌ Docker is not installed${NC}"
    TEST_RESULTS+=("❌ Docker not found")
fi
echo ""

# Test 9: Check Docker Compose
echo -e "${CYAN}🐳 Test 9: Checking Docker Compose${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version 2>/dev/null)
    echo -e "${GREEN}✅ Docker Compose is available: $COMPOSE_VERSION${NC}"
    TEST_RESULTS+=("✅ Docker Compose available")
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null)
    echo -e "${GREEN}✅ Docker Compose (standalone) is installed: $COMPOSE_VERSION${NC}"
    TEST_RESULTS+=("✅ Docker Compose (standalone)")
else
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    TEST_RESULTS+=("❌ Docker Compose not found")
fi
echo ""

# Test 10: Check current Docker containers (if any)
echo -e "${CYAN}📦 Test 10: Checking existing Nexus containers${NC}"
echo -e "${CYAN}$(printf '%0.s─' {1..40})${NC}"
if docker ps >/dev/null 2>&1; then
    NEXUS_CONTAINERS=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)
    if [ -n "$NEXUS_CONTAINERS" ]; then
        echo -e "${GREEN}✅ Found Nexus-related containers:${NC}"
        while IFS= read -r container; do
            STATUS=$(docker ps -a --filter "name=$container" --format "{{.Status}}")
            if [[ "$STATUS" == Up* ]]; then
                echo -e "${GREEN}   ├─ $container (${STATUS})${NC}"
            else
                echo -e "${YELLOW}   ├─ $container (${STATUS})${NC}"
            fi
        done <<< "$NEXUS_CONTAINERS"
        TEST_RESULTS+=("✅ Nexus containers found")
    else
        echo -e "${YELLOW}⚠  No Nexus containers found${NC}"
        TEST_RESULTS+=("⚠️  No Nexus containers")
    fi
else
    echo -e "${YELLOW}⚠  Cannot check containers (Docker not accessible)${NC}"
fi
echo ""

# Summary
echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}📊 TEST SUMMARY${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

PASSED=0
FAILED=0
WARNINGS=0

for result in "${TEST_RESULTS[@]}"; do
    if [[ $result == ✅* ]]; then
        ((PASSED++))
        echo -e "$result"
    elif [[ $result == ❌* ]]; then
        ((FAILED++))
        echo -e "$result"
    elif [[ $result == ⚠️* ]]; then
        ((WARNINGS++))
        echo -e "$result"
    fi
done

echo ""
echo -e "${GREEN}Passed: $PASSED${NC} | ${RED}Failed: $FAILED${NC} | ${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     ✅ ALL TESTS PASSED                      ║${NC}"
    echo -e "${GREEN}║          Environment is ready for production updates        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ⚠️  TESTS FAILED                          ║${NC}"
    echo -e "${RED}║     Please resolve issues before running updates            ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
