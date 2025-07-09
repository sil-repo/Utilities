# Source Utilities


# Nexus Install
An automated script for installing and updating Nexus repositories with branch selection support for internal use.

## Quick Start

### Direct Download & Run
```bash
curl -sL https://raw.githubusercontent.com/sil-repo/Utilities/master/nexus-install.sh | bash
```

The script will:
- Authenticate with GitHub (using Device Flow or existing token)
- Prompt you to select a branch (Live/Test or Custom)
- Install/update all Nexus repositories
- Restart the Nexus container

## Branch Options

- **Live Branch (master)** - Stable production version
- **Test Branch (test)** - Development/testing version
- **Custom/Advanced** - Allows you to select custom branches for each repo