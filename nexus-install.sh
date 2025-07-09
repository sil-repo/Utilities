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
NC='\033[0m' # No Colour

# Visual header
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    ${WHITE}NEXUS INSTALL/UPDATE v1.6.1 SCRIPT${PURPLE}                    ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load the Git token
# If token cannot be found, we'll use GitHub Device Flow for authorisation
#    - This will provide a browser link for secure authorisation
#    - Alternative: Create a PAT token file: `echo "PATCodeInHere" > /git_token`
#    - Secure the file: `chmod 600 /git_token`.
if [ -f /git_token ]; then
    export GIT_TOKEN=$(cat /git_token)
    echo -e "${GREEN}✓ Using GitHub token from /git_token${NC}"
else
    echo -e "${YELLOW}⚠ No /git_token file found. Starting GitHub Device Flow authorisation...${NC}"
    echo -e "${CYAN}🔗 This will provide a browser link for secure authorisation.${NC}"
    echo ""
    
    # Start GitHub Device Flow
    echo -e "${BLUE}📱 Requesting device authorisation from GitHub...${NC}"
    
    # Use a public client ID for GitHub CLI (safe to use)
    CLIENT_ID="178c6fc778ccc68e1d6a"
    
    DEVICE_RESPONSE=$(curl -s -X POST \
        -H "Accept: application/json" \
        -H "User-Agent: Nexus-Installer" \
        -d "client_id=$CLIENT_ID&scope=repo" \
        https://github.com/login/device/code)
    
    # Debug: Show raw response (remove this line in production)
    echo -e "${BLUE}Debug - Raw response: $DEVICE_RESPONSE${NC}"
    
    if [ $? -eq 0 ] && [ -n "$DEVICE_RESPONSE" ]; then
        # Use jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.device_code // empty')
            USER_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.user_code // empty')
            VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | jq -r '.verification_uri // empty')
            INTERVAL=$(echo "$DEVICE_RESPONSE" | jq -r '.interval // 5')
        else
            # Fallback parsing without jq
            DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | sed -n 's/.*"device_code":"\([^"]*\)".*/\1/p')
            USER_CODE=$(echo "$DEVICE_RESPONSE" | sed -n 's/.*"user_code":"\([^"]*\)".*/\1/p')
            VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | sed -n 's/.*"verification_uri":"\([^"]*\)".*/\1/p')
            INTERVAL=$(echo "$DEVICE_RESPONSE" | sed -n 's/.*"interval":\([0-9]*\).*/\1/p')
        fi
        
        # Set default interval if parsing failed
        INTERVAL=${INTERVAL:-5}
        
        if [ -n "$USER_CODE" ] && [ -n "$VERIFICATION_URI" ] && [ -n "$DEVICE_CODE" ]; then
            echo -e "${GREEN}✅ Device authorisation initiated successfully!${NC}"
            echo ""
            echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${WHITE}║                    ${YELLOW}GITHUB AUTHORISATION${WHITE}                    ║${NC}"
            echo -e "${WHITE}╠══════════════════════════════════════════════════════════════╣${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}║  ${YELLOW}🌐 Please open this URL in your browser:${WHITE}                ║${NC}"
            echo -e "${WHITE}║     ${CYAN}${VERIFICATION_URI}${WHITE}$(printf "%*s" $((48 - ${#VERIFICATION_URI})) "")║${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}║  ${YELLOW}🔑 Enter this code when prompted:${WHITE}                      ║${NC}"
            echo -e "${WHITE}║     ${GREEN}${USER_CODE}${WHITE}$(printf "%*s" $((52 - ${#USER_CODE})) "")║${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}║  ${BLUE}💡 Copy the URL and code above to authorise${WHITE}            ║${NC}"
            echo -e "${WHITE}║     in your browser, then return here.${WHITE}                  ║${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${BLUE}⏳ Waiting for authorisation... (Press Ctrl+C to cancel)${NC}"
            echo ""
            
            # Poll for authorisation
            MAX_ATTEMPTS=120  # 10 minutes at 5-second intervals
            ATTEMPT=0
            
            while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
                sleep $INTERVAL
                TOKEN_RESPONSE=$(curl -s -X POST \
                    -H "Accept: application/json" \
                    -H "User-Agent: Nexus-Installer" \
                    -d "client_id=$CLIENT_ID&device_code=$DEVICE_CODE&grant_type=urn:ietf:params:oauth:grant-type:device_code" \
                    https://github.com/login/oauth/access_token)
                
                if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
                    if command -v jq >/dev/null 2>&1; then
                        GIT_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
                    else
                        GIT_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
                    fi
                    
                    if [ -n "$GIT_TOKEN" ]; then
                        export GIT_TOKEN
                        echo -e "${GREEN}✅ Authorisation successful! Token acquired.${NC}"
                        echo -e "${BLUE}💾 Saving token to /git_token for future use...${NC}"
                        echo "$GIT_TOKEN" > /git_token
                        chmod 600 /git_token
                        echo -e "${GREEN}✓ Token saved successfully${NC}"
                        break
                    fi
                elif echo "$TOKEN_RESPONSE" | grep -q "authorization_pending"; then
                    echo -e "${YELLOW}⏳ Still waiting for authorisation... (${ATTEMPT}/${MAX_ATTEMPTS} - $(( (MAX_ATTEMPTS - ATTEMPT) * INTERVAL / 60 )) minutes remaining)${NC}"
                elif echo "$TOKEN_RESPONSE" | grep -q "slow_down"; then
                    INTERVAL=$((INTERVAL + 5))
                    echo -e "${YELLOW}🐌 Slowing down polling interval to ${INTERVAL} seconds...${NC}"
                elif echo "$TOKEN_RESPONSE" | grep -q "expired_token"; then
                    echo -e "${RED}❌ Device code expired. Please restart the script.${NC}"
                    exit 1
                elif echo "$TOKEN_RESPONSE" | grep -q "access_denied"; then
                    echo -e "${RED}❌ Authorisation denied. Please restart the script.${NC}"
                    exit 1
                else
                    echo -e "${YELLOW}⚠ Waiting for authorisation... (response: $(echo "$TOKEN_RESPONSE" | head -c 50)...)${NC}"
                fi
                
                ATTEMPT=$((ATTEMPT + 1))
            done
            
            if [ -z "$GIT_TOKEN" ]; then
                echo -e "${RED}❌ Authorisation timeout after 10 minutes.${NC}"
                echo -e "${YELLOW}💡 You can also create a Personal Access Token manually:${NC}"
                echo -e "${CYAN}   1. Go to: https://github.com/settings/tokens${NC}"
                echo -e "${CYAN}   2. Generate a new token with 'repo' scope${NC}"
                echo -e "${CYAN}   3. Save it to: echo 'YOUR_TOKEN' > /git_token${NC}"
                echo -e "${CYAN}   4. Secure it: chmod 600 /git_token${NC}"
                echo ""
                echo -e "${YELLOW}Falling back to username/password authorisation...${NC}"
                echo -e -n "${CYAN}GitHub Username: ${NC}"
                read GIT_USERNAME
            fi
        else
            echo -e "${RED}❌ Failed to parse GitHub response.${NC}"
            echo -e "${YELLOW}Debug info:${NC}"
            echo -e "  Device code: '${DEVICE_CODE}'"
            echo -e "  User code: '${USER_CODE}'"
            echo -e "  Verification URI: '${VERIFICATION_URI}'"
            echo ""
            echo -e "${YELLOW}Falling back to username/password authorisation...${NC}"
            echo -e -n "${CYAN}GitHub Username: ${NC}"
            read GIT_USERNAME
        fi
    else
        echo -e "${RED}❌ Failed to connect to GitHub.${NC}"
        echo -e "${YELLOW}Falling back to username/password authorisation...${NC}"
        echo -e -n "${CYAN}GitHub Username: ${NC}"
        read GIT_USERNAME
    fi
fi

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🚀 Starting Nexus repositories setup...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Branch selection - forced input
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    ${WHITE}BRANCH SELECTION${PURPLE}                            ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Please select which branch to install/update:${NC}"
echo -e "${GREEN}1) Live Branch (master)${NC} - Stable production version"
echo -e "${BLUE}2) Test Branch (test)${NC} - Development/testing version"
echo -e "${PURPLE}3) Advanced (Custom)${NC} - Select branch for each repository"
echo ""

# Loop until valid input is provided
BRANCH_CHOICE=""
while [ -z "$BRANCH_CHOICE" ]; do
    printf "${CYAN}Enter your choice (1, 2, or 3): ${NC}"
    read -r BRANCH_CHOICE < /dev/tty
    
    case "$BRANCH_CHOICE" in
        1)
            BRANCH="master"
            DOCKER_COMPOSE_FILE="docker-compose-prod.yaml"
            echo -e "${GREEN}✓ Selected: Live Branch (master)${NC}"
            ;;
        2)
            BRANCH="test"
            DOCKER_COMPOSE_FILE="docker-compose-test.yaml"
            echo -e "${BLUE}✓ Selected: Test Branch (test)${NC}"
            ;;
        3)
            echo -e "${ORANGE}✓ Selected: Advanced (Custom)${NC}"
            ;;
        "")
            echo -e "${RED}❌ No input provided. Please enter 1, 2, or 3.${NC}"
            BRANCH_CHOICE=""
            ;;
        *)
            echo -e "${RED}❌ Invalid choice '${BRANCH_CHOICE}'. Please enter 1, 2, or 3.${NC}"
            BRANCH_CHOICE=""
            ;;
    esac
done
echo ""

# Function to select branch for a repository
select_branch() {
    local repo_name=$1
    local branch=""
    
    while [ -z "$branch" ]; do
        echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║                    ${WHITE}SELECT BRANCH: ${repo_name}${PURPLE}                    ║${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}1) Live Branch (master)${NC} - Stable production version"
        echo -e "${BLUE}2) Development Branch (dev)${NC} - Development version"
        echo -e "${YELLOW}3) Test Branch (test)${NC} - Testing version"
        echo -e "${RED}4) Skip this repository${NC}"
        echo ""
        printf "${CYAN}Enter your choice (1-4): ${NC}"
        read -r choice < /dev/tty
        
        case "$choice" in
            1)
                branch="master"
                echo -e "${GREEN}✓ Selected: Live Branch (master)${NC}"
                ;;
            2)
                branch="dev"
                echo -e "${BLUE}✓ Selected: Development Branch (dev)${NC}"
                ;;
            3)
                branch="test"
                echo -e "${YELLOW}✓ Selected: Test Branch (test)${NC}"
                ;;
            4)
                branch="none"
                echo -e "${RED}✓ Skipping this repository${NC}"
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter a number between 1 and 4.${NC}"
                ;;
        esac
    done
    echo ""
    echo "$branch"
}

# If Advanced (Custom) option is selected, choose branch for each repository
if [ "$BRANCH_CHOICE" = "3" ]; then
    echo -e "${PURPLE}✓ Selected: Advanced (Custom Branch Selection)${NC}"
    echo ""
    NEXUS_CORE_BRANCH=$(select_branch "Nexus Core")
    NEXUS_CUSTOM_BRANCH=$(select_branch "Nexus Custom")
    NEXUS_IMPLEMENTATION_BRANCH=$(select_branch "Nexus Implementation")
    DOCKER_COMPOSE_FILE="docker-compose-custom.yaml"
else
    NEXUS_CORE_BRANCH=$BRANCH
    NEXUS_CUSTOM_BRANCH=$BRANCH
    NEXUS_IMPLEMENTATION_BRANCH=$BRANCH
fi

# Create nexus directory if it doesn't exist
mkdir -p ~/nexus

# Handle Nexus Core (nexus-app)
handle_repository() {
    local repo_name=$1
    local repo_path=$2
    local repo_url=$3
    local branch=$4

    if [ "$branch" = "none" ]; then
        echo -e "${YELLOW}Skipping ${repo_name} as 'None' was selected${NC}"
        return
    fi

    if [ -d "$repo_path" ]; then
        echo -e "${CYAN}🔄 Updating ${repo_name} (${branch} branch)${NC}"
        echo -e "${CYAN}$(printf '%0.s─' {1..${#repo_name}})${NC}"
        cd "$repo_path"
        if [ -n "$GIT_TOKEN" ]; then
            git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin "$branch"
        else
            echo -e -n "${YELLOW}🔐 GitHub Password for ${repo_name}: ${NC}"
            read -s GIT_PASSWORD
            echo ""
            git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin "$branch"
            unset GIT_PASSWORD
        fi
        echo -e "${GREEN}✓ ${repo_name} updated successfully${NC}"
    else
        echo -e "${GREEN}🆕 Creating ${repo_name} (${branch} branch)${NC}"
        echo -e "${GREEN}$(printf '%0.s─' {1..${#repo_name}})${NC}"
        cd ~/nexus
        if [ -n "$GIT_TOKEN" ]; then
            git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' clone -b "$branch" "$repo_url" "$(basename "$repo_path")"
        else
            echo -e -n "${YELLOW}🔐 GitHub Password for ${repo_name}: ${NC}"
            read -s GIT_PASSWORD
            echo ""
            git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone -b "$branch" "$repo_url" "$(basename "$repo_path")"
            unset GIT_PASSWORD
        fi
        echo -e "${GREEN}✓ ${repo_name} created successfully${NC}"
    fi
    echo ""
}

handle_repository "Nexus Core" ~/nexus/nexus-app https://github.com/sil-repo/Nexus.git "$NEXUS_CORE_BRANCH"
handle_repository "Nexus Custom" ~/nexus/nexus-custom https://github.com/sil-repo/Nexus-PAS.git "$NEXUS_CUSTOM_BRANCH"
handle_repository "Nexus Implementation" ~/nexus/nexus-implementation https://github.com/sil-repo/Nexus-implementation.git "$NEXUS_IMPLEMENTATION_BRANCH"

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🔧 Update complete. Deploying using ${DOCKER_COMPOSE_FILE}...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

cd /home/source/nexus

if [ "$DOCKER_COMPOSE_FILE" = "docker-compose-custom.yaml" ]; then
    echo -e "${YELLOW}Creating custom docker-compose file...${NC}"
    cp docker-compose-prod.yaml "$DOCKER_COMPOSE_FILE"
    # You may want to add logic here to modify the custom docker-compose file based on the selected branches
fi

docker compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans

echo ""
echo -e "${BLUE}📊 Container status:${NC}"
docker compose -f "$DOCKER_COMPOSE_FILE" ps

echo ""
echo -e "${BLUE}📜 Recent logs for nexus (last 20 lines):${NC}"
docker compose -f "$DOCKER_COMPOSE_FILE" logs --tail=20 nexus

echo ""
echo -e "${YELLOW}** Please check uptime and logs as required. **${NC}"
echo ""
echo -e "${GREEN}✅ Installation/update completed using ${DOCKER_COMPOSE_FILE}${NC}"
