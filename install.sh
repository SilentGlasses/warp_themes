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
BACKGROUNDS_BASE="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/backgrounds"
API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/yaml_files"

# Determine OS using uname
OS_TYPE=$(uname -s)

# Determine OS and set theme directories accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS_NAME="macOS"
  WARP_THEMES_DIR="$HOME/.warp/themes"  # macOS Warp
  WARP_PREVIEW_THEMES_DIR="$HOME/.warp-preview/themes"  # macOS Warp Preview
else
  OS_NAME="Linux"
  WARP_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"  # Linux Warp
  WARP_PREVIEW_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal-preview/themes"  # Linux Warp Preview
fi

# Display detected OS
clear
echo -e "${BOLD}${BLUE}Detected OS:${NC} $OS_NAME"

# Prompt for Warp version selection
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
  mkdir -p "$dir"
done

echo -e "${BOLD}${BLUE}Installing themes for ${version_name}...${NC}"
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
    existing_themes["$install_key"]="$theme_name in $version_name"
    return 2
  fi

  echo -e "${BLUE}Installing $theme_name to $version_name...${NC}"

  if curl -sSfL "$url" -o "$destination"; then
    # Check if the theme has a background image and download it
    local bg_image=$(grep -A1 "background_image:" "$destination" | grep "path:" | sed "s/.*path: *['\"]\(.*\)['\"].*/\1/")
    
    if [[ ! -z "$bg_image" ]]; then
      local bg_url="$BACKGROUNDS_BASE/$bg_image"
      local bg_destination="$install_dir/$bg_image"
      
      if [[ -f "$bg_destination" ]]; then
        background_installed="exists"
      elif curl -sSfL "$bg_url" -o "$bg_destination" 2>/dev/null; then
        background_installed="installed"
      else
        background_installed="failed"
        echo -e "${YELLOW}Warning: Could not download background image for $theme_name${NC}"
      fi
    fi
    
    installed_themes["$install_key"]="$theme_name in $version_name"
    background_status["$install_key"]="$background_installed"
    return 0
  else
    failed_themes["$install_key"]="$theme_name in $version_name"
    echo -e "${RED}Error: Failed to download theme $theme_name${NC}"
    return 1
  fi
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
    for i in "${!themes[@]}"; do
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
      if [[ -n "${themes[$index]}" ]]; then
        install_theme "${themes[$index]}" "${file_map[$index]}" "$dir"
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
  
  # Create arrays for each version
  declare -a warp_installed=()
  declare -a preview_installed=()
  
  # Sort themes into version-specific arrays with their background status
  for key in "${!installed_themes[@]}"; do
    theme_info="${installed_themes[$key]}"
    bg_status="${background_status[$key]}"
    
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
  if [ ${#sorted_warp_installed[@]} -gt 0 ]; then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${sorted_warp_installed[@]}"; do
      echo "    - $theme"
    done
  fi
  
  # Display Warp Preview themes if any exist
  if [ ${#sorted_preview_installed[@]} -gt 0 ]; then
    echo -e "  ${BLUE}Warp Preview:${NC}"
    for theme in "${sorted_preview_installed[@]}"; do
      echo "    - $theme"
    done
  fi
fi

if [[ ${#existing_themes[@]} -gt 0 ]]; then
  # Count how many themes should be installed in total
  total_expected=$((${#themes[@]} * ${#install_dirs[@]}))
  
  # If everything is already installed, show a simpler message
  if [[ ${#existing_themes[@]} -eq $total_expected && ${#installed_themes[@]} -eq 0 && ${#failed_themes[@]} -eq 0 ]]; then
    echo -e "${YELLOW}• All themes are already installed in selected version(s)${NC}"
  else
    echo -e "${YELLOW}• Already installed themes:${NC}"
    
    # Create arrays for each version
    declare -a warp_themes=()
    declare -a preview_themes=()
    
    # Sort themes into version-specific arrays
    for key in "${!existing_themes[@]}"; do
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
    if [ ${#sorted_warp[@]} -gt 0 ]; then
      echo -e "  ${BLUE}Warp:${NC}"
      for theme in "${sorted_warp[@]}"; do
        echo "    - $theme"
      done
    fi
    
    # Display Warp Preview themes if any exist
    if [ ${#sorted_preview[@]} -gt 0 ]; then
      echo -e "  ${BLUE}Warp Preview:${NC}"
      for theme in "${sorted_preview[@]}"; do
        echo "    - $theme"
      done
    fi
  fi
fi

if [[ ${#failed_themes[@]} -gt 0 ]]; then
  echo -e "${RED}✗ Failed installations:${NC}"
  
  # Create arrays for each version
  declare -a warp_failed=()
  declare -a preview_failed=()
  
  # Sort themes into version-specific arrays
  for key in "${!failed_themes[@]}"; do
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
  if [ ${#sorted_warp_failed[@]} -gt 0 ]; then
    echo -e "  ${BLUE}Warp:${NC}"
    for theme in "${sorted_warp_failed[@]}"; do
      echo "    - $theme"
    done
  fi
  
  # Display Warp Preview themes if any exist
  if [ ${#sorted_preview_failed[@]} -gt 0 ]; then
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
