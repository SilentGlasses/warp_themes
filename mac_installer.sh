#!/bin/bash

# Ensure we're running with bash
if [[ -z "$BASH_VERSION" ]]; then
    echo "Error: This script requires bash."
    echo "Please run with: bash $0"
    exit 1
fi

# Clear screen at the start using escape sequences for better compatibility
printf "\033[2J\033[H"

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check for required dependencies
if ! command -v curl > /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${NC}"
    echo -e "${YELLOW}Please install curl and try again.${NC}"
    exit 1
fi

# Function to validate theme file
validate_theme_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    if ! grep -q "^name:" "$file" 2>/dev/null; then
        echo -e "${YELLOW}Warning: Invalid theme file format in $file${NC}"
        return 1
    fi
    return 0
}

# Function to retry curl with exponential backoff
retry_curl() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1
    local wait_time=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -sSfL --connect-timeout 10 --max-time 30 "$url" -o "$output"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            echo -e "${YELLOW}Attempt $attempt failed, retrying in ${wait_time}s...${NC}"
            sleep $wait_time
            wait_time=$((wait_time * 2))  # Exponential backoff
        fi
        ((attempt++))
    done
    return 1
}

# GitHub repository details
REPO_USER="SilentGlasses"
REPO_NAME="warp_themes"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/yaml_files"
BACKGROUNDS_BASE="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/backgrounds"
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/yaml_files"

# Set theme directories for macOS
WARP_THEMES_DIR="$HOME/.warp/themes"
WARP_PREVIEW_THEMES_DIR="$HOME/.warp-preview/themes"

# Prompt for Warp version selection
echo -e "\n${BOLD}${BLUE}WELCOME TO THE WARP THEME INSTALLER FOR MACOS${NC}"
echo -e "\n${BOLD}${BLUE}Select Warp version for theme installation:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${YELLOW}[1]${NC} Install for Warp"
echo -e "${YELLOW}[2]${NC} Install for Warp Preview"
echo -e "${YELLOW}[3]${NC} Install for both versions"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

# Get version selection
read -p "Select version (1-3 or Q to quit): " -r version_selection

# Process version selection
case $version_selection in
  1)
    install_dirs=("$WARP_THEMES_DIR")
    version_name="Warp"
    ;;
  2)
    install_dirs=("$WARP_PREVIEW_THEMES_DIR")
    version_name="Warp Preview"
    ;;
  3)
    install_dirs=("$WARP_THEMES_DIR" "$WARP_PREVIEW_THEMES_DIR")
    version_name="both Warp versions"
    ;;
  [Qq])
    echo "Installation canceled."
    exit 0
    ;;
  *)
    echo -e "${RED}Invalid selection. Please choose 1, 2, 3, or Q.${NC}"
    exit 1
    ;;
esac

# Create theme directories if they don't exist
for dir in "${install_dirs[@]}"; do
  if ! mkdir -p "$dir" 2>/dev/null; then
    echo -e "${RED}Error: Failed to create directory $dir${NC}"
    echo -e "${YELLOW}Please check permissions and try again.${NC}"
    exit 1
  fi
done

echo -e "${BOLD}${BLUE}Installing themes for ${version_name}...${NC}"
echo -e "${BOLD}${BLUE}Fetching available themes...${NC}"

# Fetch the list of theme files from GitHub with retry logic
api_response_file="/tmp/warp_api_response.json"
if ! retry_curl "$API_URL" "$api_response_file"; then
  echo -e "${RED}Failed to retrieve theme list after multiple attempts.${NC}"
  echo -e "${YELLOW}Please check your internet connection or GitHub API limits.${NC}"
  exit 1
fi

# Parse theme files from API response
theme_files=$(sed -n 's/.*"name": "\([^\"]*\.yaml\)".*/\1/p' "$api_response_file" | sed 's/\.yaml$//')

# Clean up temporary file
rm -f "$api_response_file"

if [[ -z "$theme_files" ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

# Fetch theme names from their YAML content using regular arrays
themes=()
file_map=()
index=0

for file in $theme_files; do
  # Strip any trailing whitespace/newlines from the filename
  file=$(echo "$file" | tr -d '\r\n')
  yaml_url="$RAW_BASE/$file.yaml"
  temp_yaml="/tmp/warp_theme_${file}.yaml"
  theme_name=""

  # Download theme YAML with retry logic
  if retry_curl "$yaml_url" "$temp_yaml"; then
    # Validate the downloaded theme file
    if validate_theme_file "$temp_yaml"; then
      theme_name=$(grep "^name:" "$temp_yaml" | sed 's/^name: *//' | tr -d '"\047')
    else
      echo -e "${YELLOW}Skipping invalid theme file: $file${NC}"
      rm -f "$temp_yaml"
      continue
    fi
  else
    echo -e "${RED}Failed to download $yaml_url after multiple attempts.${NC}"
    continue
  fi

  # Clean up temporary file
  rm -f "$temp_yaml"

  if [[ -z "$theme_name" ]]; then
    theme_name="$file"  # Fallback to filename if name field is missing
  fi

  themes["$index"]="$theme_name"
  file_map["$index"]="$file.yaml"
  ((index++))
done

if [[ ${#themes[@]} -eq 0 ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

# Pretty display of theme menu (with corrected order)
echo -e "\n${BOLD}${BLUE}Available Warp Themes:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"

# Display themes with proper indexing
max_index=${#themes[@]}
for ((i=0; i<max_index; i++)); do
  if [[ -n "${themes[$i]}" ]]; then
    echo -e "${YELLOW}[$((i+1))]${NC} ${themes[$i]}"
  fi
done

echo -e "${YELLOW}[A]${NC} Install all themes"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

# Prompt the user for selection
echo ""
read -p "Select themes to install (e.g., 1 3 5 or A for all): " -r selection

# Function to get proper version name from directory
get_version_name() {
  local dir="$1"
  if [[ "$dir" == *"preview"* ]]; then
    echo "Warp Preview"
  else
    echo "Warp"
  fi
}

# Function to download and install a theme
install_theme() {
  local theme_name=$1
  local theme_file=$2
  local install_dir=$3
  local version_name=$(get_version_name "$install_dir")
  local url="$RAW_BASE/$theme_file"
  local destination="$install_dir/$theme_file"
  local background_installed=""
  local install_key="${theme_name}::${version_name}"

  if [[ -f "$destination" ]]; then
    existing_themes="${existing_themes}${install_key}=${theme_name} in ${version_name}\n"
    return 2
  fi

  echo -e "${BLUE}Installing $theme_name to $version_name...${NC}"

  # Download theme with retry logic
  if ! retry_curl "$url" "$destination"; then
    echo -e "${RED}Failed to download theme $theme_name after multiple attempts.${NC}"
    failed_themes="${failed_themes}${install_key}=${theme_name} in ${version_name}\n"
    return 1
  fi

  # Validate the downloaded theme file
  if ! validate_theme_file "$destination"; then
    echo -e "${RED}Downloaded theme file is invalid: $theme_name${NC}"
    rm -f "$destination"
    failed_themes="${failed_themes}${install_key}=${theme_name} in ${version_name}\n"
    return 1
  fi

  # Check if the theme has a background image and download it
  local bg_image=$(grep -A1 "background_image:" "$destination" | grep "path:" | sed "s/.*path: *['\"]\(.*\)['\"].*/\1/" | head -1)

  if [[ ! -z "$bg_image" ]]; then
    local bg_url="$BACKGROUNDS_BASE/$bg_image"
    local bg_destination="$install_dir/$bg_image"

    if [[ -f "$bg_destination" ]]; then
      background_installed="exists"
    elif retry_curl "$bg_url" "$bg_destination"; then
      background_installed="installed"
    else
      background_installed="failed"
      echo -e "${YELLOW}Warning: Could not download background image for $theme_name${NC}"
    fi
  fi

  installed_themes="${installed_themes}${install_key}=${theme_name} in ${version_name}\n"
  background_status="${background_status}${install_key}=${background_installed}\n"
  return 0
}

# Variables to track installation outcomes using strings
installed_themes=""
existing_themes=""
failed_themes=""
background_status=""

# Process the user's selection
if [[ "$selection" =~ ^[Aa]$ ]]; then
  # Install all themes to selected directories
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing themes for $version_name...${NC}"
    for ((i=0; i<${#themes[@]}; i++)); do
      install_theme "${themes[$i]}" "${file_map[$i]}" "$dir"
    done
  done
elif [[ "$selection" =~ ^[Qq]$ ]]; then
  echo "Installation canceled."
  exit 0
else
  # Install selected themes to selected directories
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing selected themes for $version_name...${NC}"
    for index in $selection; do
      # Convert to 0-based index
      array_index=$((index - 1))
      if [[ $array_index -ge 0 && $array_index -lt ${#themes[@]} && -n "${themes[$array_index]}" ]]; then
        install_theme "${themes[$array_index]}" "${file_map[$array_index]}" "$dir"
      else
        echo -e "${RED}Invalid selection: $index${NC}"
      fi
    done
  done
fi

# Display installation summary using simpler approach
echo -e "\n${BLUE}Installation Summary:${NC}"
if [[ -n "$installed_themes" ]]; then
  echo -e "${GREEN}✓ Installed themes:${NC}"
  echo -e "$installed_themes" | grep -v '^$' | while IFS='=' read -r key value; do
    echo "    - $value"
  done
fi

if [[ -n "$existing_themes" ]]; then
  echo -e "${YELLOW}• Already installed themes:${NC}"
  echo -e "$existing_themes" | grep -v '^$' | while IFS='=' read -r key value; do
    echo "    - $value"
  done
fi

if [[ -n "$failed_themes" ]]; then
  echo -e "${RED}✗ Failed installations:${NC}"
  echo -e "$failed_themes" | grep -v '^$' | while IFS='=' read -r key value; do
    echo "    - $value"
  done
fi

# Display installation paths
echo -e "\n${BLUE}Installation paths:${NC}"
for dir in "${install_dirs[@]}"; do
  version_name=$(get_version_name "$dir")
  echo "  - $version_name: $dir"
done

echo -e "${BLUE}Installation process completed.${NC}"
