#!/usr/bin/env zsh

# Ensure we're running with zsh
if [[ -z "$ZSH_VERSION" ]]; then
    echo "Error: This script requires zsh."
    echo "Please run with: zsh $0"
    exit 1
fi

# Enable associative arrays in zsh
setopt KSH_ARRAYS 2>/dev/null || true

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check for required dependencies
if ! command -v curl >/dev/null; then
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

clear

# Prompt for Warp version selection
echo -e "\n${BOLD}${BLUE}WELCOME TO THE WARP THEME INSTALLER FOR MACOS${NC}"
echo -e "\n${BLUE}Select Warp version for theme installation:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${YELLOW}[1]${NC} Install for Warp"
echo -e "${YELLOW}[2]${NC} Install for Warp Preview"
echo -e "${YELLOW}[3]${NC} Install for both versions"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

# Get version selection
read -r "?Select version (1-3 or Q to quit): " version_selection

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
theme_files_raw=$(sed -n 's/.*"name": "\([^"]*\.yaml\)".*/\1/p' "$api_response_file" | sed 's/\.yaml$//')

# Clean up temporary file
rm -f "$api_response_file"

if [[ -z "$theme_files_raw" ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

# Convert newline-separated list to array for proper iteration
theme_files=()
while IFS= read -r line; do
  # Skip empty lines and lines with only whitespace
  [[ -n "$line" ]] && [[ "$line" =~ [^[:space:]] ]] && theme_files+=("$line")
done <<< "$theme_files_raw"

# Convert filenames to display-friendly names and create theme mappings
# This is much faster than downloading each file individually
declare -a themes
declare -a file_map

echo -e "${BLUE}Processing ${#theme_files[@]} themes...${NC}"

# Function to convert filename to display name
filename_to_display() {
  local filename="$1"
  # Convert underscores to spaces and capitalize words
  echo "$filename" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))} 1'
}

# Initialize arrays with empty first element to make them 1-indexed
themes[0]=""
file_map[0]=""

for file in "${theme_files[@]}"; do
  # Strip any trailing whitespace/newlines from the filename
  file=$(echo "$file" | tr -d '\r\n')
  
  # Skip empty files
  if [[ -z "$file" ]]; then
    continue
  fi
  
  # Create a user-friendly display name from filename
  display_name=$(filename_to_display "$file")
  
  themes+=("$display_name")
  file_map+=("$file.yaml")
done

if [[ ${#themes[@]} -le 1 ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Found $((${#themes[@]} - 1)) themes available for installation${NC}"

# Pretty display of theme menu (with corrected order)
echo -e "\n${BOLD}${BLUE}Available Warp Themes:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"

# Display themes with proper indexing (skip index 0 which is empty)
max_index=$((${#themes[@]} - 1))
for ((i=1; i<=max_index; i++)); do
  if [[ -n "${themes[$i]}" ]]; then
    echo -e "${YELLOW}[${i}]${NC} ${themes[$i]}"
  fi
done

echo -e "${YELLOW}[A]${NC} Install all themes"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

# Prompt the user for selection
echo ""
read -r "?Select themes to install (e.g., 1 3 5 or A for all): " selection

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
  local install_key="${theme_name}___${version_name}"

  if [[ -f "$destination" ]]; then
    existing_themes["$install_key"]="$theme_name in $version_name"
    return 2
  fi

  echo -e "${BLUE}Installing $theme_name to $version_name...${NC}"

  # Download theme with retry logic
  if ! retry_curl "$url" "$destination"; then
    echo -e "${RED}Failed to download theme $theme_name after multiple attempts.${NC}"
    failed_themes["$install_key"]="$theme_name in $version_name"
    return 1
  fi

  # Validate the downloaded theme file
  if ! validate_theme_file "$destination"; then
    echo -e "${RED}Downloaded theme file is invalid: $theme_name${NC}"
    rm -f "$destination"
    failed_themes["$install_key"]="$theme_name in $version_name"
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

  # Debug output
  echo "Debug: theme_name='$theme_name', version_name='$version_name', install_key='$install_key'"
  
  if [[ -n "$theme_name" && -n "$version_name" ]]; then
    installed_themes["$install_key"]="$theme_name in $version_name"
    background_status["$install_key"]="$background_installed"
    echo "Debug: Added to installed_themes[\"$install_key\"] = \"${installed_themes[\"$install_key\"]}\""
  else
    echo "Warning: Blank theme information found for key $install_key"
    echo "Debug: theme_name='$theme_name', version_name='$version_name'"
  fi
  return 0
}

# Arrays to track installation outcomes
declare -A installed_themes
declare -A existing_themes
declare -A failed_themes
declare -A background_status

# Process the user's selection
if [[ "$selection" =~ ^[Aa]$ ]]; then
  # Install all themes to selected directories
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing themes for $version_name...${NC}"
    for ((i=1; i<=max_index; i++)); do
      if [[ -n "${themes[$i]}" ]]; then
        install_theme "${themes[$i]}" "${file_map[$i]}" "$dir"
      fi
    done
  done
elif [[ "$selection" =~ ^[Qq]$ ]]; then
  echo -e "\n${YELLOW}Installation canceled by user.${NC}"
  echo -e "\n${BOLD}${BLUE}Installation Summary:${NC}"
  echo -e "${BLUE}===================${NC}"
  echo -e "${YELLOW}• No themes were installed${NC}"
  echo -e "\n${BLUE}Available themes remain unchanged.${NC}"
  exit 0
else
  # Install selected themes to selected directories
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing selected themes for $version_name...${NC}"
    for index in ${(z)selection}; do
      if [[ -n "${themes[$index]}" ]]; then
        install_theme "${themes[$index]}" "${file_map[$index]}" "$dir"
      else
        echo -e "${RED}Invalid selection: $index${NC}"
      fi
    done
  done
fi

# Display installation summary
echo -e "\n${BOLD}${BLUE}Installation Summary:${NC}"
echo -e "${BLUE}===================${NC}"

if (( ${#installed_themes[@]} > 0 )); then
  echo -e "${GREEN}✓ Installed themes:${NC}"

  # Create arrays for each version
  declare -a warp_installed=()
  declare -a preview_installed=()

  # Sort themes into version-specific arrays with their background status
  for key in "${(@k)installed_themes}"; do
    theme_info="${installed_themes[$key]}"
    bg_status="${background_status[$key]}"

    # Correct the theme information handling
    if [[ -z "$theme_info" ]]; then
      echo "Warning: Theme info for key '$key' is blank"
      continue
    fi

    # Create the display string with background info
    if [[ "$bg_status" == "installed" ]]; then
      display=" (with background image)"
    elif [[ "$bg_status" == "exists" ]]; then
      display=" (background image already exists)"
    elif [[ "$bg_status" == "failed" ]]; then
      display=" (background image not found)"
    else
      display=""
    fi

    if [[ "$theme_info" == *"in Warp Preview"* ]]; then
      # Strip "in Warp Preview" and add to preview array
      clean_name="${theme_info% in Warp Preview}$display"
      preview_installed+=("$clean_name")
    else
      # Strip "in Warp" and add to warp array
      clean_name="${theme_info% in Warp}$display"
      warp_installed+=("$clean_name")
    fi
  done

  # Sort the arrays
  IFS=$'\n' sorted_warp_installed=($(sort <<<"${warp_installed[*]}"))
  IFS=$'\n' sorted_preview_installed=($(sort <<<"${preview_installed[*]}"))
  unset IFS

  # Display Warp themes if any exist
  if (( ${#sorted_warp_installed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${sorted_warp_installed[@]}"; do
      echo "    - $theme"
    done
  fi

  # Display Warp Preview themes if any exist
  if (( ${#sorted_preview_installed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp Preview:${NC}"
    for theme in "${sorted_preview_installed[@]}"; do
      echo "    - $theme"
    done
  fi
  
  # If arrays are empty but we have installed themes, there might be an issue
  if (( ${#sorted_warp_installed[@]} == 0 && ${#sorted_preview_installed[@]} == 0 )); then
    echo -e "  ${YELLOW}Note: Themes were installed but not displayed in summary${NC}"
    echo -e "  ${YELLOW}Debug info:${NC}"
    echo "    - installed_themes array size: ${#installed_themes[@]}"
    echo "    - warp_installed array size: ${#warp_installed[@]}"
    echo "    - preview_installed array size: ${#preview_installed[@]}"
    echo "    - sorted_warp_installed array size: ${#sorted_warp_installed[@]}"
    echo "    - sorted_preview_installed array size: ${#sorted_preview_installed[@]}"
    echo -e "  ${YELLOW}Raw installed_themes data:${NC}"
    for key in "${(@k)installed_themes}"; do
      theme_info="${installed_themes[$key]}"
      if [[ -z "$theme_info" ]]; then
        echo "    - Key: '$key' -> Theme info is blank"
      else
        echo "    - Key: '$key' -> '$theme_info'"
      fi
    done
    echo -e "  ${YELLOW}warp_installed array contents:${NC}"
    for ((i=1; i<=${#warp_installed[@]}; i++)); do
      echo "    - [$i]: '${warp_installed[$i]}'"
    done
    echo -e "  ${YELLOW}preview_installed array contents:${NC}"
    for ((i=1; i<=${#preview_installed[@]}; i++)); do
      echo "    - [$i]: '${preview_installed[$i]}'"
    done
  fi
fi

if (( ${#existing_themes[@]} > 0 )); then
  # Count how many themes should be installed in total
  total_expected=$((${#themes[@]} * ${#install_dirs[@]}))

  # If everything is already installed, show a simpler message
  if (( ${#existing_themes[@]} == total_expected && ${#installed_themes[@]} == 0 && ${#failed_themes[@]} == 0 )); then
    echo -e "${YELLOW}• All themes are already installed in selected version(s)${NC}"
  else
    echo -e "${YELLOW}• Already installed themes:${NC}"

    # Create arrays for each version
    declare -a warp_themes=()
    declare -a preview_themes=()

    # Sort themes into version-specific arrays
    for key in "${(@k)existing_themes}"; do
      theme_info="${existing_themes[$key]}"
      if [[ "$theme_info" == *"in Warp Preview"* ]]; then
        # Strip "in Warp Preview" and add to preview array
        clean_name="${theme_info% in Warp Preview}"
        preview_themes+=("$clean_name")
      else
        # Strip "in Warp" and add to warp array
        clean_name="${theme_info% in Warp}"
        warp_themes+=("$clean_name")
      fi
    done

    # Sort the arrays
    IFS=$'\n' sorted_warp=($(sort <<<"${warp_themes[*]}"))
    IFS=$'\n' sorted_preview=($(sort <<<"${preview_themes[*]}"))
    unset IFS

    # Display Warp themes if any exist
    if (( ${#sorted_warp[@]} > 0 )); then
      echo -e "  ${BLUE}Warp:${NC}"
      for theme in "${sorted_warp[@]}"; do
        echo "    - $theme"
      done
    fi

    # Display Warp Preview themes if any exist
    if (( ${#sorted_preview[@]} > 0 )); then
      echo -e "  ${BLUE}Warp Preview:${NC}"
      for theme in "${sorted_preview[@]}"; do
        echo "    - $theme"
      done
    fi
  fi
fi

if (( ${#failed_themes[@]} > 0 )); then
  echo -e "${RED}✗ Failed installations:${NC}"

  # Create arrays for each version
  declare -a warp_failed=()
  declare -a preview_failed=()

  # Sort themes into version-specific arrays
  for key in "${(@k)failed_themes}"; do
    theme_info="${failed_themes[$key]}"
    if [[ "$theme_info" == *"in Warp Preview"* ]]; then
      # Strip "in Warp Preview" and add to preview array
      clean_name="${theme_info% in Warp Preview}"
      preview_failed+=("$clean_name")
    else
      # Strip "in Warp" and add to warp array
      clean_name="${theme_info% in Warp}"
      warp_failed+=("$clean_name")
    fi
  done

  # Sort the arrays
  IFS=$'\n' sorted_warp_failed=($(sort <<<"${warp_failed[*]}"))
  IFS=$'\n' sorted_preview_failed=($(sort <<<"${preview_failed[*]}"))
  unset IFS

  # Display Warp themes if any exist
  if (( ${#sorted_warp_failed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${sorted_warp_failed[@]}"; do
      echo "    - $theme"
    done
  fi

  # Display Warp Preview themes if any exist
  if (( ${#sorted_preview_failed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp Preview:${NC}"
    for theme in "${sorted_preview_failed[@]}"; do
      echo "    - $theme"
    done
  fi
fi

# Show message if nothing happened
if (( ${#installed_themes[@]} == 0 && ${#existing_themes[@]} == 0 && ${#failed_themes[@]} == 0 )); then
  echo -e "${YELLOW}• No themes were processed${NC}"
fi

# Display installation paths
echo -e "\n${BLUE}Installation paths:${NC}"
for dir in "${install_dirs[@]}"; do
  version_name=$(get_version_name "$dir")
  echo "  - $version_name: $dir"
done

# Display final statistics
echo -e "\n${BOLD}${BLUE}Final Statistics:${NC}"
echo -e "${BLUE}=================${NC}"
echo -e "${GREEN}• Successfully installed: ${#installed_themes[@]} theme(s)${NC}"
echo -e "${YELLOW}• Already installed: ${#existing_themes[@]} theme(s)${NC}"
if (( ${#failed_themes[@]} > 0 )); then
  echo -e "${RED}• Failed installations: ${#failed_themes[@]} theme(s)${NC}"
fi
echo -e "${BLUE}• Total processed: $(( ${#installed_themes[@]} + ${#existing_themes[@]} + ${#failed_themes[@]} )) theme(s)${NC}"

echo -e "\n${GREEN}${BOLD}Installation process completed.${NC}"
