#!/bin/bash
clear

# Colour for visual appeal
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
    echo -e "${CYAN}🔗 Please authenticate with GitHub using the browser link that will be provided.${NC}"
    echo ""
    
    # Start GitHub Device Flow
    echo -e "${BLUE}📱 Requesting device authentication from GitHub...${NC}"
    DEVICE_RESPONSE=$(curl -s -X POST \
        -H "Accept: application/json" \
        -H "User-Agent: Nexus-Installer" \
        -d "client_id=Ov23liOODBR1WJ8aJ0vL&scope=repo" \
        https://github.com/login/device/code)
    
    if [ $? -eq 0 ] && [ -n "$DEVICE_RESPONSE" ]; then
        DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | grep -o '"device_code":"[^"]*"' | cut -d'"' -f4)
        USER_CODE=$(echo "$DEVICE_RESPONSE" | grep -o '"user_code":"[^"]*"' | cut -d'"' -f4)
        VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | grep -o '"verification_uri":"[^"]*"' | cut -d'"' -f4)
        INTERVAL=$(echo "$DEVICE_RESPONSE" | grep -o '"interval":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$USER_CODE" ] && [ -n "$VERIFICATION_URI" ]; then
            echo -e "${GREEN}✅ Device authentication initiated successfully!${NC}"
            echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}🌐 Please open this URL in your browser:${NC}"
            echo -e "${CYAN}   ${VERIFICATION_URI}${NC}"
            echo ""
            echo -e "${YELLOW}🔑 Enter this code when prompted:${NC}"
            echo -e "${WHITE}   ${USER_CODE}${NC}"
            echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${BLUE}⏳ Waiting for authentication... (This may take a moment)${NC}"
            
            # Poll for authentication
            MAX_ATTEMPTS=60
            ATTEMPT=0
            INTERVAL=${INTERVAL:-5}
            
            while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
                sleep $INTERVAL
                TOKEN_RESPONSE=$(curl -s -X POST \
                    -H "Accept: application/json" \
                    -H "User-Agent: Nexus-Installer" \
                    -d "client_id=Ov23liOODBR1WJ8aJ0vL&device_code=$DEVICE_CODE&grant_type=urn:ietf:params:oauth:grant-type:device_code" \
                    https://github.com/login/oauth/access_token)
                
                if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
                    GIT_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
                    export GIT_TOKEN
                    echo -e "${GREEN}✅ Authentication successful! Token acquired.${NC}"
                    echo -e "${BLUE}💾 Saving token to /git_token for future use...${NC}"
                    echo "$GIT_TOKEN" > /git_token
                    chmod 600 /git_token
                    echo -e "${GREEN}✓ Token saved successfully${NC}"
                    break
                elif echo "$TOKEN_RESPONSE" | grep -q "authorization_pending"; then
                    echo -e "${YELLOW}⏳ Still waiting for authorization... (attempt $((ATTEMPT + 1))/${MAX_ATTEMPTS})${NC}"
                elif echo "$TOKEN_RESPONSE" | grep -q "slow_down"; then
                    INTERVAL=$((INTERVAL + 5))
                    echo -e "${YELLOW}🐌 Slowing down polling interval...${NC}"
                elif echo "$TOKEN_RESPONSE" | grep -q "expired_token"; then
                    echo -e "${RED}❌ Device code expired. Please restart the script.${NC}"
                    exit 1
                elif echo "$TOKEN_RESPONSE" | grep -q "access_denied"; then
                    echo -e "${RED}❌ Authentication denied. Please restart the script.${NC}"
                    exit 1
                else
                    echo -e "${YELLOW}⚠ Unexpected response, continuing to wait...${NC}"
                fi
                
                ATTEMPT=$((ATTEMPT + 1))
            done
            
            if [ -z "$GIT_TOKEN" ]; then
                echo -e "${RED}❌ Authentication timeout. Please restart the script and try again.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}❌ Failed to parse GitHub response. Falling back to username/password.${NC}"
            echo -e -n "${CYAN}GitHub Username: ${NC}"
            read GIT_USERNAME
        fi
    else
        echo -e "${RED}❌ Failed to connect to GitHub. Falling back to username/password.${NC}"
        echo -e -n "${CYAN}GitHub Username: ${NC}"
        read GIT_USERNAME
    fi
fi

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🚀 Starting Nexus repositories setup...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Create nexus directory if it doesn't exist
mkdir -p ~/nexus

# Handle Nexus Core (nexus-app)
if [ -d ~/nexus/nexus-app ]; then
    echo -e "${CYAN}🔄 Updating Nexus Core${NC}"
    echo -e "${CYAN}────────────────────${NC}"
    cd ~/nexus/nexus-app
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin master
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Core: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin master
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Core updated successfully${NC}"
else
    echo -e "${GREEN}🆕 Creating Nexus Core${NC}"
    echo -e "${GREEN}────────────────────${NC}"
    cd ~/nexus
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' clone https://github.com/sil-repo/Nexus-app.git nexus-app
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Core: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone https://github.com/sil-repo/Nexus-app.git nexus-app
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Core created successfully${NC}"
fi
echo ""

# Handle Nexus Custom
if [ -d ~/nexus/nexus-custom ]; then
    echo -e "${CYAN}🔄 Updating Nexus Custom${NC}"
    echo -e "${CYAN}──────────────────────${NC}"
    cd ~/nexus/nexus-custom
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin master
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Custom: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin master
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Custom updated successfully${NC}"
else
    echo -e "${GREEN}🆕 Creating Nexus Custom${NC}"
    echo -e "${GREEN}──────────────────────${NC}"
    cd ~/nexus
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' clone https://github.com/sil-repo/Nexus-custom.git nexus-custom
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Custom: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone https://github.com/sil-repo/Nexus-custom.git nexus-custom
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Custom created successfully${NC}"
fi
echo ""

# Handle Nexus Implementation
if [ -d ~/nexus/nexus-implementation ]; then
    echo -e "${CYAN}🔄 Updating Nexus Implementation${NC}"
    echo -e "${CYAN}──────────────────────────────${NC}"
    cd ~/nexus/nexus-implementation
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin master
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Implementation: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin master
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Implementation updated successfully${NC}"
else
    echo -e "${GREEN}🆕 Creating Nexus Implementation${NC}"
    echo -e "${GREEN}──────────────────────────────${NC}"
    cd ~/nexus
    if [ -n "$GIT_TOKEN" ]; then
        git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' clone https://github.com/sil-repo/Nexus-implementation.git nexus-implementation
    else
        echo -e -n "${YELLOW}🔐 GitHub Password for Nexus Implementation: ${NC}"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone https://github.com/sil-repo/Nexus-implementation.git nexus-implementation
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

