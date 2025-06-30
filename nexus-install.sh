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
echo -e "${PURPLE}║                    ${WHITE}NEXUS INSTALL/UPDATE SCRIPT${PURPLE}                    ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load the Git token
# If token cannot be found, we'll use GitHub Device Flow for authentication
#    - This will provide a browser link for secure authentication
#    - Alternative: Create a PAT token file: `echo "PATCodeInHere" > /git_token`
#    - Secure the file: `chmod 600 /git_token`.
if [ -f /git_token ]; then
    export GIT_TOKEN=$(cat /git_token)
    echo -e "${GREEN}✓ Using GitHub token from /git_token${NC}"
else
    echo -e "${YELLOW}⚠ No /git_token file found. Starting GitHub Device Flow authentication...${NC}"
    echo -e "${CYAN}🔗 This will provide a browser link for secure authentication.${NC}"
    echo ""
    
    # Start GitHub Device Flow
    echo -e "${BLUE}📱 Requesting device authentication from GitHub...${NC}"
    
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
            echo -e "${GREEN}✅ Device authentication initiated successfully!${NC}"
            echo ""
            echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${WHITE}║                    ${YELLOW}GITHUB AUTHENTICATION${WHITE}                    ║${NC}"
            echo -e "${WHITE}╠══════════════════════════════════════════════════════════════╣${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}║  ${YELLOW}🌐 Please open this URL in your browser:${WHITE}                ║${NC}"
            echo -e "${WHITE}║     ${CYAN}${VERIFICATION_URI}${WHITE}$(printf "%*s" $((48 - ${#VERIFICATION_URI})) "")║${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}║  ${YELLOW}🔑 Enter this code when prompted:${WHITE}                      ║${NC}"
            echo -e "${WHITE}║     ${GREEN}${USER_CODE}${WHITE}$(printf "%*s" $((52 - ${#USER_CODE})) "")║${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}║  ${BLUE}💡 Copy the URL and code above to authenticate${WHITE}          ║${NC}"
            echo -e "${WHITE}║     in your browser, then return here.${WHITE}                  ║${NC}"
            echo -e "${WHITE}║                                                              ║${NC}"
            echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${BLUE}⏳ Waiting for authentication... (Press Ctrl+C to cancel)${NC}"
            echo ""
            
            # Poll for authentication
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
                        echo -e "${GREEN}✅ Authentication successful! Token acquired.${NC}"
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
                    echo -e "${RED}❌ Authentication denied. Please restart the script.${NC}"
                    exit 1
                else
                    echo -e "${YELLOW}⚠ Waiting for authentication... (response: $(echo "$TOKEN_RESPONSE" | head -c 50)...)${NC}"
                fi
                
                ATTEMPT=$((ATTEMPT + 1))
            done
            
            if [ -z "$GIT_TOKEN" ]; then
                echo -e "${RED}❌ Authentication timeout after 10 minutes.${NC}"
                echo -e "${YELLOW}💡 You can also create a Personal Access Token manually:${NC}"
                echo -e "${CYAN}   1. Go to: https://github.com/settings/tokens${NC}"
                echo -e "${CYAN}   2. Generate a new token with 'repo' scope${NC}"
                echo -e "${CYAN}   3. Save it to: echo 'YOUR_TOKEN' > /git_token${NC}"
                echo -e "${CYAN}   4. Secure it: chmod 600 /git_token${NC}"
                echo ""
                echo -e "${YELLOW}Falling back to username/password authentication...${NC}"
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
            echo -e "${YELLOW}Falling back to username/password authentication...${NC}"
            echo -e -n "${CYAN}GitHub Username: ${NC}"
            read GIT_USERNAME
        fi
    else
        echo -e "${RED}❌ Failed to connect to GitHub.${NC}"
        echo -e "${YELLOW}Falling back to username/password authentication...${NC}"
        echo -e -n "${CYAN}GitHub Username: ${NC}"
        read GIT_USERNAME
    fi
fi

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🚀 Starting Nexus repositories setup...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Branch selection
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    ${WHITE}BRANCH SELECTION${PURPLE}                         ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Please select which branch to install/update:${NC}"
echo -e "${GREEN}1) Live Branch (master)${NC} - Stable production version"
echo -e "${BLUE}2) Test Branch (test)${NC} - Development/testing version"
echo ""
echo -e -n "${CYAN}Enter your choice (1 or 2): ${NC}"
read BRANCH_CHOICE

case $BRANCH_CHOICE in
    1)
        BRANCH="master"
        echo -e "${GREEN}✓ Selected: Live Branch (master)${NC}"
        ;;
    2)
        BRANCH="test"
        echo -e "${BLUE}✓ Selected: Test Branch (test)${NC}"
        ;;
    *)
        echo -e "${YELLOW}⚠ Invalid choice. Defaulting to Live Branch (master)${NC}"
        BRANCH="master"
        ;;
esac
echo ""

# Create nexus directory if it doesn't exist
mkdir -p ~/nexus

# Handle Nexus Core (nexus-app)
if [ -d ~/nexus/nexus-app ]; then
    echo -e "${CYAN}🔄 Updating Nexus Core (${BRANCH} branch)${NC}"
    echo -e "${CYAN}────────────────────${NC}"
    cd ~/nexus/nexus-app
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin $BRANCH
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Core: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin $BRANCH
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Core updated successfully${NC}"
else
    echo -e "${GREEN}🆕 Creating Nexus Core (${BRANCH} branch)${NC}"
    echo -e "${GREEN}────────────────────${NC}"
    cd ~/nexus
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' clone -b $BRANCH https://github.com/sil-repo/Nexus.git nexus-app
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Core: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone -b $BRANCH https://github.com/sil-repo/Nexus.git nexus-app
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Core created successfully${NC}"
fi
echo ""

# Handle Nexus Custom
if [ -d ~/nexus/nexus-custom ]; then
    echo -e "${CYAN}🔄 Updating Nexus Custom (${BRANCH} branch)${NC}"
    echo -e "${CYAN}──────────────────────${NC}"
    cd ~/nexus/nexus-custom
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin $BRANCH
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Custom: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin $BRANCH
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Custom updated successfully${NC}"
else
    echo -e "${GREEN}🆕 Creating Nexus Custom (${BRANCH} branch)${NC}"
    echo -e "${GREEN}──────────────────────${NC}"
    cd ~/nexus
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' clone -b $BRANCH https://github.com/sil-repo/Nexus-PAS.git nexus-custom
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Custom: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone -b $BRANCH https://github.com/sil-repo/Nexus-PAS.git nexus-custom
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Custom created successfully${NC}"
fi
echo ""

# Handle Nexus Implementation
if [ -d ~/nexus/nexus-implementation ]; then
    echo -e "${CYAN}🔄 Updating Nexus Implementation (${BRANCH} branch)${NC}"
    echo -e "${CYAN}──────────────────────────────${NC}"
    cd ~/nexus/nexus-implementation
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin $BRANCH
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Implementation: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin $BRANCH
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Implementation updated successfully${NC}"
else
    echo -e "${GREEN}🆕 Creating Nexus Implementation (${BRANCH} branch)${NC}"
    echo -e "${GREEN}──────────────────────────────${NC}"
    cd ~/nexus
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' clone -b $BRANCH https://github.com/sil-repo/Nexus-implementation.git nexus-implementation
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Implementation: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone -b $BRANCH https://github.com/sil-repo/Nexus-implementation.git nexus-implementation
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Implementation created successfully${NC}"
fi
echo ""

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🔧Update complete. Attempting to restart the Nexus container...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

docker restart nexus
echo ""
docker ps | grep "nexus"
echo ""
docker logs nexus --tail 20
echo ""
echo "** Check uptime of container. If it has not reset, restart the container again**"
echo ""

