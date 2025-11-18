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
echo -e "${PURPLE}║              ${WHITE}NEXUS PRODUCTION UPDATE v1.0.0 SCRIPT${PURPLE}         ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Initialize tracking variables for Teams notification
UPDATE_START_TIME=$(date +%s)
UPDATE_DATE=$(date "+%d/%m/%Y %H:%M")
GIT_AUTH_STATUS="⏳ In Progress"
BRACH_SET=""
COMPOSE_FILE_SET=""
REPO_PULL_STATUS=()
PACKAGE_LOCK_CONFLICT=false
ALL_REPOS_PULLED=false
CONTAINERS_RUNNING=false
CONTAINER_ERROR_LOGS=""
UPDATE_OVERALL_STATUS="⏳ In Progress"
TEAMS_MESSAGE_ID=""
TEAMS_CONVERSATION_ID=""

# Teams notification functions
send_teams_initial_message() {
    if [ ! -f /teams_webhook ]; then
        return
    fi
    
    TEAMS_WEBHOOK_URL=$(cat /teams_webhook)
    if [ -z "$TEAMS_WEBHOOK_URL" ]; then
        return
    fi
    
    local message=$(cat <<EOF
{
    "type": "message",
    "attachments": [{
        "contentType": "application/vnd.microsoft.card.adaptive",
        "content": {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [{
                "type": "Container",
                "items": [{
                    "type": "ColumnSet",
                    "columns": [{
                        "type": "Column",
                        "width": "auto",
                        "items": [{
                            "type": "Image",
                            "url": "https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Rocket/3D/rocket_3d.png",
                            "size": "Medium",
                            "width": "48px"
                        }]
                    }, {
                        "type": "Column",
                        "width": "stretch",
                        "items": [{
                            "type": "TextBlock",
                            "text": "Nexus Update Starting: ${SERVER_NAME}",
                            "weight": "Bolder",
                            "size": "Large",
                            "wrap": true
                        }, {
                            "type": "TextBlock",
                            "text": "⏳ Update in progress • ${UPDATE_DATE}",
                            "spacing": "None",
                            "isSubtle": true,
                            "wrap": true
                        }]
                    }]
                }],
                "style": "emphasis",
                "bleed": true
            }, {
                "type": "TextBlock",
                "text": "Initializing production update...",
                "wrap": true,
                "spacing": "Medium"
            }]
        }
    }]
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -d "$message" "$TEAMS_WEBHOOK_URL")
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Teams initial notification sent${NC}"
    fi
}

send_teams_update() {
    if [ ! -f /teams_webhook ]; then
        return
    fi
    
    TEAMS_WEBHOOK_URL=$(cat /teams_webhook)
    if [ -z "$TEAMS_WEBHOOK_URL" ]; then
        return
    fi
    
    local step_name="$1"
    local step_status="$2"
    local current_time=$(date "+%d/%m/%Y %H:%M:%S")
    
    local message=$(cat <<EOF
{
    "type": "message",
    "attachments": [{
        "contentType": "application/vnd.microsoft.card.adaptive",
        "content": {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [{
                "type": "TextBlock",
                "text": "**${step_name}:** ${step_status}",
                "wrap": true,
                "size": "Small"
            }, {
                "type": "TextBlock",
                "text": "${current_time}",
                "spacing": "None",
                "isSubtle": true,
                "size": "Small"
            }]
        }
    }]
}
EOF
)
    
    curl -s -H "Content-Type: application/json" -d "$message" "$TEAMS_WEBHOOK_URL" > /dev/null 2>&1
}

# Load the Git token
# If token cannot be found, we'll use GitHub Device Flow for authorisation
#    - This will provide a browser link for secure authorisation
#    - Alternative: Create a PAT token file: `echo "PATCodeInHere" > /git_token`
#    - Secure the file: `chmod 600 /git_token`.
if [ -f /git_token ]; then
    export GIT_TOKEN=$(cat /git_token)
    echo -e "${GREEN}✓ Using GitHub token from /git_token${NC}"
    GIT_AUTH_STATUS="✅ Successful"
    send_teams_update "Git Authentication" "✅ Successful"
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
                        GIT_AUTH_STATUS="✅ Successful"
                        send_teams_update "Git Authentication" "✅ Successful"
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
echo -e "${WHITE}🚀 Starting Nexus Production Update (master branch)...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Send initial Teams notification
send_teams_initial_message

# Set production branch and docker-compose file
BRANCH="master"
DOCKER_COMPOSE_FILE="docker-compose-prod.yaml"
BRANCH_SET="master"
COMPOSE_FILE_SET="docker-compose-prod.yaml"
echo -e "${GREEN}✓ Using Live Branch (master) with ${DOCKER_COMPOSE_FILE}${NC}"
send_teams_update "Configuration" "✅ Branch: master | Compose: docker-compose-prod.yaml"
echo ""

# Create nexus directory if it doesn't exist
mkdir -p ~/nexus

# Handle repository updates
handle_repository() {
    local repo_name=$1
    local repo_path=$2
    local repo_url=$3
    local branch=$4
    local pull_success=false
    local had_package_conflict=false

    if [ -d "$repo_path" ]; then
        echo -e "${CYAN}🔄 Updating ${repo_name} (${branch} branch)${NC}"
        echo -e "${CYAN}$(printf '%0.s─' {1..${#repo_name}})${NC}"
        cd "$repo_path"
        
        # Function to perform the git pull
        do_git_pull() {
            if [ -n "$GIT_TOKEN" ]; then
                git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin "$branch"
            else
                echo -e -n "${YELLOW}🔐 GitHub Password for ${repo_name}: ${NC}"
                read -s GIT_PASSWORD
                echo ""
                git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin "$branch"
                unset GIT_PASSWORD
            fi
        }

        if ! do_git_pull; then
            echo -e "${RED}❌ Pull failed. Checking for package-lock.json conflicts...${NC}"
            if git status --porcelain | grep -E "package(-lock)?.json"; then
                echo -e "${YELLOW}Attempting to resolve conflicts by checking out package.json and package-lock.json...${NC}"
                git checkout -- package.json package-lock.json
                had_package_conflict=true
                PACKAGE_LOCK_CONFLICT=true
                echo -e "${CYAN}Retrying pull...${NC}"
                if do_git_pull; then
                    echo -e "${GREEN}✓ ${repo_name} updated successfully after resolving conflicts.${NC}"
                    pull_success=true
                else
                    echo -e "${RED}❌ Failed to update ${repo_name} even after attempting to resolve conflicts.${NC}"
                fi
            else
                echo -e "${RED}❌ Pull failed for a reason other than package-lock.json conflicts.${NC}"
            fi
        else
            echo -e "${GREEN}✓ ${repo_name} updated successfully${NC}"
            pull_success=true
        fi
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
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ ${repo_name} created successfully${NC}"
            pull_success=true
        fi
    fi
    
    # Track repository pull status
    if [ "$pull_success" = true ]; then
        if [ "$had_package_conflict" = true ]; then
            REPO_PULL_STATUS+=("✅ ${repo_name} (package.json conflict resolved)")
            send_teams_update "Repository: ${repo_name}" "✅ Updated (conflict resolved)"
        else
            REPO_PULL_STATUS+=("✅ ${repo_name}")
            send_teams_update "Repository: ${repo_name}" "✅ Updated successfully"
        fi
    else
        REPO_PULL_STATUS+=("❌ ${repo_name}")
        send_teams_update "Repository: ${repo_name}" "❌ Failed to update"
    fi
    
    echo ""
}

handle_repository "Nexus Core" ~/nexus/nexus-app https://github.com/sil-repo/Nexus.git "$BRANCH"
handle_repository "Nexus Custom" ~/nexus/nexus-custom https://github.com/sil-repo/Nexus-PAS.git "$BRANCH"
handle_repository "Nexus Implementation" ~/nexus/nexus-implementation https://github.com/sil-repo/Nexus-implementation.git "$BRANCH"

# Check if all repos pulled successfully
ALL_REPOS_SUCCESS=true
for status in "${REPO_PULL_STATUS[@]}"; do
    if [[ $status == ❌* ]]; then
        ALL_REPOS_SUCCESS=false
        break
    fi
done
if [ "$ALL_REPOS_SUCCESS" = true ]; then
    ALL_REPOS_PULLED=true
fi

echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🔧 Update complete. Deploying using ${DOCKER_COMPOSE_FILE}...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

cd ~/nexus

docker compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans

if [ $? -eq 0 ]; then
    CONTAINERS_RUNNING=true
    send_teams_update "Docker Deployment" "✅ Containers deployed successfully"
else
    send_teams_update "Docker Deployment" "❌ Failed to deploy containers"
fi

echo ""
echo -e "${GREEN}✅ Production update completed using ${DOCKER_COMPOSE_FILE}${NC}"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}📊 Running Docker Containers${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}📜 Checking for errors in nexus container logs...${NC}"
CONTAINER_ERRORS=$(docker compose -f "$DOCKER_COMPOSE_FILE" logs nexus 2>&1 | grep -i "error" | head -20)
if [ -n "$CONTAINER_ERRORS" ]; then
    echo -e "${RED}❌ Errors found in nexus container logs:${NC}"
    echo "$CONTAINER_ERRORS" | grep -i "error" --color=always
    CONTAINER_ERROR_LOGS="$CONTAINER_ERRORS"
    send_teams_update "Container Logs" "⚠️ Errors detected in logs"
else
    echo -e "${GREEN}✓ No errors found in nexus container logs.${NC}"
    send_teams_update "Container Logs" "✅ No errors detected"
fi
echo ""

# Determine overall update status
if [ "$ALL_REPOS_PULLED" = true ] && [ "$CONTAINERS_RUNNING" = true ]; then
    UPDATE_OVERALL_STATUS="✅ Successful"
fi

# Send Teams notification
send_teams_notification() {
    if [ ! -f /teams_webhook ]; then
        echo -e "${YELLOW}⚠ No Teams webhook configured (/teams_webhook not found). Skipping notification.${NC}"
        return
    fi
    
    TEAMS_WEBHOOK_URL=$(cat /teams_webhook)
    
    if [ -z "$TEAMS_WEBHOOK_URL" ]; then
        echo -e "${YELLOW}⚠ Teams webhook URL is empty. Skipping notification.${NC}"
        return
    fi
    
    UPDATE_END_TIME=$(date +%s)
    UPDATE_DURATION=$((UPDATE_END_TIME - UPDATE_START_TIME))
    UPDATE_DURATION_MIN=$((UPDATE_DURATION / 60))
    UPDATE_DURATION_SEC=$((UPDATE_DURATION % 60))
    
    # Determine status color and message
    if [ "$UPDATE_OVERALL_STATUS" == "✅ Successful" ]; then
        STATUS_COLOR="Good"
        STATUS_MESSAGE="✅ Update Completed Successfully"
    elif [ "$UPDATE_OVERALL_STATUS" == "⚠️ Partial Success" ]; then
        STATUS_COLOR="Warning"
        STATUS_MESSAGE="⚠️ Update Completed with Warnings"
    else
        STATUS_COLOR="Attention"
        STATUS_MESSAGE="❌ Update Failed"
    fi
    
    # Build container error logs section if exists
    CONTAINER_LOGS_SECTION=""
    if [ -n "$CONTAINER_ERROR_LOGS" ]; then
        ESCAPED_LOGS=$(echo "$CONTAINER_ERROR_LOGS" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        CONTAINER_LOGS_SECTION=",{\"type\":\"Container\",\"items\":[{\"type\":\"TextBlock\",\"text\":\"⚠️ **Container Error Logs**\",\"wrap\":true,\"weight\":\"Bolder\",\"color\":\"Warning\"},{\"type\":\"TextBlock\",\"text\":\"${ESCAPED_LOGS}\",\"wrap\":true,\"fontType\":\"Monospace\",\"size\":\"Small\",\"color\":\"Warning\"}],\"style\":\"attention\",\"bleed\":true}"
    fi
    
    # Build the final summary message
    TEAMS_MESSAGE=$(cat <<EOF
{
    "type": "message",
    "attachments": [{
        "contentType": "application/vnd.microsoft.card.adaptive",
        "content": {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [{
                "type": "Container",
                "items": [{
                    "type": "ColumnSet",
                    "columns": [{
                        "type": "Column",
                        "width": "auto",
                        "items": [{
                            "type": "Image",
                            "url": "https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Check%20Mark%20Button/3D/check_mark_button_3d.png",
                            "size": "Medium",
                            "width": "48px"
                        }]
                    }, {
                        "type": "Column",
                        "width": "stretch",
                        "items": [{
                            "type": "TextBlock",
                            "text": "Nexus Update Complete: ${SERVER_NAME}",
                            "weight": "Bolder",
                            "size": "Large",
                            "wrap": true
                        }, {
                            "type": "TextBlock",
                            "text": "${STATUS_MESSAGE} • Completed in ${UPDATE_DURATION_MIN}m ${UPDATE_DURATION_SEC}s",
                            "spacing": "None",
                            "isSubtle": true,
                            "wrap": true
                        }]
                    }]
                }],
                "style": "${STATUS_COLOR}",
                "bleed": true
            }, {
                "type": "Container",
                "items": [{
                    "type": "TextBlock",
                    "text": "📊 **Final Summary**",
                    "weight": "Bolder",
                    "size": "Medium"
                }, {
                    "type": "FactSet",
                    "facts": [{
                        "title": "Server:",
                        "value": "${SERVER_NAME}"
                    }, {
                        "title": "Branch:",
                        "value": "${BRANCH_SET}"
                    }, {
                        "title": "Compose File:",
                        "value": "${COMPOSE_FILE_SET}"
                    }, {
                        "title": "Duration:",
                        "value": "${UPDATE_DURATION_MIN}m ${UPDATE_DURATION_SEC}s"
                    }, {
                        "title": "Completed:",
                        "value": "$(date '+%d/%m/%Y %H:%M')"
                    }]
                }]
            }${CONTAINER_LOGS_SECTION}],
            "actions": [{
                "type": "Action.OpenUrl",
                "title": "View Server",
                "url": "https://${SERVER_NAME}"
            }]
        }
    }]
}
EOF
)
    
    echo -e "${BLUE}📨 Sending Teams completion notification...${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -d "$TEAMS_MESSAGE" "$TEAMS_WEBHOOK_URL")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Teams notification sent successfully${NC}"
    else
        echo -e "${RED}❌ Failed to send Teams notification (HTTP $HTTP_CODE)${NC}"
    fi
}

send_teams_notification
echo ""
