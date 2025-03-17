# Backup Installer Script

## Overview

The `backup_installer.sh` script is designed to facilitate the installation of packages from a backup file on various Linux distributions. It supports both Arch-based and Debian-based systems, providing a user-friendly interface and multilingual support.

## Features

- **Multi-Distribution Support**: Works with Arch Linux, Manjaro, EndeavourOS, Debian, Ubuntu, and Linux Mint.
- **Multilingual Support**: Automatically detects system language and provides prompts in the user's preferred language.
- **Dependency Checking**: Checks for and installs missing dependencies before proceeding with the installation.
- **Package Installation from Backup**: Installs packages from a specified backup file and logs any errors encountered during the process.
- **Mirror Source Refreshing**: Offers the option to refresh package mirrors for better installation performance.

## Prerequisites

- Bash
- `sudo` privileges
- Distribution-specific package managers:
  - Arch: `pacman`, optional `yay`
  - Debian: `apt`, `nala`

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Made2Flex/backup_installer.git
   ```
2. Make the script executable:
   ```bash
   chmod +x -v backup_installer.sh
   ```

## Usage

Run the script with:
```bash
./backup_installer.sh
```

## Acknowledgments

This script is designed to work in conjunction with [Mr. Updater GitHub repository](https://github.com/Made2Flex/Mr._Updater.git). For more details, please refer to the repository.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
