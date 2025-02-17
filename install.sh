#!/bin/bash

# Color definitions
GREEN='\e[0;32m'
BLUE='\e[0;34m'
YELLOW='\e[1;33m'
RED='\e[0;31m'
NC='\e[0m' # No Color

INSTALLERS_DIR="./installers"

# Display a progress bar with current progress
display_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "${BLUE}Installing themes ${YELLOW}[${NC}"
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "${YELLOW}]${NC} ${GREEN}%3d%%${NC} (${BLUE}%d${NC}/${BLUE}%d${NC})\r" $percentage $current $total
}

# Arrays to track installation status
successful_installs=()
existing_themes=()
failed_installs=()

# Get theme display name from installer script
get_theme_display_name() {
    local script_path="$1"
    local display_name
    display_name=$(grep "^readonly THEME_NAME=" "$script_path" | cut -d'"' -f2)
    if [ -z "$display_name" ]; then
        # Fallback to file name if THEME_NAME is not found
        display_name=$(basename "$script_path" .sh)
    fi
    echo "$display_name"
}

# List available themes and return them as an array
get_themes() {
    find "$INSTALLERS_DIR" -type f -name "*.sh" | sort | while read -r theme; do
        basename "$theme" .sh
    done
}

# Check if a theme is already installed
theme_exists() {
    local theme_name=$1
    bash "$INSTALLERS_DIR/${theme_name}.sh" check >/dev/null 2>&1
    return $?
}

# Display menu of available themes
display_menu() {
    local themes=("$@")
    echo -e "\n${BLUE}Available themes:${NC}"
    for i in "${!themes[@]}"; do
        local display_name=$(get_theme_display_name "${INSTALLERS_DIR}/${themes[$i]}.sh")
        echo -e "  ${GREEN}$((i+1))${NC}) ${YELLOW}$display_name${NC}"
    done
    echo
    echo -e "  ${GREEN}$((${#themes[@]}+1))${NC}) Install All"
    echo -e "  ${RED}$((${#themes[@]}+2))${NC}) Exit"
    echo
}

# Handle theme installation
install_theme() {
    local theme_name=$1
    local display_name=$(get_theme_display_name "$INSTALLERS_DIR/${theme_name}.sh")

    if theme_exists "$theme_name"; then
        echo -e "${YELLOW}Theme${NC} ${BLUE}$display_name${NC} ${YELLOW}is already installed!${NC}"
        existing_themes+=("$display_name")
        return 2
    fi

    bash "$INSTALLERS_DIR/${theme_name}.sh" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        successful_installs+=("$display_name")
        return 0
    else
        failed_installs+=("$display_name")
        return 3
    fi
}

# Main installation logic
main() {
    mapfile -t themes < <(get_themes)
    if [ ${#themes[@]} -eq 0 ]; then
        echo -e "${RED}No themes found in $INSTALLERS_DIR${NC}"
        exit 1
    fi

    # Check for already installed themes before starting
    echo -e "${BLUE}Checking for installed themes...${NC}"
    for theme in "${themes[@]}"; do
        if theme_exists "$theme"; then
            display_name=$(get_theme_display_name "$INSTALLERS_DIR/${theme}.sh")
            existing_themes+=("$display_name")
        fi
    done
    echo

    while true; do
        display_menu "${themes[@]}"
        read -rp "Select theme to install (1-$((${#themes[@]}+2))): " choice

        # Validate input
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((${#themes[@]}+2)) ]; then
            echo -e "${RED}Invalid selection. Please try again.${NC}"
            continue
        fi

        # Handle exit
        if [ "$choice" -eq $((${#themes[@]}+2)) ]; then
            break
        fi

        # Handle install all
        if [ "$choice" -eq $((${#themes[@]}+1)) ]; then
            local total_themes=${#themes[@]}
            local current=0
            for theme in "${themes[@]}"; do
                ((current++))
                display_progress_bar $current $total_themes
                install_theme "$theme"
            done
            echo
            break
        fi

        # Install selected theme
        display_progress_bar 0 1
        install_theme "${themes[$((choice-1))]}"
        display_progress_bar 1 1
        echo
    done

    # Show summary of installations
    echo
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║             ${YELLOW}INSTALL REPORT${BLUE}             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
    if [ ${#successful_installs[@]} -gt 0 ]; then
        echo -e "${GREEN}Successfully installed themes:${NC}"
        for theme in "${successful_installs[@]}"; do
            echo -e "  ${GREEN}✓${NC} ${BLUE}$theme${NC}"
            echo
            echo -e  "Restart Warp and select a theme from the Theme Picker"
            echo -e  "Don't know how to open the Theme Picker? ${GREEN_BOLD}https://docs.warp.dev/features/themes#how-to-access-it${NC}"
        done
        echo
    fi
    if [ ${#existing_themes[@]} -gt 0 ]; then
        echo -e "${YELLOW}Already installed themes:${NC}"
        for theme in "${existing_themes[@]}"; do
            echo -e "  ${YELLOW}•${NC} ${BLUE}$theme${NC}"
        done
        echo
    fi
    if [ ${#failed_installs[@]} -gt 0 ]; then
        echo -e "${RED}Failed installations:${NC}"
        for theme in "${failed_installs[@]}"; do
            echo -e "  ${RED}✗${NC} ${BLUE}$theme${NC}"
        done
        echo
    fi
}

main
