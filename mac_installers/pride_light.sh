#!/bin/bash
# Theme Configuration
readonly THEME_NAME="Pride_Light"
readonly THEME_CONTENT='terminal_colors:
  bright:
    black: "#593624"
    red: "#ff4b4b"
    green: "#1cdb55"
    yellow: "#d8ce05"
    blue: "#8080fc"
    magenta: "#e673e6"
    cyan: "#88ffff"
    white: "#ffffff"
  normal:
    black: "#352116"
    red: "#f34343"
    green: "#17c34b"
    yellow: "#bcb400"
    blue: "#6767ff"
    magenta: "#d363d3"
    cyan: "#76eded"
    white: "#fffbfb"
background: "#fff5f5"
foreground: "#6f3b6c"
accent: "#ff4583"
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
