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
# If token cannot be found create a a PAT token (This is best approach)
#    - Create the file: `echo "PATCodeInHere" > /git_token`
#    - Secure the file: `chmod 600 /git_token`.
#    - Test PAT token -- curl -u git:$(cat /tmp/git_token) https://api.github.com/repos/sil-repo/Nexus
if [ -f /git_token ]; then
    export GIT_TOKEN=$(cat /git_token)
    echo -e "${GREEN}✓ Using GitHub token from /git_token${NC}"
else
    echo -e "${YELLOW}⚠ No /git_token file found. Please provide GitHub credentials.${NC}"
    echo -e "${CYAN}GitHub Username: ${NC}\c"
    read GIT_USERNAME
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
        echo -e "${YELLOW}🔐 GitHub Password for Nexus Core: ${NC}\c"
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
        echo -e "${YELLOW}🔐 GitHub Password for Nexus Core: ${NC}\c"
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
        echo -e "${YELLOW}🔐 GitHub Password for Nexus Custom: ${NC}\c"
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
        echo -e "${YELLOW}🔐 GitHub Password for Nexus Custom: ${NC}\c"
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
        echo -e "${YELLOW}🔐 GitHub Password for Nexus Implementation: ${NC}\c"
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
        echo -e "${YELLOW}🔐 GitHub Password for Nexus Implementation: ${NC}\c"
        read -s GIT_PASSWORD
        echo ""
        git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' clone https://github.com/sil-repo/Nexus-implementation.git nexus-implementation
        unset GIT_PASSWORD
    fi
    echo -e "${GREEN}✓ Nexus Implementation created successfully${NC}"
fi
echo ""

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🔧 Repository setup complete! Starting Docker operations...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${PURPLE}🐳 Attempting to restart the Nexus container...${NC}"
echo -e "${PURPLE}────────────────────────────────────────────────${NC}"
docker restart nexus
echo ""

echo -e "${CYAN}📊 Container Status:${NC}"
docker ps | grep "nexus"
echo ""

echo -e "${YELLOW}📋 Recent Container Logs:${NC}"
docker logs nexus --tail 20
echo ""

echo -e "${RED}⚠️  ${WHITE}IMPORTANT: Check container uptime above. If it hasn't reset, restart the container again manually!${NC}"
echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    ${WHITE}NEXUS SETUP COMPLETED${PURPLE}                         ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
