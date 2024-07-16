#!/bin/bash
# Theme Configuration
readonly THEME_NAME="Sad_Bat"
readonly THEME_CONTENT='terminal_colors:
  bright:
    black: "#191919"
    red: "#944141"
    green: "#37703a"
    yellow: "#abb04a"
    blue: "#5865ad"
    magenta: "#8A2BE2"
    cyan: "#93acbf"
    white: "#DFE0E5"
  normal:
    black: "#191919"
    red: "#944141"
    green: "#37703a"
    yellow: "#abb04a"
    blue: "#5865ad"
    magenta: "#8A2BE2"
    cyan: "#93acbf"
    white: "#DFE0E5"
background: "#2A2C2E"
foreground: "#4A5575"
accent: "#F8F805"
details: "darker"
'
# Warp Variables
readonly WARP_THEME_DIR="$HOME/.warp/themes"
# Colors
readonly RESET="\033[0m"
readonly BLACK="\033[0;30m"
readonly BOLD="\033[1m"
readonly DIM="\033[2m"
readonly GREEN_BOLD="\033[1;32m"
readonly RED_BOLD="\033[1;31m"
readonly BACKGROUND_LIGHT_GREEN="\033[102m"
readonly BACKGROUND_LIGHT_RED="\033[101m"
printf "${BOLD}Warp-Themes Installer ${RESET}${DIM}(v1.0.0)${RESET}\n\n"
printf "${GREEN_BOLD}âœ”${RESET} ${BOLD}Installing theme:${RESET}${DIM} ${THEME_NAME}${RESET}\n"
# Check if WARP_THEME_DIR exists
if [ ! -d "${WARP_THEME_DIR}" ]; then
	printf "${GREEN_BOLD}âœ”${RESET} ${BOLD}Creating Warp Theme Directory:${RESET}${DIM} ${WARP_THEME_DIR}${RESET}\n"
	mkdir -p "${WARP_THEME_DIR}"
fi
# Check if theme file already exists
if [ -f "${WARP_THEME_DIR}/${THEME_NAME}.yaml" ]; then
	printf "${RED_BOLD}âœ—${RESET} ${BOLD}Theme already exists:${RESET} ${DIM}${WARP_THEME_DIR}/${THEME_NAME}.yaml\n\n"
	printf "${BLACK}${BACKGROUND_LIGHT_RED} Next steps ${RESET}\n\n"
	printf "Delete the file to continue\n"
	printf "Copy and paste ${DIM}rm ${WARP_THEME_DIR}/${THEME_NAME}.yaml ${RESET}into your terminal\n"
	exit 1
fi
touch "${WARP_THEME_DIR}/${THEME_NAME}.yaml"
echo "${THEME_CONTENT}" > "${WARP_THEME_DIR}/${THEME_NAME}.yaml"
printf "${GREEN_BOLD}âœ”${RESET} ${GREEN}Successfully installed the theme!\n\n"
printf "${BLACK}${BACKGROUND_LIGHT_GREEN} Next steps ${RESET}\n\n"
printf "Restart Warp and select ${GREEN_BOLD}${THEME_NAME} ${RESET}from the Theme Picker\n\n"
printf "Don't know how to open the Theme Picker? ${GREEN_BOLD}https://docs.warp.dev/features/themes#how-to-access-it${RESET}\n"
printf "${DIM}Enjoy your new theme!${RESET}\n"
