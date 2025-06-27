#!/bin/bash
clear

# Load the Git token
# If token cannot be found create a a PAT token (This is best approach)
#    - Create the file: `echo "PATCodeInHere" > /git_token`
#    - Secure the file: `chmod 600 /git_token`.
#    - Test PAT token -- curl -u git:$(cat /tmp/git_token) https://api.github.com/repos/sil-repo/Nexus
if [ -f /git_token ]; then
    export GIT_TOKEN=$(cat /git_token)
    echo "Using GitHub token from /git_token"
else
    echo "No /git_token file found. Please provide GitHub credentials."
    read -p "GitHub Username: " GIT_USERNAME
fi

echo "Updating Nexus Core"
echo "-------------------"
mkdir -p ~/nexus/nexus-app
cd ~/nexus/nexus-app || { echo "Failed to enter ~/nexus/nexus-app"; exit 1; }
if [ -n "$GIT_TOKEN" ]; then
    git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin master
else
    read -s -p "GitHub Password for Nexus Core: " GIT_PASSWORD
    echo ""
    git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin master
    unset GIT_PASSWORD
fi
echo ""

echo "Updating Nexus Custom"
echo "---------------------"
mkdir -p ~/nexus/nexus-custom
cd ~/nexus/nexus-custom || { echo "Failed to enter ~/nexus/nexus-custom"; exit 1; }
if [ -n "$GIT_TOKEN" ]; then
    git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin master
else
    read -s -p "GitHub Password for Nexus Custom: " GIT_PASSWORD
    echo ""
    git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin master
    unset GIT_PASSWORD
fi
echo ""

echo "Updating Nexus Implementation"
echo "---------------------"
mkdir -p ~/nexus/nexus-implementation
cd ~/nexus/nexus-implementation || { echo "Failed to enter ~/nexus/nexus-implementation"; exit 1; }
if [ -n "$GIT_TOKEN" ]; then
    git -c credential.helper= -c credential.helper='!f() { echo "username=git"; echo "password=$GIT_TOKEN"; } ; f' pull origin master
else
    read -s -p "GitHub Password for Nexus Implementation: " GIT_PASSWORD
    echo ""
    git -c credential.helper= -c credential.helper='!f() { echo "username=$GIT_USERNAME"; echo "password=$GIT_PASSWORD"; } ; f' pull origin master
    unset GIT_PASSWORD
fi
echo ""

echo "Update complete. Attempting to restart the Nexus container..."
echo "-------------------------------------------------------------"
docker restart nexus
echo ""
docker ps | grep "nexus"
echo ""
docker logs nexus --tail 20
echo ""
echo "** Check uptime of container. If it has not reset, restart the container again**"
echo ""
