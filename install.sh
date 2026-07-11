#!/usr/bin/env bash

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
if ! command -v curl &> /dev/null; then
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
            wait_time=$((wait_time * 2))
        fi
        ((attempt++))
    done
    return 1
}

# Function to extract background image path from a theme YAML file.
# Scans all lines for "path:" following a "background_image:" block,
# handling arbitrary indentation and whitespace robustly.
extract_bg_image() {
    local file="$1"
    local in_bg_block=0
    local bg_path=""
    while IFS= read -r line; do
        if echo "$line" | grep -q "background_image:"; then
            in_bg_block=1
            continue
        fi
        if [[ $in_bg_block -eq 1 ]]; then
            # A new top-level key (no leading whitespace) ends the block
            if echo "$line" | grep -qE "^[^[:space:]]"; then
                break
            fi
            if echo "$line" | grep -q "path:"; then
                bg_path=$(echo "$line" | sed -E "s/.*path:[[:space:]]*['\"]?//" | sed -E "s/['\"].*//")
                bg_path=$(echo "$bg_path" | tr -d '[:space:]')
                break
            fi
        fi
    done < "$file"
    echo "$bg_path"
}

# GitHub repository details
REPO_USER="SilentGlasses"
REPO_NAME="warp_themes"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/yaml_files"
BACKGROUNDS_BASE="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/backgrounds"
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/yaml_files"

# Set theme directories for Linux
WARP_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"
WARP_PREVIEW_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal-preview/themes"

# Prompt for Warp version selection
echo -e "\n${BOLD}${BLUE}WELCOME TO THE WARP THEME INSTALLER FOR LINUX${NC}"
echo -e "\n${BOLD}${BLUE}Select Warp version for theme installation:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${YELLOW}[1]${NC} Install for Warp"
echo -e "${YELLOW}[2]${NC} Install for Warp Preview"
echo -e "${YELLOW}[3]${NC} Install for both versions"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

read -p "Select version (1-3 or Q to quit): " -r version_selection

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

# Parse theme files from API response into an indexed array (handles filenames safely)
mapfile -t theme_files_raw < <(sed -n 's/.*"name": "\([^"]*\.yaml\)".*/\1/p' "$api_response_file" | sed 's/\.yaml$//')
rm -f "$api_response_file"

if [[ ${#theme_files_raw[@]} -eq 0 ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

# Fetch theme names from their YAML content
# Declare tracking arrays before any function that writes to them
declare -A themes
declare -A file_map
declare -A installed_themes
declare -A existing_themes
declare -A failed_themes
declare -A background_status
index=1

for file in "${theme_files_raw[@]}"; do
  file=$(echo "$file" | tr -d '\r\n')
  [[ -z "$file" ]] && continue

  yaml_url="$RAW_BASE/$file.yaml"
  temp_yaml="/tmp/warp_theme_${file}.yaml"
  theme_name=""

  if retry_curl "$yaml_url" "$temp_yaml"; then
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

  rm -f "$temp_yaml"

  if [[ -z "$theme_name" ]]; then
    theme_name="$file"
  fi

  # Use a safe separator that won't appear in theme names or version strings
  themes["$index"]="$theme_name"
  file_map["$index"]="$file.yaml"
  ((index++))
done

if [[ ${#themes[@]} -eq 0 ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

# Display theme menu
echo -e "\n${BOLD}${BLUE}Available Warp Themes:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"

max_index=${#themes[@]}
for ((i=1; i<=max_index; i++)); do
  if [[ -n "${themes[$i]}" ]]; then
    echo -e "${YELLOW}[${i}]${NC} ${themes[$i]}"
  fi
done

echo -e "${YELLOW}[A]${NC} Install all themes"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

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

# Function to download and install a theme.
# Uses index-based install_key to avoid any separator collision with theme names.
install_theme() {
  local theme_name=$1
  local theme_file=$2
  local install_dir=$3
  local theme_index=$4
  local version_name
  version_name=$(get_version_name "$install_dir")
  local url="$RAW_BASE/$theme_file"
  local destination="$install_dir/$theme_file"
  local background_installed=""
  # Key uses numeric index + version to guarantee uniqueness and avoid name collisions
  local install_key="${theme_index}::${version_name}"

  if [[ -f "$destination" ]]; then
    existing_themes["$install_key"]="$theme_name in $version_name"
    return 2
  fi

  echo -e "${BLUE}Installing $theme_name to $version_name...${NC}"

  if ! retry_curl "$url" "$destination"; then
    echo -e "${RED}Failed to download theme $theme_name after multiple attempts.${NC}"
    failed_themes["$install_key"]="$theme_name in $version_name"
    return 1
  fi

  if ! validate_theme_file "$destination"; then
    echo -e "${RED}Downloaded theme file is invalid: $theme_name${NC}"
    rm -f "$destination"
    failed_themes["$install_key"]="$theme_name in $version_name"
    return 1
  fi

  # Robustly extract background image path (handles varied indentation)
  local bg_image
  bg_image=$(extract_bg_image "$destination")

  if [[ -n "$bg_image" ]]; then
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

  installed_themes["$install_key"]="$theme_name in $version_name"
  background_status["$install_key"]="$background_installed"
  return 0
}

# Process the user's selection
if [[ "$selection" =~ ^[Aa]$ ]]; then
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing themes for $version_name...${NC}"
    for i in "${!themes[@]}"; do
      install_theme "${themes[$i]}" "${file_map[$i]}" "$dir" "$i"
    done
  done
elif [[ "$selection" =~ ^[Qq]$ ]]; then
  echo "Installation canceled."
  exit 0
else
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing selected themes for $version_name...${NC}"
    for index in $selection; do
      if [[ -n "${themes[$index]}" ]]; then
        install_theme "${themes[$index]}" "${file_map[$index]}" "$dir" "$index"
      else
        echo -e "${RED}Invalid selection: $index${NC}"
      fi
    done
  done
fi

# Display installation summary
echo -e "\n${BLUE}Installation Summary:${NC}"
if [[ ${#installed_themes[@]} -gt 0 ]]; then
  echo -e "${GREEN}✓ Installed themes:${NC}"

  declare -a warp_installed=()
  declare -a preview_installed=()

  for key in "${!installed_themes[@]}"; do
    theme_info="${installed_themes[$key]}"
    bg_stat="${background_status[$key]}"

    if [[ "$bg_stat" == "installed" ]]; then
      display=" (with background image)"
    elif [[ "$bg_stat" == "exists" ]]; then
      display=" (background image already exists)"
    elif [[ "$bg_stat" == "failed" ]]; then
      display=" (background image not found)"
    else
      display=""
    fi

    if [[ "$theme_info" == *"in Warp Preview"* ]]; then
      clean_name="${theme_info% in Warp Preview}$display"
      preview_installed+=("$clean_name")
    else
      clean_name="${theme_info% in Warp}$display"
      warp_installed+=("$clean_name")
    fi
  done

  IFS=$'\n' sorted_warp_installed=($(sort <<<"${warp_installed[*]}"))
  IFS=$'\n' sorted_preview_installed=($(sort <<<"${preview_installed[*]}"))
  unset IFS

  if [[ ${#sorted_warp_installed[@]} -gt 0 ]]; then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${sorted_warp_installed[@]}"; do
      echo "    - $theme"
    done
  fi

  if [[ ${#sorted_preview_installed[@]} -gt 0 ]]; then
    echo -e "  ${BLUE}Warp Preview:${NC}"
    for theme in "${sorted_preview_installed[@]}"; do
      echo "    - $theme"
    done
  fi
fi

if [[ ${#existing_themes[@]} -gt 0 ]]; then
  total_expected=$((${#themes[@]} * ${#install_dirs[@]}))

  if [[ ${#existing_themes[@]} -eq $total_expected && ${#installed_themes[@]} -eq 0 && ${#failed_themes[@]} -eq 0 ]]; then
    echo -e "${YELLOW}• All themes are already installed in selected version(s)${NC}"
  else
    echo -e "${YELLOW}• Already installed themes:${NC}"

    declare -a warp_themes=()
    declare -a preview_themes=()

    for key in "${!existing_themes[@]}"; do
      theme_info="${existing_themes[$key]}"
      if [[ "$theme_info" == *"in Warp Preview"* ]]; then
        clean_name="${theme_info% in Warp Preview}"
        preview_themes+=("$clean_name")
      else
        clean_name="${theme_info% in Warp}"
        warp_themes+=("$clean_name")
      fi
    done

    IFS=$'\n' sorted_warp=($(sort <<<"${warp_themes[*]}"))
    IFS=$'\n' sorted_preview=($(sort <<<"${preview_themes[*]}"))
    unset IFS

    if [[ ${#sorted_warp[@]} -gt 0 ]]; then
      echo -e "  ${BLUE}Warp:${NC}"
      for theme in "${sorted_warp[@]}"; do
        echo "    - $theme"
      done
    fi

    if [[ ${#sorted_preview[@]} -gt 0 ]]; then
      echo -e "  ${BLUE}Warp Preview:${NC}"
      for theme in "${sorted_preview[@]}"; do
        echo "    - $theme"
      done
    fi
  fi
fi

if [[ ${#failed_themes[@]} -gt 0 ]]; then
  echo -e "${RED}✗ Failed installations:${NC}"

  declare -a warp_failed=()
  declare -a preview_failed=()

  for key in "${!failed_themes[@]}"; do
    theme_info="${failed_themes[$key]}"
    if [[ "$theme_info" == *"in Warp Preview"* ]]; then
      clean_name="${theme_info% in Warp Preview}"
      preview_failed+=("$clean_name")
    else
      clean_name="${theme_info% in Warp}"
      warp_failed+=("$clean_name")
    fi
  done

  IFS=$'\n' sorted_warp_failed=($(sort <<<"${warp_failed[*]}"))
  IFS=$'\n' sorted_preview_failed=($(sort <<<"${preview_failed[*]}"))
  unset IFS

  if [[ ${#sorted_warp_failed[@]} -gt 0 ]]; then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${sorted_warp_failed[@]}"; do
      echo "    - $theme"
    done
  fi

  if [[ ${#sorted_preview_failed[@]} -gt 0 ]]; then
    echo -e "  ${BLUE}Warp Preview:${NC}"
    for theme in "${sorted_preview_failed[@]}"; do
      echo "    - $theme"
    done
  fi
fi

# Display installation paths
echo -e "\n${BLUE}Installation paths:${NC}"
for dir in "${install_dirs[@]}"; do
  version_name=$(get_version_name "$dir")
  echo "  - $version_name: $dir"
done

echo -e "${BLUE}Installation process completed.${NC}"
