```
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡞⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⣦
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡞⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⠟
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟   Themes for
⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟    Warp Terminal
```

If you want to get Warp, download it from [here](https://app.warp.dev/referral/2K4GVJ)

This project includes easy-to-use scripts, `install.sh` for macOS and Linux and `install.ps1` for Windows, that automates the installation of Warp themes from this repository. The script fetches available theme files directly from the repository and installs them to the correct location on your system based on your operating system.

## Features:

- **Automatic OS Detection**: The script detects whether you're using macOS or Linux and installs the themes in the appropriate directory.
- **Fetches Available Themes**: It pulls the list of themes directly from the repository, and updates the list as new themes are added.
- **Interactive Menu**: A clean, interactive menu displays all available themes, allowing you to select themes by number or install all themes at once.
- **Background Image Support**: For themes that include a background image, the installer will automatically download and install the corresponding image.
- **Installation Summary**: After installation, it provides a summary of installed themes, already existing themes, and failed installations, including background image status.
- **Pretty Display**: The menu is formatted for clarity, making the installation process easy to follow.

## Installation

### For Mac or Linux

- Run this command to initiate the installer, choose the theme you want to use or install them all:
```
bash <(curl -s https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/install.sh)
```

### For Windows

> [!NOTE]
> The Windows Installer works at the moment, but it's still a work in progress, so don't expect too much.
> Thanks for your understanding.

- Ensure PowerShell Allows Script Execution, open PowerShell as Administrator and run:
```
Set-ExecutionPolicy Bypass -Scope Process -Force
```
- Run the script from PowerShell:
```
irm https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/install.ps1 | iex
```

## Using Installed Themes

- Restart Warp if you have it running, or start it if not.
- Click `Settings` → `Appearance` → `Themes`
- Click on the `Current theme` box
- Select the newly installed theme to enable it
- Enjoy your new theme

## Available Themes

### African History

<img src="./screenshots/african_history.png" alt="African History" width="850">

### 117

<img src="./screenshots/117_dark.png" alt="117" width="850">

### Kali Blue

<img src="./screenshots/kali_blue.png" alt="Kali Blue" width="850">

### Lapiz Dark

<img src="./screenshots/lapiz_dark.png" alt="Lapiz Dark" width="850">

### Lapiz Light

<img src="./screenshots/lapiz_light.png" alt="Lapiz Light" width="850">

### LLM Dark

<img src="./screenshots/llm_dark.png" alt="LLM Dark" width="850">

### Material Dark

<img src="./screenshots/material_dark.png" alt="Material Dark" width="850">

### Matrix Dark

<img src="./screenshots/matrix_dark.png" alt="Matrix Dark" width="850">

### Mjolnir

<img src="./screenshots/mjolnir_dark.png" alt="Mjolnir" width="850">

### Neon Nights

<img src="./screenshots/neon_nights.png" alt="Neon Nights" width="850">

### Nord Dark

<img src="./screenshots/nord_dark.png" alt="Nord Dark" width="850">

### Nord Light

<img src="./screenshots/nord_light.png" alt="Nord Light" width="850">

### Pride Dark

<img src="./screenshots/pride_dark.png" alt="Pride Dark" width="850">

### Pride Light

<img src="./screenshots/pride_light.png" alt="Pride Light" width="850">

### Proton Dark

<img src="./screenshots/proton_dark.png" alt="Proton Dark" width="850">

### Spring Dark

<img src="./screenshots/spring_dark.png" alt="Spring Dark" width="850">

### Spring Light

<img src="./screenshots/spring_light.png" alt="Spring Light" width="850">

### Retro Green

<img src="./screenshots/retro_green.png" alt="Retro Green" width="850">

### Tabs Dark

<img src="./screenshots/tabs_dark.png" alt="Tabs Dark" width="850">

### Vintage Dark

<img src="./screenshots/vintage_dark.png" alt="Vintage Dark" width="850">

### Webs Dark

<img src="./screenshots/webs_dark.png" alt="Webs Dark" width="850">


### White Rabbit Dark

<img src="./screenshots/whiterabbit.png" alt="White Rabbit Dark" width="850">


## Themes with Backgrounds

Some themes include background images that will be automatically installed by the script. The installer checks for the `background_image.path` field in each theme YAML file and downloads the corresponding image from the repository's backgrounds directory.

### Strand Dark

<img src="./screenshots/strand_dark.png" alt="Strand Dark" width="850">


### Ethereal Galaxy Dark

<img src="./screenshots/ethereal_galaxy_dark.png" alt="Ethereal Galaxy Dark" width="850">
