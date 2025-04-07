#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# GitHub repository details
REPO_USER="SilentGlasses"
REPO_NAME="warp_themes"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/yaml_files"
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/yaml_files"

# Determine OS using uname
OS_TYPE=$(uname -s)

# Determine OS and set theme directory accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS_NAME="macOS"
  WARP_THEMES_DIR="$HOME/.warp/themes"  # macOS
else
  OS_NAME="Linux"
  WARP_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"  # Linux
fi

# Ensure the installation directory exists
mkdir -p "$WARP_THEMES_DIR"

# Display detected OS
clear
echo -e "${BOLD}${BLUE}Detected OS:${NC} $OS_NAME"
echo -e "${BOLD}${BLUE}Fetching available themes...${NC}"

# Fetch the list of theme files from GitHub
theme_files=$(curl -s "$API_URL" | sed -n 's/.*"name": "\([^"]*\.yaml\)".*/\1/p' | sed 's/\.yaml$//')

if [[ -z "$theme_files" ]]; then
  echo -e "${RED}Failed to retrieve theme list. Please check your internet connection or GitHub API limits.${NC}"
  exit 1
fi

# Fetch theme names from their YAML content
declare -A themes
declare -A file_map
index=1

for file in $theme_files; do
  yaml_url="$RAW_BASE/$file.yaml"
  theme_name=$(curl -s "$yaml_url" | grep "^name:" | sed 's/^name: *//')

  if [[ -z "$theme_name" ]]; then
    theme_name="$file"  # Fallback to filename if name field is missing
  fi

  themes["$index"]="$theme_name"
  file_map["$index"]="$file.yaml"
  ((index++))
done

# Pretty display of theme menu (with corrected order)
echo -e "\n${BOLD}${BLUE}Available Warp Themes:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"

for i in $(seq 1 ${#themes[@]}); do
  echo -e "${YELLOW}[${i}]${NC} ${themes[$i]}"
done

echo -e "${YELLOW}[A]${NC} Install all themes"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

# Prompt the user for selection
echo ""
read -p "Select themes to install (e.g., 1 3 5 or A for all): " -r selection

# Function to download and install a theme
install_theme() {
  local theme_name=$1
  local theme_file=$2
  local url="$RAW_BASE/$theme_file"
  local destination="$WARP_THEMES_DIR/$theme_file"

  if [[ -f "$destination" ]]; then
    existing_themes+=("$theme_name")
    return 2
  fi

  echo -e "${BLUE}Installing $theme_name...${NC}"

  if curl -sSfL "$url" -o "$destination"; then
    installed_themes+=("$theme_name")
    return 0
  else
    failed_themes+=("$theme_name")
    return 1
  fi
}

# Arrays to track installation outcomes
installed_themes=()
existing_themes=()
failed_themes=()

# Process the user's selection
if [[ "$selection" =~ ^[Aa]$ ]]; then
  # Install all themes
  for i in "${!themes[@]}"; do
    install_theme "${themes[$i]}" "${file_map[$i]}"
  done
elif [[ "$selection" =~ ^[Qq]$ ]]; then
  echo "Installation canceled."
  exit 0
else
  # Install selected themes
  for index in $selection; do
    if [[ -n "${themes[$index]}" ]]; then
      install_theme "${themes[$index]}" "${file_map[$index]}"
    else
      echo -e "${RED}Invalid selection: $index${NC}"
    fi
  done
fi

# Display installation summary
echo -e "\n${BLUE}Installation Summary:${NC}"

if [[ ${#installed_themes[@]} -gt 0 ]]; then
  echo -e "${GREEN}✓ Installed themes:${NC}"
  for theme in "${installed_themes[@]}"; do
    echo "  - $theme"
  done
elif [[ ${#existing_themes[@]} -gt 0 ]]; then
  echo -e "${YELLOW}• All selected themes were already installed.${NC}"
fi

if [[ ${#failed_themes[@]} -gt 0 ]]; then
  echo -e "${RED}✗ Failed installations:${NC}"
  for theme in "${failed_themes[@]}"; do
    echo "  - $theme"
  done
fi

# Only show the "Themes were installed in" if new themes were actually installed
if [[ ${#installed_themes[@]} -gt 0 ]]; then
  echo -e "${BLUE}\nThemes were installed in:${NC} $WARP_THEMES_DIR"
fi

echo -e "${BLUE}Installation process completed.${NC}"
