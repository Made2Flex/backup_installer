#!/usr/bin/env bash

set -euo pipefail
# -e: exit on error
# -u: treat unset variables as an error
# -o pipefail: ensure pipeline errors are captured

# Color definitions
GREEN='\033[1;32m'
ORANGE='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
LIGHT_BLUE='\033[1;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No color

# ASCII Art Header
ascii_art_header() {
    cat << 'EOF'
   ,---,                               ___                     ,--,      ,--,                         
,`--.' |                             ,--.'|_                 ,--.'|    ,--.'|                         
|   :  :       ,---,                 |  | :,'                |  | :    |  | :                 __  ,-. 
:   |  '   ,-+-. /  |   .--.--.      :  : ' :                :  : '    :  : '               ,' ,'/ /| 
|   :  |  ,--.'|'   |  /  /    '   .;__,'  /      ,--.--.    |  ' |    |  ' |       ,---.   '  | |' | 
'   '  ; |   |  ,"' | |  :  /`./   |  |   |      /       \   '  | |    '  | |      /     \  |  |   ,' 
|   |  | |   | /  | | |  :  ;_     :__,'| :     .--.  .-. |  |  | :    |  | :     /    /  | '  :  /   
'   :  ; |   | |  | |  \  \    `.    '  : |__    \__\/: . .  '  : |__  '  : |__  .    ' / | |  | '    
|   |  ' |   | |  |/    `----.   \   |  | '.'|   ," .--.; |  |  | '.'| |  | '.'| '   ;   /| ;  : |    
'   :  | |   | |--'    /  /`--'  /   ;  :    ;  /  /  ,.  |  ;  :    ; ;  :    ; '   |  / | |  , ;    
;   |.'  |   |/       '--'.     /    |  ,   /  ;  :   .'   \ |  ,   /  |  ,   /  |   :    |  ---'
'---'    '---'          `--'---'      ---`-'   |  ,     .-./  ---`-'    ---`-'    \   \  /
                                                `--`---'                           `----'
EOF
}

# Preflight check
Preflight_check() {
    if [[ $EUID -eq 0 ]]; then
        dynamic_color_line "Do NOT run this script as root!!"
        echo -e "${ORANGE}==>> Use sudo if elevated privileges are needed${NC}"
        exit 1
    fi
}
# Disk space check function
check_disk_space() {
    echo -e "${ORANGE}==>> Checking disk space...${NC}"
    local min_space_gb=${1:-5}  # Default 5GB minimum
    local required_space=$((min_space_gb * 1024 * 1024))  # Convert to KB
    local available_space
    
    available_space=$(df -k / | awk '/\// {print $4}')
    
    if [[ $available_space -lt $required_space ]]; then
        echo -e "${RED}!!! Insufficient disk space${NC}"
        echo -e "${ORANGE}==>> Requires at least ${min_space_gb}GB free space${NC}"
        echo -e "${WHITE}  Current free space: $((available_space / 1024 / 1024)) GB${NC}"
        return 1
    fi
    
    echo -e "${GREEN}  >> Disk space check ✓passed${NC}"
    return 0
}

# Validate package list function
validate_package_list() {
    local backup_file="$1"
    
    # Check if file exists
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}!!! Backup package list not found: $backup_file${NC}"
        return 1
    fi
    
    # Check file is not empty
    if [[ ! -s "$backup_file" ]]; then
        echo -e "${RED}!!! Backup package list is empty: $backup_file${NC}"
        return 1
    fi
    
    # Basic syntax check (no weird characters)
    if grep -qE '[;&|`()]' "$backup_file"; then
        echo -e "${RED}!!! Potential malicious content detected in package list${NC}"
        return 1
    fi
    
    # Count packages
    local package_count
    package_count=$(grep -vE '^\s*#|^\s*$' "$backup_file" | wc -l)
    
    if [[ $package_count -eq 0 ]]; then
        echo -e "${ORANGE}  >> No valid packages found in list${NC}"
        return 1
    fi
    
    echo -e "${GREEN}  >> Package list ✓validated: $package_count packages${NC}"
    return 0
}

# Utility function for dynamic color-changing a line
dynamic_color_line() {
    local message="$1"
    #local colors=("red" "yellow" "green" "cyan" "magenta" "blue")
    local colors=("\033[1;31m" "\033[1;33m" "\033[1;32m" "\033[1;36m" "\033[1;35m" "\033[1;34m")
    local NC="\033[0m"
    local delay=0.1
    local iterations=${2:-30}  # Default 30 iterations, but allow customization

    {
        for ((i=1; i<=iterations; i++)); do
            # Cycle through colors
            color=${colors[$((i % ${#colors[@]}))]}

            # Use \r to return to start of line, update with new color
            printf "\r${color}==>> ${message}${NC}"

            sleep "$delay"
        done

        # Final clear line
        #printf "\r\033[K"
        # Add a newline to move to the next line
        printf "\n"
    } >&2
}

# Localization function
get_system_language() {
    # Get the system's default language
    local lang=${LANG:-en_US.UTF-8}

    # Extract language code
    local language_code=$(echo "$lang" | cut -d'_' -f1)

    # Define translations
    case "$language_code" in
        "es")
            # Spanish translations
            GREET_MESSAGE="¡Hola, %s-sama"
            INSTALL_PROMPT="¿Quieres instalar desde la copia de seguridad? (Sí/No): "
            UPDATE_PROMPT="¿Quieres actualizar ahora? (Sí/No): "
            ;;
        "fr")
            # French translations
            GREET_MESSAGE="Bonjour, %s-sama"
            INSTALL_PROMPT="Voulez-vous installer à partir de la sauvegarde ? (Oui/Non) : "
            UPDATE_PROMPT="Voulez-vous mettre à jour maintenant ? (Oui/Non) : "
            ;;
        "de")
            # German translations
            GREET_MESSAGE="Hallo, %s-sama"
            INSTALL_PROMPT="Möchten Sie von der Sicherung installieren? (Ja/Nein): "
            UPDATE_PROMPT="Möchten Sie jetzt aktualisieren? (Ja/Nein): "
            ;;
        "ja")
            # Japanese translations
            GREET_MESSAGE="%s-sama、こんにちは"
            INSTALL_PROMPT="バックアップから復元しますか？ (はい/いいえ): "
            UPDATE_PROMPT="今すぐ更新しますか？ (はい/いいえ): "
            ;;
        *)
            # Default to English
            GREET_MESSAGE="Hello, %s-sama"
            INSTALL_PROMPT="Do you want to install from backup? (Yes/No): "
            UPDATE_PROMPT="Do you want to update Now? (Yes/No): "
            ;;
    esac
}

# Function to check if running in a terminal
check_terminal() {
    # Check if stdin is a terminal
    if [ ! -t 0 ]; then
        # Silence GTK warnings by redirecting stderr to 2>/dev/null
        local zenity_command="zenity --question --title='Terminal Required' --text='This program must be run in a terminal. Do you want to open a terminal now?' 2>/dev/null"
        
        if eval "$zenity_command"; then
            local script_path
            script_path=$(readlink -f "$0")

            # Try various terminal emulators
            local terminal_commands=(
                "xdg-terminal \"$script_path\""
                "gnome-terminal -- \"$script_path\""
                "konsole -e \"$script_path\""
                "xfce4-terminal --command=\"$script_path\""
                "mate-terminal -e \"$script_path\""
                "xterm -e \"$script_path\""
            )

            local success=false
            for cmd in "${terminal_commands[@]}"; do
                if command -v "$(echo "$cmd" | cut -d' ' -f1)" &> /dev/null; then
                    if eval "$cmd"; then
                        success=true
                        break
                    fi
                fi
            done

            if [ "$success" = false ]; then
                echo -e "${RED}No known terminal emulator found. Please open a terminal manually and run the program.${NC}" >&2
                exit 1
            fi
        else
            # User cancelled the dialog
            exit 1
        fi
        exit 1
    fi
}

# Function to detect distribution
detect_distribution() {
    # Default values
    DISTRO=""
    DISTRO_ID=""
    PACKAGE_MANAGER=""
    MIRROR_REFRESH_CMD=""

    # Check for distribution
    if [ -f /etc/os-release ]; then
        # Source the os-release file to get distribution information
        source /etc/os-release

        # Normalize ID to lowercase
        DISTRO_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')

        case "$DISTRO_ID" in
            "arch")
                DISTRO="Arch Linux"
                PACKAGE_MANAGER="pacman"
                MIRROR_REFRESH_CMD="reflector --verbose -c US --protocol https --sort rate --latest 20 --download-timeout 5 --save /etc/pacman.d/mirrorlist"
                ;;
            "manjaro")
                DISTRO="Manjaro Linux"
                PACKAGE_MANAGER="pacman"
                MIRROR_REFRESH_CMD="sudo pacman-mirrors --geoip"
                ;;
            "endeavouros")
                DISTRO="EndeavourOS"
                PACKAGE_MANAGER="pacman"
                ;;
            "debian"|"ubuntu"|"linuxmint")
                DISTRO="Debian-based"
                PACKAGE_MANAGER="apt"
                MIRROR_REFRESH_CMD="sudo nala fetch --auto --fetches 10 --country US" # change US to your actual country.
                ;;
            *)
                echo -e "${RED}!!! Unsupported distribution: $DISTRO_ID${NC}"
                sleep 1
                echo -e "${MAGENTA}==>> Please report this to the developer. Or kindly add support for your distro yourself!${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}Unable to detect distribution${NC}"
        exit 1
    fi
}

# Function to check dependencies
check_dependencies() {
    # Detect distribution first
    detect_distribution

    local missing_deps=()
    local deps=()

    # Define dependencies based on distribution
    case "$DISTRO_ID" in
        "arch")
            deps=("sudo" "pacman" "yay")
            ;;
        "manjaro")
            deps=("sudo" "pacman" "pacman-mirrors" "yay")
            ;;
        "endeavouros")
            deps=("sudo" "pacman" "eos-rankmirrors" "reflector" "yay")
            ;;
        "debian"|"ubuntu"|"linuxmint")
            deps=("sudo" "apt" "nala")
            ;;
        *)
            echo -e "${RED}!! Unsupported distribution for dependency check.${NC}"
            exit 1
            ;;
    esac

    # Check for missing dependencies
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # Function to warn user about manual installation
    warn_manual_install() {
        echo -e "${RED}!!! Unable to automatically install apt.${NC}"
        echo -e "${ORANGE}==>> Please install apt manually:${NC}"
        echo -e "  1. Download the apt package from Debian repositories"
        echo -e "  2. Use: sudo dpkg -i apt_package.deb"
        echo -e "  3. If dependencies are missing, use: sudo apt-get install -f"
        dynamic_color_line "Manual intervention required to install apt."
        sleep 1
        echo -e "${ORANGE} ==>> Now exiting.${NC}"
        exit 1
    }

    # If there are missing dependencies
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}!! The following dependencies are missing:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${WHITE}  - $dep${NC}"
        done

        # Prompt user to install
        while true; do
            read -rp "Do you want to install the missing dependencies? (Yes/No): " response
            response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

            if [[ -z "$response" || "$response" == "yes" || "$response" == "y" ]]; then
                echo -e "${ORANGE}==>> Installing missing dependencies...${NC}"
                # Distribution-specific dependency installation
                case "$DISTRO_ID" in
                    "arch"|"manjaro"|"endeavouros")
                        for dep in "${missing_deps[@]}"; do
                            if [[ "$dep" == "yay" ]]; then
                                # Handle yay installation separately
                                echo -e "${LIGHT_BLUE}  >> Attempting to install yay from repo...${NC}"
                                if sudo pacman -S --noconfirm yay 2>/dev/null; then
                                    echo -e "${GREEN}  >> ✓Successfully installed yay from repo${NC}"
                                else
                                    echo -e "${RED}!! Failed to install yay from repo.${NC}"
                                    echo -e "${LIGHT_BLUE}  >> Installing git and building from AUR...${NC}"
                                    sudo pacman -S --noconfirm base-devel git
                                    echo -e "${LIGHT_BLUE}  >> Cloning and building yay from AUR...${NC}"
                                    git clone https://aur.archlinux.org/yay.git
                                    cd yay || exit
                                    makepkg -si --noconfirm
                                    cd .. || exit
                                    echo -e "${LIGHT_BLUE}  >> Removing previously created yay source directory...${NC}"
                                    rm -rfv yay
                                fi
                            else
                                echo -e "${LIGHT_BLUE}  >> Installing $dep...${NC}"
                                sudo pacman -S --noconfirm "$dep"
                            fi
                        done
                        ;;
                    "debian"|"ubuntu"|"linuxmint")
                        # Check if apt is available
                        if command -v apt &> /dev/null; then
                            for dep in "${missing_deps[@]}"; do
                                echo -e "${LIGHT_BLUE}  >> Installing $dep...${NC}"
                                sudo apt-get install -y "$dep"
                            done
                        else
                            dynamic_color_line "APT is not installed!!."
                            warn_manual_install
                        fi
                        ;;
                esac

                echo -e "${GREEN}==>> Dependencies installed ✓successfully!${NC}"
                break
            elif [[ "$answer" == "no" || "$answer" == "n" ]]; then
                echo -e "${RED}!!! Missing dependencies. Cannot proceed.${NC}"
                dynamic_color_line "Try to install them manually, then run the script again."
                sleep 1
                echo -e "${ORANGE} ==>> Now exiting."
                exit 1
            else
                echo -e "${RED}Invalid Input. Please Enter 'yes' or 'no'.${NC}"
            fi
        done
    fi
}

# Function to print the operating system
print_os() {
    # Detect distribution first before using variable
    detect_distribution
    echo -e "Operating System detected: ${LIGHT_BLUE}$DISTRO${NC}"
}

# Function to greet user
greet_user() {
    local username
    username=$(whoami)

    # Get system language translations
    get_system_language
    print_os

    # Use the appropriate greeting
    printf "${GREEN}$GREET_MESSAGE${NC}\n" "$username"
}

# Function to show ascii art header
show_ascii_header() {
    echo -e "${BLUE}"
    ascii_art_header
    echo -e "${NC}"
    sleep 1
}

# Function to refresh mirrors of all supported distros!
refresh_mirror_source() {
    while true; do
        read -rp "Do You Want To Refresh Mirrors now? (Yes/No): " answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')                 
        if [[ "$answer" == "yes" || "$answer" == "y" || -z "$answer" ]]; then                                       
            echo -e "${ORANGE}==>> Checking mirror sources...${NC}"

            case "$DISTRO_ID" in
                "arch"|"manjaro"|"endeavouros")
                    local mirror_sources_file="/etc/pacman.d/mirrorlist"
                    if [[ -f "$mirror_sources_file" ]]; then
                        echo -e "${ORANGE}  >> Backing up current mirrorlist...${NC}"
                        sudo cp "$mirror_sources_file" "$mirror_sources_file.backup.$(date +"%Y%m%d_%H%M%S")"
                        echo -e "${BLUE}  >> Mirrorlist backed up to $mirror_sources_file.backup.$(date +"%Y%m%d_%H%M%S")${NC}"

                        echo -e "${ORANGE}==>> Refreshing Mirrors...${NC}"

                        # Handle multiple mirror refresh commands for EndeavourOS
                        if [[ "$DISTRO_ID" == "endeavouros" ]]; then
                            # Try both commands
                            if command -v eos-rankmirrors &> /dev/null; then
                                echo -e "${LIGHT_BLUE}  >> Running eos-rankmirrors...${NC}"
                                if eos-rankmirrors; then
                                    echo -e "${GREEN}  >> eos-rankmirrors completed ✓successfully${NC}"
                                else
                                    echo -e "${RED}!! eos-rankmirrors failed${NC}"
                                fi
                            fi

                            if command -v reflector &> /dev/null; then
                                echo -e "${LIGHT_BLUE}  >> Running reflector...${NC}"
                                if sudo reflector --verbose -c US --protocol https --sort rate --latest 20 --download-timeout 5 --save /etc/pacman.d/mirrorlist; then
                                    echo -e "${GREEN}  >> reflector completed ✓successfully${NC}"
                                else
                                    echo -e "${RED}!! reflector failed${NC}"
                                fi
                            fi
                        else
                            # For other distributions, use the single MIRROR_REFRESH_CMD
                            if ! $MIRROR_REFRESH_CMD; then
                                echo -e "${RED}!! Failed to refresh mirrors.${NC}"
                            fi
                        fi

                        echo -e "${GREEN}  >> Mirrors have been refreshed!${NC}"
                    else
                        echo -e "${GREEN}  >> Mirror source is fresh. moving on!${NC}"
                    fi
                    ;;
                "debian"|"ubuntu"|"linuxmint")
                    local nala_sources_file="/etc/apt/sources.list.d/nala-sources.list"
                    if [[ -f "$nala_sources_file" ]]; then
                        echo -e "${ORANGE}==>> Refreshing Nala sources...${NC}"
                        if ! sudo $MIRROR_REFRESH_CMD; then
                            echo -e "${RED}!! Failed to refresh Nala sources.${NC}"
                        fi
                        echo -e "${GREEN}==>> Nala sources have been refreshed.${NC}"
                    else
                        echo -e "${LIGHT_BLUE}==>> Sources are fresh. Moving On!${NC}"
                    fi
                    ;;
                *)
                    echo -e "${RED}!!! Unsupported distribution for mirror refresh.${NC}"
                    exit 1
                    ;;
            esac
            break
        elif [[ "$answer" == "no" || "$answer" == "n" ]]; then 
            echo -e "${ORANGE}==>> Continuing without refreshing mirrors...${NC}"
            break
        else 
            echo -e "${RED}!! Invalid Input. Please Enter 'yes', 'no', or just press Enter for 'yes'.${NC}"
        fi         
    done
}

# Dummy function to flush output
fflush() {
    # Force output buffer to flush
    >&2 echo -n ""
}

# Global variable to control spinner
spinner_running=false

# Function to create a spinner with colors
start_spinner_spinner() {
    local spinners=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local colors=("$GREEN" "$ORANGE" "$RED" "$BLUE" "$MAGENTA" "$LIGHT_BLUE")
    local delay=0.1

    # Ensure only one spinner runs at a time
    if [ "$spinner_running" = true ]; then
        echo -e "${RED}Warning: Spinner is already running.${NC}" >&2
        return 1
    fi

    spinner_running=true

    # Start spinner in background
    (
        while $spinner_running; do
            for spinner in "${spinners[@]}"; do
                for color in "${colors[@]}"; do
                    if ! $spinner_running; then
                        exit 0  # Explicitly exit the background process
                    fi
                    printf "\r${color}%s Processing...${NC}" "$spinner" >&2
                    fflush
                    sleep "$delay"
                done
            done
        done
    ) &
    spinner_pid=$!
}

# Function to stop the spinner
stop_spinner() {
    spinner_running=false

    # Wait a moment to ensure the spinner stops
    sleep 0.2

    # Kill the spinner process if it exists
    if [ -n "$spinner_pid" ]; then
        kill "$spinner_pid" 2>/dev/null
        wait "$spinner_pid" 2>/dev/null
    fi

    # Clear the line
    printf "\r%*s\r" $(tput cols) >&2

    # Reset global variables
    spinner_pid=""
}

# Global variable to store AUR packages
AUR_PACKAGES=""

# Function to check for AUR packages
check_aur_pkg() {
    aur_pkgs=$(sudo pacman -Qmq 2>&1)
    if [ $? -eq 0 ]; then
        AUR_PACKAGES="$aur_pkgs"
        echo "$AUR_PACKAGES"
    else
        echo -e "${MAGENTA}  >> No AUR packages found.${NC}"
    fi
}

# Function to update the system
update_system() {
    case "$DISTRO_ID" in
        "arch"|"manjaro"|"endeavouros")
            echo -e "${ORANGE}==>> Checking 'pacman' packages to update...${NC}"
            sudo pacman -Syyuu --noconfirm --needed --color=auto

            # Use the global AUR_PACKAGES variable to determine AUR updates
            check_aur_pkg
            if [ -n "$AUR_PACKAGES" ]; then
                echo -e "${ORANGE}==>> Inspecting yay cache...${NC}"
                # Check yay cache exists
                if [ -d "$HOME/.cache/yay" ]; then
                    # Check if yay cache is empty
                    if [ -z "$(find "$HOME/.cache/yay" -maxdepth 1 -type d | grep -v "^$HOME/.cache/yay$")" ]; then
                        echo -e "${GREEN}  >> yay cache is clean${NC}"
                    else
                        # Collect directories to be cleaned
                        mapfile -t yay_cache_dirs < <(find "$HOME/.cache/yay" -maxdepth 1 -type d | grep -v "^$HOME/.cache/yay$")
                        
                        if [ ${#yay_cache_dirs[@]} -gt 0 ]; then
                            echo -e "${ORANGE}==>> Cleaning yay cache directories: ${NC}"
                            printf "${WHITE}  - %s\n${NC}" "$(basename "${yay_cache_dirs[@]}")"
                        
                        # Remove the directories
                        for dir in "${yay_cache_dirs[@]}"; do
                                rm -rf "$dir"
                            done
                        fi
                    fi
                else
                    echo -e "${RED}!!! yay cache directory not found: $HOME/.cache/yay${NC}"
                fi
                echo -e "${ORANGE}==>> Checking 'aur' packages to update...${NC}"
                yay -Sua --norebuild --noredownload --removemake --answerclean A --noanswerdiff --noansweredit --noconfirm --cleanafter
            fi
            ;;
        "debian"|"ubuntu"|"linuxmint")
            echo -e "${ORANGE}==>> Checking for package updates.${NC}"

            # Start spinner in background
            start_spinner_spinner

            # Capture command output and exit status
            local update_output
            local exit_status
            update_output=$(sudo nala update)
            exit_status=$?

            # Stop spinner
            stop_spinner

            # Check command result
            if [ $exit_status -eq 0 ] && echo "$update_output" | grep -q 'packages can be upgraded'; then
                echo -e "${LIGHT_BLUE}==>> Updates have been found!${NC}"
                echo -e "${ORANGE}==>> Now Witness MEOW POWA!!!!!${NC}"
                sudo nala upgrade --assume-yes --no-install-recommends --no-install-suggests --no-update --full
                echo -e "${GREEN}==>> System has been updated!${NC}"
            elif [ $exit_status -ne 0 ]; then
                echo -e "${RED}!!! Update check failed. See output below:${NC}"
                echo "$update_output"
            else
                echo -e "${ORANGE}==>> No packages to update.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}!!! Unsupported distribution for system update.${NC}"
            exit 1
            ;;
    esac
}

# Function to prompt user to update the system
prompt_update() {
    while true; do
        # Use localized prompt
        get_system_language
        read -rp "$UPDATE_PROMPT" answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

        if [[ -z "$answer" || "$answer" == "yes" || "$answer" == "y" || "$answer" == "" ]]; then
            update_system
            break
        elif [[ "$answer" == "no" || "$answer" == "n" ]]; then
            dynamic_color_line "You have chosen not to update!"
            echo -e "${MAGENTA}==>> This could have catastrophic consequences. You have been WARNED!${NC}" 
            sleep 3
            echo -e "${ORANGE}  >> Continuing...${NC}"
            break
        else
            echo -e "${RED}Invalid Input. Please Enter 'yes' or 'no'.${NC}"
        fi
    done
}

# Function to install packages from backup
install_from_backup() {
    # Disk space and package list validation
    check_disk_space 10 || {
        echo -e "${RED}!!! Installation aborted due to insufficient disk space${NC}"
        return 1
    }
    
    local backup_file=""
    local log_file=""
    local aur_backup_file=""

    # Determine backup file and log file based on distribution
    case "$DISTRO_ID" in
        "arch"|"manjaro"|"endeavouros")
            backup_file="$HOME/bk/arch-pkglst.txt"
            log_file="$HOME/bk/install-error.log"
            aur_backup_file="$HOME/bk/aur-pkglist.txt"
            ;;
        "debian"|"ubuntu"|"linuxmint")
            backup_file="$HOME/bk/debian-pkglist.txt"
            log_file="$HOME/bk/install-error.log"
            ;;
        *)
            echo -e "${RED}!!! Unsupported distribution for package installation.${NC}"
            return 1
            ;;
    esac

    # Validate package lists before installation
    if ! validate_package_list "$backup_file"; then
        echo -e "${RED}!!! Invalid package list. Aborting installation.${NC}"
        return 1
    fi
    
    if [[ "$DISTRO_ID" == "arch" || "$DISTRO_ID" == "manjaro" || "$DISTRO_ID" == "endeavouros" ]] && 
       command -v yay &> /dev/null && 
       [ -f "$aur_backup_file" ]; then
        if ! validate_package_list "$aur_backup_file"; then
            echo -e "${RED}!!! Invalid AUR package list. Skipping AUR packages.${NC}"
            aur_backup_file=""
        fi
    fi

    # Prompt user for confirmation
    get_system_language
    while true; do
        read -rp "$INSTALL_PROMPT" answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

        if [[ -z "$answer" || "$answer" == "yes" || "$answer" == "y" ]]; then
            echo -e "${ORANGE}==>> Starting package installation from backup...${NC}"
            
            # Distribution-specific package installation
            case "$DISTRO_ID" in
                "arch"|"manjaro"|"endeavouros")
                    # Capture output and log errors
                    if sudo pacman -S --noconfirm --needed - < "$backup_file" 2>"$log_file"; then
                        echo -e "${GREEN}==>> Packages installed ✓successfully!${NC}"
                        sleep 1
                    if command -v yay &> /dev/null && [ -f "$aur_backup_file" ]; then
                        echo -e "${ORANGE}==>> Starting package installation from AUR...${NC}"
                        sudo yay -S --noconfirm --needed - < "$aur_backup_file" 2>>"$log_file"
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}==>> AUR packages installed ✓successfully!${NC}"
                        else
                            echo -e "${RED}!!! AUR package installation failed. See $log_file for details.${NC}"
                        fi
                    fi
                        
                        # Enable system services
                        echo -e "${ORANGE}==>> Enabling system services...${NC}"
                        sudo systemctl enable NetworkManager
                        sudo systemctl enable bluetooth
                        sudo systemctl set-default graphical.target
                        
                        # Detect and enable display manager
                        local display_managers=("gdm" "lightdm" "sddm" "lxdm")
                        local enabled_dm=""
                        
                        for dm in "${display_managers[@]}"; do
                            if command -v "$dm" &> /dev/null; then
                                sudo systemctl enable "$dm"
                                enabled_dm="$dm"
                                break
                            fi
                        done
                        
                        if [ -n "$enabled_dm" ]; then
                            echo -e "${GREEN}  >> Enabled display manager: $enabled_dm${NC}"
                        else
                            echo -e "${YELLOW}  >> No display manager found to enable${NC}"
                        fi
                        
                        # Change shell to zsh if available
                        if command -v zsh &> /dev/null; then
                            echo -e "${ORANGE}==>> Changing shell to zsh...${NC}"
                            sudo chsh -s "$(command -v zsh)" "$USER"
                            echo -e "${GREEN}  >> Shell changed to zsh${NC}"
                        fi
                        
                        # Prompt for reboot
                        read -rp "Do you want to reboot now? (Yes/No): " reboot_choice
                        reboot_choice=$(echo "$reboot_choice" | tr '[:upper:]' '[:lower:]')
                        
                        if [[ "$reboot_choice" == "yes" || "$reboot_choice" == "y" ]]; then
                            echo -e "${ORANGE}==>> Rebooting system...${NC}"
                            sudo systemctl reboot
                        else
                            echo -e "${GREEN}==>> Installation complete. Reboot recommended.${NC}"
                        fi
                    else
                        echo -e "${RED}!!! Package installation failed. See $log_file for details.${NC}"
                        return 1
                    fi
                    ;;
                "debian"|"ubuntu"|"linuxmint")
                    # Capture output and log errors
                    if sudo nala install -y < "$backup_file" 2>"$log_file"; then
                        echo -e "${GREEN}==>> Packages installed ✓successfully!${NC}"
                        
                        # Prompt for reboot
                        read -rp "Do you want to reboot now? (Yes/No): " reboot_choice
                        reboot_choice=$(echo "$reboot_choice" | tr '[:upper:]' '[:lower:]')
                        
                        if [[ "$reboot_choice" == "yes" || "$reboot_choice" == "y" ]]; then
                            echo -e "${ORANGE}==>> Rebooting system...${NC}"
                            sudo systemctl reboot
                        else
                            echo -e "${GREEN}==>> Installation complete. Reboot recommended.${NC}"
                        fi
                    else
                        echo -e "${RED}!!! Package installation failed. See $log_file for details.${NC}"
                        return 1
                    fi
                    ;;
            esac
            break
        elif [[ "$answer" == "no" || "$answer" == "n" ]]; then
            echo -e "${ORANGE}  >> Installation cancelled.${NC}"
            echo -e "${ORANGE}==>> Exiting..${NC}" 
            break
        else
            echo -e "${RED}Invalid Input. Please Enter 'yes' or 'no'.${NC}"
        fi
    done
}

# Orchestrate
main() { 
    check_terminal
    show_ascii_header
    greet_user
    Preflight_check
    check_dependencies
    refresh_mirror_source
    prompt_update
    install_from_backup
}

# Let it reap
main
