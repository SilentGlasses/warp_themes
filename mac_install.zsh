#!/usr/bin/env zsh

# Ensure we're running with zsh
if [[ -z "$ZSH_VERSION" ]]; then
    echo "Error: This script requires zsh."
    echo "Please run with: zsh $0"
    exit 1
fi

# Use native zsh 1-based arrays throughout — no KSH_ARRAYS needed.
# All arrays in this script are 1-indexed as zsh natively expects.

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
            wait_time=$((wait_time * 2))
        fi
        ((attempt++))
    done
    return 1
}

# Robustly extract background image path from a theme YAML file.
# Scans the file line-by-line so it handles varied indentation correctly.
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
                bg_path=$(echo "$line" | sed "s/.*path:[[:space:]]*['\"]\\?//" | sed "s/['\"].*//" | tr -d '[:space:]')
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

# Set theme directories for macOS
WARP_THEMES_DIR="$HOME/.warp/themes"
WARP_PREVIEW_THEMES_DIR="$HOME/.warp-preview/themes"

clear

echo -e "\n${BOLD}${BLUE}WELCOME TO THE WARP THEME INSTALLER FOR MACOS${NC}"
echo -e "\n${BLUE}Select Warp version for theme installation:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${YELLOW}[1]${NC} Install for Warp"
echo -e "${YELLOW}[2]${NC} Install for Warp Preview"
echo -e "${YELLOW}[3]${NC} Install for both versions"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

read -r "version_selection?Select version (1-3 or Q to quit): "

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

# Fetch the list of theme files from GitHub
api_response_file="/tmp/warp_api_response.json"
if ! retry_curl "$API_URL" "$api_response_file"; then
  echo -e "${RED}Failed to retrieve theme list after multiple attempts.${NC}"
  echo -e "${YELLOW}Please check your internet connection or GitHub API limits.${NC}"
  exit 1
fi

# Parse theme filenames into a proper zsh array
theme_files=()
while IFS= read -r line; do
  [[ -n "$line" ]] && [[ "$line" =~ [^[:space:]] ]] && theme_files+=("$line")
done < <(sed -n 's/.*"name": "\([^"]*\.yaml\)".*/\1/p' "$api_response_file" | sed 's/\.yaml$//')
rm -f "$api_response_file"

if [[ ${#theme_files[@]} -eq 0 ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

# Build display name from filename (underscore → space, title case).
# This is used consistently for both the menu and the summary so names always match.
filename_to_display() {
  local filename="$1"
  echo "$filename" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))} 1'
}

# Build 1-indexed theme and file_map arrays (native zsh, no KSH_ARRAYS)
typeset -a themes
typeset -a file_map

echo -e "${BLUE}Processing ${#theme_files[@]} themes...${NC}"

for file in "${theme_files[@]}"; do
  file=$(echo "$file" | tr -d '\r\n')
  [[ -z "$file" ]] && continue

  display_name=$(filename_to_display "$file")
  themes+=("$display_name")
  file_map+=("$file.yaml")
done

if [[ ${#themes[@]} -eq 0 ]]; then
  echo -e "${RED}No theme files found in the repository.${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Found ${#themes[@]} themes available for installation${NC}"

# Display theme menu (zsh arrays are 1-based natively)
echo -e "\n${BOLD}${BLUE}Available Warp Themes:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"

for ((i=1; i<=${#themes[@]}; i++)); do
  [[ -n "${themes[$i]}" ]] && echo -e "${YELLOW}[${i}]${NC} ${themes[$i]}"
done

echo -e "${YELLOW}[A]${NC} Install all themes"
echo -e "${YELLOW}[Q]${NC} Quit"
echo -e "${YELLOW}-----------------------------------------${NC}"

echo ""
read -r "selection?Select themes to install (e.g., 1 3 5 or A for all): "

# Function to get proper version name from directory
get_version_name() {
  local dir="$1"
  if [[ "$dir" == *"preview"* ]]; then
    echo "Warp Preview"
  else
    echo "Warp"
  fi
}

# Tracking arrays — declared before install_theme is called
typeset -A installed_themes
typeset -A existing_themes
typeset -A failed_themes
typeset -A background_status

# Function to download and install a theme.
# install_key uses the numeric index + version to guarantee uniqueness.
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

  # Record successful installation before background check
  installed_themes["$install_key"]="$theme_name in $version_name"

  # Robustly extract background image path
  local bg_image
  bg_image=$(extract_bg_image "$destination")

  if [[ -n "$bg_image" ]]; then
    local bg_url="$BACKGROUNDS_BASE/$bg_image"
    local bg_destination="$install_dir/$bg_image"

    if [[ -f "$bg_destination" ]]; then
      background_installed="exists"
    else
      # Use -w to get HTTP status code, following redirects, to avoid false negatives on 302s
      local http_code
      http_code=$(curl -sSLo /dev/null -w "%{http_code}" "$bg_url")
      if [[ "$http_code" == "200" ]]; then
        if retry_curl "$bg_url" "$bg_destination"; then
          background_installed="installed"
        else
          background_installed="failed"
        fi
      else
        # Asset missing on remote: generate local 1x1 transparent PNG fallback
        echo -e "${BLUE}Generating transparent fallback for $theme_name...${NC}"
        local b64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        if command -v base64 >/dev/null; then
          echo "$b64" | base64 -d > "$bg_destination" 2>/dev/null
        else
          python3 -c "import base64; open('$bg_destination', 'wb').write(base64.b64decode('$b64'))" 2>/dev/null
        fi
        background_installed="generated"
      fi
    fi
    background_status["$install_key"]="$background_installed"
  fi
}

# Process the user's selection
if [[ "$selection" =~ ^[Aa]$ ]]; then
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing themes for $version_name...${NC}"
    for ((i=1; i<=${#themes[@]}; i++)); do
      [[ -n "${themes[$i]}" ]] && install_theme "${themes[$i]}" "${file_map[$i]}" "$dir" "$i"
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
  for dir in "${install_dirs[@]}"; do
    version_name=$(get_version_name "$dir")
    echo -e "\n${BLUE}Installing selected themes for $version_name...${NC}"
    # Use (z) flag to split selection string into words
    for index in ${(z)selection}; do
      if [[ -n "${themes[$index]}" ]]; then
        install_theme "${themes[$index]}" "${file_map[$index]}" "$dir" "$index"
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

  typeset -a warp_installed=()
  typeset -a preview_installed=()

  for key in "${(@k)installed_themes}"; do
    theme_info="${installed_themes[$key]}"
    bg_stat="${background_status[$key]}"

    [[ -z "$theme_info" ]] && continue

    if [[ "$bg_stat" == "installed" ]]; then
      display=" (with background image)"
    elif [[ "$bg_stat" == "exists" ]]; then
      display=" (background image already exists)"
    elif [[ "$bg_stat" == "generated" ]]; then
      display=" (background image generated locally)"
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

  # Sort using native zsh ordering
  if (( ${#warp_installed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${(o)warp_installed[@]}"; do
      echo "    - $theme"
    done
  fi

  if (( ${#preview_installed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp Preview:${NC}"
    for theme in "${(o)preview_installed[@]}"; do
      echo "    - $theme"
    done
  fi
fi

if (( ${#existing_themes[@]} > 0 )); then
  total_expected=$(( (${#themes[@]} + 1) * ${#install_dirs[@]} ))

  if (( ${#existing_themes[@]} == total_expected && ${#installed_themes[@]} == 0 && ${#failed_themes[@]} == 0 )); then
    echo -e "${YELLOW}• All themes are already installed in selected version(s)${NC}"
  else
    echo -e "${YELLOW}• Already installed themes:${NC}"

    typeset -a warp_themes=()
    typeset -a preview_themes=()

    for key in "${(@k)existing_themes}"; do
      theme_info="${existing_themes[$key]}"
      if [[ "$theme_info" == *"in Warp Preview"* ]]; then
        preview_themes+=("${theme_info% in Warp Preview}")
      else
        warp_themes+=("${theme_info% in Warp}")
      fi
    done

    if (( ${#warp_themes[@]} > 0 )); then
      echo -e "  ${BLUE}Warp:${NC}"
      for theme in "${(o)warp_themes[@]}"; do
        echo "    - $theme"
      done
    fi

    if (( ${#preview_themes[@]} > 0 )); then
      echo -e "  ${BLUE}Warp Preview:${NC}"
      for theme in "${(o)preview_themes[@]}"; do
        echo "    - $theme"
      done
    fi
  fi
fi

if (( ${#failed_themes[@]} > 0 )); then
  echo -e "${RED}✗ Failed installations:${NC}"

  typeset -a warp_failed=()
  typeset -a preview_failed=()

  for key in "${(@k)failed_themes}"; do
    theme_info="${failed_themes[$key]}"
    if [[ "$theme_info" == *"in Warp Preview"* ]]; then
      preview_failed+=("${theme_info% in Warp Preview}")
    else
      warp_failed+=("${theme_info% in Warp}")
    fi
  done

  if (( ${#warp_failed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${(o)warp_failed[@]}"; do
      echo "    - $theme"
    done
  fi

  if (( ${#preview_failed[@]} > 0 )); then
    echo -e "  ${BLUE}Warp Preview:${NC}"
    for theme in "${(o)preview_failed[@]}"; do
      echo "    - $theme"
    done
  fi
fi

if (( ${#installed_themes[@]} == 0 && ${#existing_themes[@]} == 0 && ${#failed_themes[@]} == 0 )); then
  echo -e "${YELLOW}• No themes were processed${NC}"
fi

# Display installation paths
echo -e "\n${BLUE}Installation paths:${NC}"
for dir in "${install_dirs[@]}"; do
  version_name=$(get_version_name "$dir")
  echo "  - $version_name: $dir"
done

# Final statistics
echo -e "\n${BOLD}${BLUE}Final Statistics:${NC}"
echo -e "${BLUE}=================${NC}"
echo -e "${GREEN}• Successfully installed: ${#installed_themes[@]} theme(s)${NC}"
echo -e "${YELLOW}• Already installed: ${#existing_themes[@]} theme(s)${NC}"
if (( ${#failed_themes[@]} > 0 )); then
  echo -e "${RED}• Failed installations: ${#failed_themes[@]} theme(s)${NC}"
fi
echo -e "${BLUE}• Total processed: $(( ${#installed_themes[@]} + ${#existing_themes[@]} + ${#failed_themes[@]} )) theme(s)${NC}"

echo -e "\n${GREEN}${BOLD}Installation process completed.${NC}"
