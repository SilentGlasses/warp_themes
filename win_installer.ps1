# Warp Theme Installer
<#
.SYNOPSIS
    Installs custom themes for Warp terminal from GitHub repository.

.DESCRIPTION
    This script provides a graphical interface to download and install custom themes
    for Warp and Warp Preview terminals. It features parallel downloads, error handling,
    and automatic background image installation.

.NOTES
    Requires: PowerShell 5.1 or higher
    Author: SilentGlasses
    Repository: https://github.com/SilentGlasses/warp_themes
#>

# Check PowerShell version
$requiredVersion = [version]"5.1"
$currentVersion = $PSVersionTable.PSVersion

if ($currentVersion -lt $requiredVersion) {
    Write-Error "This script requires PowerShell $requiredVersion or higher. Current version: $currentVersion"
    exit 1
}

if ($currentVersion.Major -eq 5) {
    Write-Warning "You are using PowerShell 5.1. For better performance, consider upgrading to PowerShell 7+."
    Start-Sleep -Seconds 2
}

# Load required assemblies early for PS 5.1 compatibility
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Ensure TLS 1.2 or higher for secure connections
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

# Define variables
$repoRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/yaml_files"
$backgroundsRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/backgrounds"
$repoApiUrl = "https://api.github.com/repos/SilentGlasses/warp_themes/contents/yaml_files"
$warpThemePath = "${env:AppData}\warp\Warp\data\themes"
$warpPreviewThemePath = "${env:AppData}\warp-preview\Warp\data\themes"

# UI Constants
$script:UIConstants = @{
    CheckedListBoxColumnWidth = 280
    CheckedListBoxItemHeight = 32
    ButtonWidth = 120
    ButtonHeight = 36
    DefaultTimeout = 30  # seconds for web requests
    MaxRetries = 3
    MaxFileSize = 10MB   # Maximum file size for downloads
    MaxImageSize = 5MB   # Maximum image file size
}

# Cache for API responses
$script:ThemeFileCache = $null

# Windows 11 color palette
$script:Win11Colors = @{
    Background = [System.Drawing.Color]::FromArgb(248, 248, 248)
    Surface = [System.Drawing.Color]::FromArgb(255, 255, 255)
    Primary = [System.Drawing.Color]::FromArgb(0, 103, 192)
    PrimaryHover = [System.Drawing.Color]::FromArgb(16, 110, 190)
    Secondary = [System.Drawing.Color]::FromArgb(72, 70, 68)
    SecondaryHover = [System.Drawing.Color]::FromArgb(96, 94, 92)
    Accent = [System.Drawing.Color]::FromArgb(0, 120, 215)
    Success = [System.Drawing.Color]::FromArgb(16, 124, 16)
    Warning = [System.Drawing.Color]::FromArgb(157, 93, 0)
    Error = [System.Drawing.Color]::FromArgb(196, 43, 28)
    Border = [System.Drawing.Color]::FromArgb(200, 198, 196)
    BorderDark = [System.Drawing.Color]::FromArgb(96, 94, 92)
    TextPrimary = [System.Drawing.Color]::FromArgb(50, 49, 48)
    TextSecondary = [System.Drawing.Color]::FromArgb(96, 94, 92)
    TextOnSecondary = [System.Drawing.Color]::White
}

# To keep track of selected version
$script:selectedPaths = @()

<#
.SYNOPSIS
    Gets the filename without extension in a PowerShell 5.1 compatible way.

.PARAMETER FilePath
    The full path or filename to process.

.OUTPUTS
    String. The filename without its extension.
#>
function Get-FileNameWithoutExtension {
    param([string]$FilePath)
    $fileName = Split-Path $FilePath -Leaf
    $lastDot = $fileName.LastIndexOf('.')
    if ($lastDot -gt 0) {
        return $fileName.Substring(0, $lastDot)
    }
    return $fileName
}

<#
.SYNOPSIS
    Validates that a file path is safe and doesn't contain path traversal sequences.

.PARAMETER FilePath
    The file path to validate.

.OUTPUTS
    Boolean. True if the path is safe, False otherwise.
#>
function Test-SafeFilePath {
    param([string]$FilePath)

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return $false
    }

    # Check for path traversal sequences
    if ($FilePath -match '\.\.[\\/]' -or $FilePath -match '[\\/]\.\.') {
        Write-Warning "Path traversal detected in filename: $FilePath"
        return $false
    }

    # Check if path is rooted (absolute path)
    if ([System.IO.Path]::IsPathRooted($FilePath)) {
        Write-Warning "Absolute path detected in filename: $FilePath"
        return $false
    }

    # Check for invalid characters
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($char in $invalidChars) {
        if ($FilePath.Contains($char)) {
            Write-Warning "Invalid character detected in filename: $FilePath"
            return $false
        }
    }

    return $true
}

<#
.SYNOPSIS
    Validates downloaded file size and type.

.PARAMETER FilePath
    Path to the downloaded file.

.PARAMETER FileType
    Expected file type: 'yaml' or 'image'.

.OUTPUTS
    Hashtable with Success (bool) and Message (string) keys.
#>
function Test-DownloadedFile {
    param(
        [string]$FilePath,
        [string]$FileType
    )

    $result = @{ Success = $true; Message = "" }

    if (-not (Test-Path $FilePath)) {
        $result.Success = $false
        $result.Message = "File not found: $FilePath"
        return $result
    }

    # Check file size
    $fileInfo = Get-Item $FilePath
    $maxSize = if ($FileType -eq 'image') { $script:UIConstants.MaxImageSize } else { $script:UIConstants.MaxFileSize }

    if ($fileInfo.Length -gt $maxSize) {
        $result.Success = $false
        $result.Message = "File exceeds maximum size limit: $($fileInfo.Length) bytes (max: $maxSize bytes)"
        return $result
    }

    if ($fileInfo.Length -eq 0) {
        $result.Success = $false
        $result.Message = "Downloaded file is empty"
        return $result
    }

    # Validate file type
    if ($FileType -eq 'yaml') {
        try {
            $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($content)) {
                $result.Success = $false
                $result.Message = "YAML file is empty or invalid"
                return $result
            }
            if ($content -notmatch '[a-zA-Z_]+:') {
                $result.Success = $false
                $result.Message = "File does not appear to be valid YAML"
                return $result
            }
        } catch {
            $result.Success = $false
            $result.Message = "Failed to read YAML file: $($_.Exception.Message)"
            return $result
        }
    } elseif ($FileType -eq 'image') {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($FilePath)
            if ($bytes.Length -lt 4) {
                $result.Success = $false
                $result.Message = "File is too small to be a valid image"
                return $result
            }

            $isPng  = ($bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47)
            $isJpg  = ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8 -and $bytes[2] -eq 0xFF)
            $isGif  = ($bytes[0] -eq 0x47 -and $bytes[1] -eq 0x49 -and $bytes[2] -eq 0x46)
            $isWebp = ($bytes.Length -ge 12 -and $bytes[8] -eq 0x57 -and $bytes[9] -eq 0x45 -and $bytes[10] -eq 0x42 -and $bytes[11] -eq 0x50)

            if (-not ($isPng -or $isJpg -or $isGif -or $isWebp)) {
                $result.Success = $false
                $result.Message = "File does not appear to be a valid image (PNG, JPG, GIF, or WebP)"
                return $result
            }
        } catch {
            $result.Success = $false
            $result.Message = "Failed to validate image file: $($_.Exception.Message)"
            return $result
        }
    }

    return $result
}

<#
.SYNOPSIS
    Ensures destination directories exist and are writable.

.DESCRIPTION
    Creates theme directories if they don't exist and validates write permissions.

.OUTPUTS
    Hashtable with Success (bool) and Message (string) keys.
#>
function Initialize-DestinationDirectories {
    $result = @{ Success = $true; Message = "" }

    foreach ($path in $script:selectedPaths) {
        $versionName = if ($path.Contains('preview')) { 'Warp Preview' } else { 'Warp' }

        if (-not (Test-Path $path)) {
            Write-Host "Creating theme directory for $versionName..."
            try {
                New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop | Out-Null
            } catch {
                $result.Success = $false
                $result.Message = "Failed to create directory for ${versionName}: $($_.Exception.Message). Please check your permissions."
                return $result
            }
        }

        # Validate write permissions
        $testFile = Join-Path $path "_write_test_$(Get-Random).tmp"
        try {
            [System.IO.File]::WriteAllText($testFile, "test")
        } catch {
            $result.Success = $false
            $result.Message = "No write permission for ${versionName} directory: $path. Please check your permissions or run as administrator."
            return $result
        } finally {
            if (Test-Path $testFile) {
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    return $result
}

<#
.SYNOPSIS
    Gets a list of YAML theme files from the GitHub repository.

.DESCRIPTION
    Fetches the theme file list from GitHub API with timeout and error handling.
    Results are cached to avoid redundant API calls.

.OUTPUTS
    Array of theme filenames.
#>
function Get-ThemeFiles {
    # Return cached data if available
    if ($null -ne $script:ThemeFileCache) {
        Write-Host "Using cached theme file list..."
        return $script:ThemeFileCache
    }

    # Validate repository URL
    if ($repoApiUrl -notmatch '^https://api\.github\.com/repos/SilentGlasses/warp_themes/') {
        throw "Invalid repository URL detected. Security check failed."
    }

    Write-Host "Fetching list of theme files from GitHub..."

    $maxRetries = $script:UIConstants.MaxRetries
    $retryCount = 0
    $lastError = $null

    while ($retryCount -lt $maxRetries) {
        try {
            $themeFilesResponse = Invoke-RestMethod -Uri $repoApiUrl -TimeoutSec $script:UIConstants.DefaultTimeout -ErrorAction Stop
            $themeFiles = $themeFilesResponse | Where-Object { $_.name -match "\.yaml$" } | ForEach-Object { $_.name }

            if ($themeFiles.Count -eq 0) {
                throw "No theme files found in repository."
            }

            $script:ThemeFileCache = $themeFiles
            Write-Host "Successfully fetched $($themeFiles.Count) theme files."
            return $themeFiles
        } catch {
            $lastError = $_
            $retryCount++

            if ($retryCount -lt $maxRetries) {
                $waitTime = [math]::Pow(2, $retryCount)
                Write-Host "Failed to fetch theme files (attempt $retryCount/$maxRetries). Retrying in $waitTime seconds..."
                Start-Sleep -Seconds $waitTime
            }
        }
    }

    $errorMessage = "Failed to fetch theme files after $maxRetries attempts. Please check your internet connection and try again.`n`nError details: $($lastError.Exception.Message)"
    Write-Host $errorMessage
    [System.Windows.Forms.MessageBox]::Show($errorMessage, "Network Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

<#
.SYNOPSIS
    Makes the process DPI-aware for proper scaling on high-DPI displays.
#>
function Set-ProcessDPIAware {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class DPIHelper {
        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();
    }
"@
    [DPIHelper]::SetProcessDPIAware() | Out-Null
}

<#
.SYNOPSIS
    Creates a modern Windows 11 style button.

.PARAMETER Text
    The text to display on the button.

.PARAMETER BackColor
    The background color of the button.

.PARAMETER ForeColor
    The text color of the button.

.PARAMETER HoverColor
    The background color when hovering over the button.

.PARAMETER BorderColor
    The border color of the button.

.PARAMETER Width
    The width of the button in pixels.

.PARAMETER Height
    The height of the button in pixels.

.OUTPUTS
    System.Windows.Forms.Button
#>
function New-ModernButton {
    param(
        [string]$Text,
        [System.Drawing.Color]$BackColor = $script:Win11Colors.Primary,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::White,
        [System.Drawing.Color]$HoverColor = $script:Win11Colors.PrimaryHover,
        [System.Drawing.Color]$BorderColor = $script:Win11Colors.Border,
        [int]$Width = $script:UIConstants.ButtonWidth,
        [int]$Height = $script:UIConstants.ButtonHeight
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $BorderColor
    $button.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $button.UseVisualStyleBackColor = $false

    $button.Tag = @{
        OriginalBackColor = $BackColor
        HoverColor = $HoverColor
    }

    $button.Add_MouseEnter({
        $this.BackColor = $this.Tag.HoverColor
    })
    $button.Add_MouseLeave({
        $this.BackColor = $this.Tag.OriginalBackColor
    })

    return $button
}

<#
.SYNOPSIS
    Shows a notification in the status area.

.PARAMETER StatusLabel
    The label control to update with the message.

.PARAMETER Message
    The message to display.

.PARAMETER Type
    The type of notification: Info, Success, Warning, or Error.
#>
function Show-StatusNotification {
    param(
        [System.Windows.Forms.Label]$StatusLabel,
        [string]$Message,
        [string]$Type = "Info"
    )

    $color = switch ($Type) {
        "Success" { $script:Win11Colors.Success }
        "Warning" { $script:Win11Colors.Warning }
        "Error"   { $script:Win11Colors.Error }
        default   { $script:Win11Colors.TextPrimary }
    }

    $StatusLabel.Text = $Message
    $StatusLabel.ForeColor = $color
}

<#
.SYNOPSIS
    Shows a modern result dialog after theme installation.

.PARAMETER installedThemes
    Hashtable of newly installed themes organized by version.

.PARAMETER alreadyInstalledThemes
    Hashtable of themes that were already installed.

.PARAMETER themeBackgroundStatus
    Hashtable tracking background image installation status.

.PARAMETER isInstallAll
    Boolean indicating if all themes were being installed.

.PARAMETER totalAlreadyInstalled
    Count of themes that were already installed.

.PARAMETER totalExpected
    Total number of themes expected to be installed.

.PARAMETER selectedPaths
    Array of installation paths.

.PARAMETER missingBackgrounds
    Array of hashtables describing backgrounds that could not be downloaded.
#>
function Show-ModernResultDialog {
    param(
        [hashtable]$installedThemes,
        [hashtable]$alreadyInstalledThemes,
        [hashtable]$themeBackgroundStatus,
        [bool]$isInstallAll,
        [int]$totalAlreadyInstalled,
        [int]$totalExpected,
        [array]$selectedPaths,
        [array]$missingBackgrounds = @()
    )

    $resultForm = New-Object System.Windows.Forms.Form
    $resultForm.Text = "Installation Complete"
    $resultForm.Size = New-Object System.Drawing.Size(700, 600)
    $resultForm.MinimumSize = New-Object System.Drawing.Size(600, 400)
    $resultForm.StartPosition = "CenterParent"
    $resultForm.BackColor = $script:Win11Colors.Background
    $resultForm.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $resultForm.Padding = New-Object System.Windows.Forms.Padding(24)

    $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainPanel.RowCount = 3
    $mainPanel.ColumnCount = 1
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70))) | Out-Null
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 60))) | Out-Null
    $resultForm.Controls.Add($mainPanel)

    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $headerPanel.BackColor = $script:Win11Colors.Background
    $mainPanel.Controls.Add($headerPanel, 0, 0)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Theme Installation Summary"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $script:Win11Colors.TextPrimary
    $titleLabel.Location = New-Object System.Drawing.Point(0, 20)
    $titleLabel.AutoSize = $true
    $headerPanel.Controls.Add($titleLabel)

    $installedCount = 0
    foreach ($version in $installedThemes.Keys) {
        $installedCount += $installedThemes[$version].Count
    }

    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.BackColor = $script:Win11Colors.Surface
    $scrollPanel.AutoScroll = $true
    $scrollPanel.Padding = New-Object System.Windows.Forms.Padding(24)
    $mainPanel.Controls.Add($scrollPanel, 0, 1)

    $contentPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $contentPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $contentPanel.WrapContents = $false
    $contentPanel.AutoSize = $true
    $contentPanel.Width = 600
    $scrollPanel.Controls.Add($contentPanel)

    # Helper: add a section header label to contentPanel
    function Add-SectionHeader {
        param([string]$Text, [System.Drawing.Color]$Color)
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $Text
        $lbl.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 12, [System.Drawing.FontStyle]::Bold)
        $lbl.ForeColor = $Color
        $lbl.AutoSize = $true
        $lbl.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
        $contentPanel.Controls.Add($lbl)
    }

    # Helper: add a table header row
    function Add-TableHeader {
        param([System.Drawing.Color]$Color)
        $hp = New-Object System.Windows.Forms.Panel
        $hp.Height = 28; $hp.Width = 560
        $hp.Margin = New-Object System.Windows.Forms.Padding(20, 4, 0, 8)
        foreach ($col in @(@{T="Theme Name";X=0;W=200}, @{T="Warp Version";X=200;W=150}, @{T="Background";X=350;W=210})) {
            $l = New-Object System.Windows.Forms.Label
            $l.Text = $col.T
            $l.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9, [System.Drawing.FontStyle]::Bold)
            $l.ForeColor = $Color
            $l.AutoSize = $false; $l.Width = $col.W
            $l.Location = New-Object System.Drawing.Point($col.X, 0)
            $hp.Controls.Add($l)
        }
        $contentPanel.Controls.Add($hp)
    }

    # Helper: add a spacer
    function Add-Spacer {
        $s = New-Object System.Windows.Forms.Label
        $s.Height = 20; $s.Width = 600
        $contentPanel.Controls.Add($s)
    }

    # Show newly installed themes
    if ($installedCount -gt 0) {
        Add-SectionHeader -Text "NEWLY INSTALLED THEMES" -Color $script:Win11Colors.Success
        Add-TableHeader -Color $script:Win11Colors.TextPrimary

        $themesByName = @{}
        foreach ($version in $installedThemes.Keys) {
            foreach ($theme in $installedThemes[$version]) {
                $themeName = Get-FileNameWithoutExtension -FilePath $theme
                if (-not $themesByName.ContainsKey($themeName)) {
                    $themesByName[$themeName] = @{ Versions = @(); BackgroundStatus = @{} }
                }
                $themesByName[$themeName].Versions += $version
                if ($themeBackgroundStatus.ContainsKey("$version::$theme")) {
                    $themesByName[$themeName].BackgroundStatus[$version] = $themeBackgroundStatus["$version::$theme"]
                }
            }
        }

        foreach ($themeName in ($themesByName.Keys | Sort-Object)) {
            $tp = New-Object System.Windows.Forms.Panel
            $tp.Height = 24; $tp.Width = 560
            $tp.Margin = New-Object System.Windows.Forms.Padding(20, 1, 0, 1)

            $nl = New-Object System.Windows.Forms.Label
            $nl.Text = $themeName
            $nl.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $nl.ForeColor = $script:Win11Colors.TextPrimary
            $nl.AutoSize = $false; $nl.Width = 200
            $nl.Location = New-Object System.Drawing.Point(0, 2)
            $tp.Controls.Add($nl)

            $versionText = if ($themesByName[$themeName].Versions.Count -eq 2) { "Both" } else { $themesByName[$themeName].Versions[0] }
            $vl = New-Object System.Windows.Forms.Label
            $vl.Text = $versionText
            $vl.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $vl.ForeColor = $script:Win11Colors.TextPrimary
            $vl.AutoSize = $false; $vl.Width = 150
            $vl.Location = New-Object System.Drawing.Point(200, 2)
            $tp.Controls.Add($vl)

            $bl = New-Object System.Windows.Forms.Label
            $bl.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $bl.AutoSize = $false; $bl.Width = 210
            $bl.Location = New-Object System.Drawing.Point(350, 2)
            $statuses = $themesByName[$themeName].BackgroundStatus.Values | Select-Object -Unique
            if ($statuses.Count -eq 0 -or ($statuses.Count -eq 1 -and $null -eq $statuses[0])) {
                $bl.Text = "No Background"; $bl.ForeColor = $script:Win11Colors.TextSecondary
            } elseif ($statuses -contains "installed") {
                $bl.Text = "Background Installed"; $bl.ForeColor = $script:Win11Colors.Success
            } elseif ($statuses -contains "exists") {
                $bl.Text = "Background Already Exists"; $bl.ForeColor = $script:Win11Colors.TextSecondary
            } else {
                $bl.Text = "Background Not Found"; $bl.ForeColor = $script:Win11Colors.Warning
            }
            $tp.Controls.Add($bl)
            $contentPanel.Controls.Add($tp)
        }
    }

    # Show already installed themes
    if ($totalAlreadyInstalled -gt 0) {
        if ($installedCount -gt 0) { Add-Spacer }
        Add-SectionHeader -Text "ALREADY INSTALLED THEMES" -Color $script:Win11Colors.TextSecondary
        Add-TableHeader -Color $script:Win11Colors.TextSecondary

        $themesByName = @{}
        foreach ($version in $alreadyInstalledThemes.Keys) {
            foreach ($theme in $alreadyInstalledThemes[$version]) {
                $themeName = Get-FileNameWithoutExtension -FilePath $theme
                if (-not $themesByName.ContainsKey($themeName)) { $themesByName[$themeName] = @() }
                $themesByName[$themeName] += $version
            }
        }

        foreach ($themeName in ($themesByName.Keys | Sort-Object)) {
            $tp = New-Object System.Windows.Forms.Panel
            $tp.Height = 24; $tp.Width = 560
            $tp.Margin = New-Object System.Windows.Forms.Padding(20, 1, 0, 1)

            $nl = New-Object System.Windows.Forms.Label
            $nl.Text = $themeName
            $nl.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $nl.ForeColor = $script:Win11Colors.TextSecondary
            $nl.AutoSize = $false; $nl.Width = 200
            $nl.Location = New-Object System.Drawing.Point(0, 2)
            $tp.Controls.Add($nl)

            $versionText = if ($themesByName[$themeName].Count -eq 2) { "Both" } else { $themesByName[$themeName][0] }
            $vl = New-Object System.Windows.Forms.Label
            $vl.Text = $versionText
            $vl.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $vl.ForeColor = $script:Win11Colors.TextSecondary
            $vl.AutoSize = $false; $vl.Width = 150
            $vl.Location = New-Object System.Drawing.Point(200, 2)
            $tp.Controls.Add($vl)

            $dl = New-Object System.Windows.Forms.Label
            $dl.Text = "-"
            $dl.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $dl.ForeColor = $script:Win11Colors.TextSecondary
            $dl.AutoSize = $false; $dl.Width = 210
            $dl.Location = New-Object System.Drawing.Point(350, 2)
            $tp.Controls.Add($dl)

            $contentPanel.Controls.Add($tp)
        }
    }

    # Installation paths
    Add-Spacer
    Add-SectionHeader -Text "INSTALLATION PATHS" -Color $script:Win11Colors.TextPrimary

    foreach ($path in $selectedPaths) {
        $versionName = if ($path -like "*preview*") { "Warp Preview" } else { "Warp" }
        $pl = New-Object System.Windows.Forms.Label
        $pl.Text = "- $versionName`: $path"
        $pl.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 8)
        $pl.ForeColor = $script:Win11Colors.TextSecondary
        $pl.AutoSize = $true
        $pl.Margin = New-Object System.Windows.Forms.Padding(20, 1, 0, 1)
        $contentPanel.Controls.Add($pl)
    }

    # Missing backgrounds
    if ($missingBackgrounds.Count -gt 0) {
        Add-Spacer
        Add-SectionHeader -Text "MISSING BACKGROUNDS" -Color $script:Win11Colors.Warning
        foreach ($bgInfo in $missingBackgrounds) {
            $ml = New-Object System.Windows.Forms.Label
            $ml.Text = "- $($bgInfo.ThemeName) ($($bgInfo.Version)): $($bgInfo.BackgroundFile)"
            $ml.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $ml.ForeColor = $script:Win11Colors.TextSecondary
            $ml.AutoSize = $true
            $ml.MaximumSize = New-Object System.Drawing.Size(560, 0)
            $ml.Margin = New-Object System.Windows.Forms.Padding(20, 1, 0, 1)
            $contentPanel.Controls.Add($ml)
        }
    }

    # Usage tip
    if ($installedCount -gt 0) {
        Add-Spacer
        $tipLabel = New-Object System.Windows.Forms.Label
        $tipLabel.Text = "TIP: To use your new themes, restart Warp and select them from Settings > Appearance > Themes"
        $tipLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9, [System.Drawing.FontStyle]::Italic)
        $tipLabel.ForeColor = $script:Win11Colors.Primary
        $tipLabel.AutoSize = $true
        $tipLabel.MaximumSize = New-Object System.Drawing.Size(560, 0)
        $tipLabel.Margin = New-Object System.Windows.Forms.Padding(20, 8, 0, 0)
        $contentPanel.Controls.Add($tipLabel)
    }

    # Button area
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttonPanel.BackColor = $script:Win11Colors.Background
    $mainPanel.Controls.Add($buttonPanel, 0, 2)

    $okButton = New-ModernButton -Text "OK" -Width 120 -Height 36
    $okButton.Location = New-Object System.Drawing.Point(266, 12)
    $okButton.Add_Click({ $resultForm.Close() })
    $buttonPanel.Controls.Add($okButton)

    $resultForm.ShowDialog() | Out-Null
}

<#
.SYNOPSIS
    Downloads and installs theme files with parallel processing where available.

.DESCRIPTION
    Downloads theme files and their background images from GitHub repository
    with timeout handling, retry logic, and parallel downloads on PowerShell 7+.
    Falls back to sequential processing on PowerShell 5.1.

.PARAMETER themes
    Array of theme filenames to install.

.PARAMETER isInstallAll
    Boolean indicating if all themes are being installed.

.PARAMETER statusLabel
    Label control for displaying status messages.

.PARAMETER progressBar
    Optional progress bar control for visual feedback.
#>
function Install-Themes {
    param (
        [array]$themes,
        [bool]$isInstallAll,
        [System.Windows.Forms.Label]$statusLabel,
        [System.Windows.Forms.ProgressBar]$progressBar = $null
    )

    $installedThemes = @{}
    $alreadyInstalledThemes = @{}
    $themeBackgroundStatus = @{}
    $missingBackgrounds = @()
    $totalOperations = $themes.Count * $script:selectedPaths.Count
    $currentOperation = 0

    foreach ($installPath in $script:selectedPaths) {
        $versionName = if ($installPath -like "*preview*") { "Warp Preview" } else { "Warp" }
        Show-StatusNotification -StatusLabel $statusLabel -Message "Installing themes for $versionName..." -Type "Info"

        $notInstalledThemes = @()

        foreach ($file in $themes) {
            $currentOperation++
            if ($progressBar) {
                $progressBar.Value = [math]::Min(100, [int](($currentOperation / $totalOperations) * 100))
            }

            $destinationPath = "$installPath\$file"
            if (Test-Path $destinationPath) {
                if (-not $alreadyInstalledThemes.ContainsKey($versionName)) {
                    $alreadyInstalledThemes[$versionName] = @()
                }
                $alreadyInstalledThemes[$versionName] += $file
            } else {
                $notInstalledThemes += $file
            }
        }

        if ($notInstalledThemes.Count -gt 0) {
            Show-StatusNotification -StatusLabel $statusLabel -Message "Downloading $($notInstalledThemes.Count) themes for $versionName..." -Type "Info"

            $useParallel = $PSVersionTable.PSVersion.Major -ge 7 -and $notInstalledThemes.Count -gt 1

            if ($useParallel) {
                # Capture values needed inside parallel runspaces.
                # Functions defined in the outer scope are NOT available in parallel runspaces;
                # pass their logic inline or via captured scriptblocks through $using:.
                $capturedRawUrl        = $repoRawUrl
                $capturedBgUrl         = $backgroundsRawUrl
                $capturedInstallPath   = $installPath
                $capturedTimeout       = $script:UIConstants.DefaultTimeout
                $capturedMaxRetries    = $script:UIConstants.MaxRetries
                $capturedMaxFileSize   = $script:UIConstants.MaxFileSize
                $capturedMaxImageSize  = $script:UIConstants.MaxImageSize

                $downloadResults = $notInstalledThemes | ForEach-Object -Parallel {
                    $file              = $_
                    $repoRawUrl        = $using:capturedRawUrl
                    $backgroundsRawUrl = $using:capturedBgUrl
                    $installPath       = $using:capturedInstallPath
                    $timeout           = $using:capturedTimeout
                    $maxRetries        = $using:capturedMaxRetries
                    $maxFileSize       = $using:capturedMaxFileSize
                    $maxImageSize      = $using:capturedMaxImageSize

                    $result = @{
                        File             = $file
                        Success          = $false
                        Error            = $null
                        BackgroundStatus = $null
                        BackgroundFile   = $null
                    }

                    # Inline YAML validation (functions not available in parallel runspace)
                    function Test-YamlFile($path, $maxSize) {
                        if (-not (Test-Path $path)) { return @{ Success=$false; Message="Not found" } }
                        $fi = Get-Item $path
                        if ($fi.Length -gt $maxSize) { return @{ Success=$false; Message="Too large" } }
                        if ($fi.Length -eq 0)        { return @{ Success=$false; Message="Empty" } }
                        $c = Get-Content $path -Raw -ErrorAction SilentlyContinue
                        if ([string]::IsNullOrWhiteSpace($c) -or $c -notmatch '[a-zA-Z_]+:') {
                            return @{ Success=$false; Message="Invalid YAML" }
                        }
                        return @{ Success=$true; Message="" }
                    }

                    # Inline image validation
                    function Test-ImageFile($path, $maxSize) {
                        if (-not (Test-Path $path)) { return @{ Success=$false; Message="Not found" } }
                        $fi = Get-Item $path
                        if ($fi.Length -gt $maxSize) { return @{ Success=$false; Message="Too large" } }
                        if ($fi.Length -eq 0)        { return @{ Success=$false; Message="Empty" } }
                        try {
                            $b = [System.IO.File]::ReadAllBytes($path)
                            if ($b.Length -lt 4)   { return @{ Success=$false; Message="Too small" } }
                            $ok = ($b[0] -eq 0x89 -and $b[1] -eq 0x50) -or  # PNG
                                  ($b[0] -eq 0xFF -and $b[1] -eq 0xD8) -or  # JPG
                                  ($b[0] -eq 0x47 -and $b[1] -eq 0x49) -or  # GIF
                                  ($b.Length -ge 12 -and $b[8] -eq 0x57 -and $b[9] -eq 0x45)  # WebP
                            if (-not $ok) { return @{ Success=$false; Message="Not a valid image" } }
                        } catch { return @{ Success=$false; Message=$_.Exception.Message } }
                        return @{ Success=$true; Message="" }
                    }

                    # Inline path safety check
                    function Test-PathSafe($p) {
                        if ([string]::IsNullOrWhiteSpace($p)) { return $false }
                        if ($p -match '\.\.[\\/]' -or $p -match '[\\/]\.\.') { return $false }
                        if ([System.IO.Path]::IsPathRooted($p)) { return $false }
                        $invalid = [System.IO.Path]::GetInvalidFileNameChars()
                        foreach ($c in $invalid) { if ($p.Contains($c)) { return $false } }
                        return $true
                    }

                    $fileUrl         = "$repoRawUrl/$file"
                    $destinationPath = "$installPath\$file"
                    $retryCount      = 0

                    while ($retryCount -lt $maxRetries) {
                        try {
                            Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -TimeoutSec $timeout -ErrorAction Stop
                            $v = Test-YamlFile $destinationPath $maxFileSize
                            if (-not $v.Success) {
                                Remove-Item $destinationPath -Force -ErrorAction SilentlyContinue
                                throw $v.Message
                            }
                            $result.Success = $true
                            break
                        } catch {
                            $retryCount++
                            if ($retryCount -ge $maxRetries) {
                                $result.Error = $_.Exception.Message
                            } else {
                                Start-Sleep -Seconds ([math]::Pow(2, $retryCount))
                            }
                        }
                    }

                    if ($result.Success) {
                        $themeContent = Get-Content -Path $destinationPath -Raw
                        if ($themeContent -match 'background_image:\s*\r?\n\s*path:\s*["'']([^"'']+)["'']') {
                            $bgImageFile = $matches[1]
                            if (-not (Test-PathSafe $bgImageFile)) {
                                # Skip unsafe path silently
                            } else {
                                $result.BackgroundFile = $bgImageFile
                                $bgDest = "$installPath\$bgImageFile"

                                if (Test-Path $bgDest) {
                                    $result.BackgroundStatus = "exists"
                                } else {
                                    $bgUrl2      = "$backgroundsRawUrl/$bgImageFile"
                                    $bgRetry     = 0
                                    while ($bgRetry -lt $maxRetries) {
                                        try {
                                            Invoke-WebRequest -Uri $bgUrl2 -OutFile $bgDest -TimeoutSec $timeout -ErrorAction Stop
                                            $iv = Test-ImageFile $bgDest $maxImageSize
                                            if (-not $iv.Success) {
                                                Remove-Item $bgDest -Force -ErrorAction SilentlyContinue
                                                throw $iv.Message
                                            }
                                            $result.BackgroundStatus = "installed"
                                            break
                                        } catch {
                                            $bgRetry++
                                            if ($bgRetry -ge $maxRetries) {
                                                $result.BackgroundStatus = "failed"
                                            } else {
                                                Start-Sleep -Seconds ([math]::Pow(2, $bgRetry))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    return $result
                } -ThrottleLimit 5

                # Merge parallel results back into tracking hashtables
                foreach ($result in $downloadResults) {
                    $currentOperation++
                    if ($progressBar) {
                        $progressBar.Value = [math]::Min(100, [int](($currentOperation / $totalOperations) * 100))
                    }

                    if ($result.Success) {
                        if (-not $installedThemes.ContainsKey($versionName)) {
                            $installedThemes[$versionName] = @()
                        }
                        $installedThemes[$versionName] += $result.File

                        if ($result.BackgroundStatus) {
                            $themeBackgroundStatus["$versionName::$($result.File)"] = $result.BackgroundStatus
                            if ($result.BackgroundStatus -eq "failed" -and $result.BackgroundFile) {
                                $themeName = Get-FileNameWithoutExtension -FilePath $result.File
                                $missingBackgrounds += @{
                                    ThemeName      = $themeName
                                    Version        = $versionName
                                    BackgroundFile = $result.BackgroundFile
                                }
                            }
                        }
                    } else {
                        $themeName = Get-FileNameWithoutExtension -FilePath $result.File
                        Show-StatusNotification -StatusLabel $statusLabel -Message "Failed to install $themeName`: $($result.Error)" -Type "Error"
                    }
                }

            } else {
                # Sequential processing for PowerShell 5.1 (uses outer-scope helper functions normally)
                foreach ($file in $notInstalledThemes) {
                    $currentOperation++
                    if ($progressBar) {
                        $progressBar.Value = [math]::Min(100, [int](($currentOperation / $totalOperations) * 100))
                    }

                    $themeName = Get-FileNameWithoutExtension -FilePath $file
                    Show-StatusNotification -StatusLabel $statusLabel -Message "Installing $themeName to $versionName..." -Type "Info"

                    $fileUrl         = "$repoRawUrl/$file"
                    $destinationPath = "$installPath\$file"
                    $retryCount      = 0
                    $downloadSuccess = $false
                    $lastError       = $null

                    while ($retryCount -lt $script:UIConstants.MaxRetries) {
                        try {
                            Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -TimeoutSec $script:UIConstants.DefaultTimeout -ErrorAction Stop

                            $validation = Test-DownloadedFile -FilePath $destinationPath -FileType 'yaml'
                            if (-not $validation.Success) {
                                Remove-Item $destinationPath -Force -ErrorAction SilentlyContinue
                                throw [Exception]::new($validation.Message)
                            }

                            $downloadSuccess = $true
                            break
                        } catch {
                            $lastError = $_
                            $retryCount++
                            if ($retryCount -lt $script:UIConstants.MaxRetries) {
                                $waitTime = [math]::Pow(2, $retryCount)
                                Write-Host "Download failed (attempt $retryCount/$($script:UIConstants.MaxRetries)). Retrying in $waitTime seconds..."
                                Start-Sleep -Seconds $waitTime
                            }
                        }
                    }

                    if (-not $downloadSuccess) {
                        Show-StatusNotification -StatusLabel $statusLabel -Message "Failed to download $themeName after $($script:UIConstants.MaxRetries) attempts: $($lastError.Exception.Message)" -Type "Error"
                        continue
                    }

                    if (-not $installedThemes.ContainsKey($versionName)) {
                        $installedThemes[$versionName] = @()
                    }
                    $installedThemes[$versionName] += $file

                    # Background image handling
                    $themeContent = Get-Content -Path $destinationPath -Raw
                    if ($themeContent -match 'background_image:\s*\r?\n\s*path:\s*["'']([^"'']+)["'']') {
                        $bgImageFile = $matches[1]

                        if (-not (Test-SafeFilePath -FilePath $bgImageFile)) {
                            Write-Warning "Skipping unsafe background path for ${themeName}: $bgImageFile"
                            continue
                        }

                        $bgImageDestination = "$installPath\$bgImageFile"

                        if (Test-Path $bgImageDestination) {
                            $themeBackgroundStatus["$versionName::$file"] = "exists"
                        } else {
                            $bgImageUrl      = "$backgroundsRawUrl/$bgImageFile"
                            $bgRetryCount    = 0
                            $bgDownloadSuccess = $false

                            while ($bgRetryCount -lt $script:UIConstants.MaxRetries) {
                                try {
                                    Invoke-WebRequest -Uri $bgImageUrl -OutFile $bgImageDestination -TimeoutSec $script:UIConstants.DefaultTimeout -ErrorAction Stop

                                    $bgValidation = Test-DownloadedFile -FilePath $bgImageDestination -FileType 'image'
                                    if (-not $bgValidation.Success) {
                                        Remove-Item $bgImageDestination -Force -ErrorAction SilentlyContinue
                                        throw $bgValidation.Message
                                    }

                                    $themeBackgroundStatus["$versionName::$file"] = "installed"
                                    $bgDownloadSuccess = $true
                                    break
                                } catch {
                                    $bgRetryCount++
                                    if ($bgRetryCount -lt $script:UIConstants.MaxRetries) {
                                        Start-Sleep -Seconds ([math]::Pow(2, $bgRetryCount))
                                    }
                                }
                            }

                            if (-not $bgDownloadSuccess) {
                                $themeBackgroundStatus["$versionName::$file"] = "failed"
                                $missingBackgrounds += @{
                                    ThemeName      = $themeName
                                    Version        = $versionName
                                    BackgroundFile = $bgImageFile
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    # Tally results
    $totalAlreadyInstalled = 0
    foreach ($version in $alreadyInstalledThemes.Keys) {
        $totalAlreadyInstalled += $alreadyInstalledThemes[$version].Count
    }
    $totalExpected = $themes.Count * $script:selectedPaths.Count

    Show-ModernResultDialog `
        -installedThemes $installedThemes `
        -alreadyInstalledThemes $alreadyInstalledThemes `
        -themeBackgroundStatus $themeBackgroundStatus `
        -isInstallAll $isInstallAll `
        -totalAlreadyInstalled $totalAlreadyInstalled `
        -totalExpected $totalExpected `
        -selectedPaths $script:selectedPaths `
        -missingBackgrounds $missingBackgrounds

    if ($progressBar) { $progressBar.Value = 0 }
    Show-StatusNotification -StatusLabel $statusLabel -Message "Installation completed." -Type "Success"
}

<#
.SYNOPSIS
    Creates the main installer GUI with Windows 11 design language.

.PARAMETER themeFiles
    Array of theme filenames to display in the interface.
#>
function New-CombinedInstallerGUI {
    param ($themeFiles)

    Set-ProcessDPIAware

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Warp Theme Installer"
    $form.Size = New-Object System.Drawing.Size(900, 750)
    $form.MinimumSize = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $script:Win11Colors.Background
    $form.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $form.Padding = New-Object System.Windows.Forms.Padding(24)

    $mainContainer = New-Object System.Windows.Forms.TableLayoutPanel
    $mainContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainContainer.RowCount = 5
    $mainContainer.ColumnCount = 1
    $mainContainer.Padding = New-Object System.Windows.Forms.Padding(0)
    $mainContainer.Margin = New-Object System.Windows.Forms.Padding(0)
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))  | Out-Null
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) | Out-Null
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))  | Out-Null
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) | Out-Null
    $form.Controls.Add($mainContainer)

    # Header
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $headerPanel.BackColor = $script:Win11Colors.Background
    $mainContainer.Controls.Add($headerPanel, 0, 0)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Warp Theme Installer"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $script:Win11Colors.TextPrimary
    $titleLabel.Location = New-Object System.Drawing.Point(0, 12)
    $titleLabel.AutoSize = $true
    $headerPanel.Controls.Add($titleLabel)

    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "Install custom themes for Warp terminal"
    $subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
    $subtitleLabel.ForeColor = $script:Win11Colors.TextSecondary
    $subtitleLabel.Location = New-Object System.Drawing.Point(0, 50)
    $subtitleLabel.AutoSize = $true
    $headerPanel.Controls.Add($subtitleLabel)

    # Version selection card
    $versionCard = New-Object System.Windows.Forms.Panel
    $versionCard.Dock = [System.Windows.Forms.DockStyle]::Fill
    $versionCard.BackColor = $script:Win11Colors.Surface
    $versionCard.Padding = New-Object System.Windows.Forms.Padding(20)
    $versionCard.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 16)
    $mainContainer.Controls.Add($versionCard, 0, 1)

    $versionTitle = New-Object System.Windows.Forms.Label
    $versionTitle.Text = "Select Warp Version"
    $versionTitle.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 14, [System.Drawing.FontStyle]::Bold)
    $versionTitle.ForeColor = $script:Win11Colors.TextPrimary
    $versionTitle.Location = New-Object System.Drawing.Point(0, 0)
    $versionTitle.AutoSize = $true
    $versionCard.Controls.Add($versionTitle)

    $radioContainer = New-Object System.Windows.Forms.FlowLayoutPanel
    $radioContainer.Location = New-Object System.Drawing.Point(0, 35)
    $radioContainer.Size = New-Object System.Drawing.Size(800, 40)
    $radioContainer.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $radioContainer.WrapContents = $false
    $versionCard.Controls.Add($radioContainer)

    $radioWarp = New-Object System.Windows.Forms.RadioButton
    $radioWarp.Text = "Warp"
    $radioWarp.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
    $radioWarp.ForeColor = $script:Win11Colors.TextPrimary
    $radioWarp.AutoSize = $true
    $radioWarp.Checked = $true
    $radioWarp.Margin = New-Object System.Windows.Forms.Padding(0, 0, 40, 0)
    $radioContainer.Controls.Add($radioWarp)

    $radioPreview = New-Object System.Windows.Forms.RadioButton
    $radioPreview.Text = "Warp Preview"
    $radioPreview.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
    $radioPreview.ForeColor = $script:Win11Colors.TextPrimary
    $radioPreview.AutoSize = $true
    $radioPreview.Margin = New-Object System.Windows.Forms.Padding(0, 0, 40, 0)
    $radioContainer.Controls.Add($radioPreview)

    $radioBoth = New-Object System.Windows.Forms.RadioButton
    $radioBoth.Text = "Both Versions"
    $radioBoth.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
    $radioBoth.ForeColor = $script:Win11Colors.TextPrimary
    $radioBoth.AutoSize = $true
    $radioContainer.Controls.Add($radioBoth)

    # Theme section header
    $themeSectionPanel = New-Object System.Windows.Forms.Panel
    $themeSectionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $themeSectionPanel.BackColor = $script:Win11Colors.Background
    $mainContainer.Controls.Add($themeSectionPanel, 0, 2)

    $themeSectionTitle = New-Object System.Windows.Forms.Label
    $themeSectionTitle.Text = "Available Themes"
    $themeSectionTitle.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 14, [System.Drawing.FontStyle]::Bold)
    $themeSectionTitle.ForeColor = $script:Win11Colors.TextPrimary
    $themeSectionTitle.Location = New-Object System.Drawing.Point(0, 15)
    $themeSectionTitle.AutoSize = $true
    $themeSectionPanel.Controls.Add($themeSectionTitle)

    # Theme list
    $themeCard = New-Object System.Windows.Forms.Panel
    $themeCard.Dock = [System.Windows.Forms.DockStyle]::Fill
    $themeCard.BackColor = $script:Win11Colors.Surface
    $themeCard.Padding = New-Object System.Windows.Forms.Padding(20)
    $mainContainer.Controls.Add($themeCard, 0, 3)

    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.MultiColumn = $true
    $checkedListBox.ColumnWidth = $script:UIConstants.CheckedListBoxColumnWidth
    $checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $checkedListBox.ItemHeight = $script:UIConstants.CheckedListBoxItemHeight
    $checkedListBox.BackColor = $script:Win11Colors.Surface
    $checkedListBox.ForeColor = $script:Win11Colors.TextPrimary
    $checkedListBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $checkedListBox.Enabled = $false
    $checkedListBox.IntegralHeight = $false

    $themeFiles | ForEach-Object {
        $displayName = Get-FileNameWithoutExtension -FilePath $_
        $checkedListBox.Items.Add($displayName) | Out-Null
    }
    $themeCard.Controls.Add($checkedListBox)

    # Action and status section
    $actionCard = New-Object System.Windows.Forms.Panel
    $actionCard.Dock = [System.Windows.Forms.DockStyle]::Fill
    $actionCard.BackColor = $script:Win11Colors.Surface
    $actionCard.Padding = New-Object System.Windows.Forms.Padding(20)
    $mainContainer.Controls.Add($actionCard, 0, 4)

    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Location = New-Object System.Drawing.Point(0, 0)
    $buttonPanel.Size = New-Object System.Drawing.Size(800, 44)
    $buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $buttonPanel.WrapContents = $false
    $actionCard.Controls.Add($buttonPanel)

    $installSelectedButton = New-ModernButton -Text "Install Selected" -Width 140
    $installSelectedButton.Enabled = $false
    $installSelectedButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
    $buttonPanel.Controls.Add($installSelectedButton)

    $installAllButton = New-ModernButton -Text "Install All" -Width 140
    $installAllButton.Enabled = $false
    $installAllButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
    $buttonPanel.Controls.Add($installAllButton)

    $selectAllButton = New-ModernButton -Text "Select All" -Width 120 -BackColor $script:Win11Colors.Secondary -ForeColor $script:Win11Colors.TextOnSecondary -HoverColor $script:Win11Colors.SecondaryHover -BorderColor $script:Win11Colors.BorderDark
    $selectAllButton.Enabled = $false
    $selectAllButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
    $buttonPanel.Controls.Add($selectAllButton)

    $exitButton = New-ModernButton -Text "Exit" -Width 100 -BackColor $script:Win11Colors.Secondary -ForeColor $script:Win11Colors.TextOnSecondary -HoverColor $script:Win11Colors.SecondaryHover -BorderColor $script:Win11Colors.BorderDark
    $buttonPanel.Controls.Add($exitButton)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(0, 48)
    $progressBar.Size = New-Object System.Drawing.Size(800, 6)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $progressBar.Visible = $false
    $actionCard.Controls.Add($progressBar)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Ready to install themes. Select themes and click Install Selected or Install All."
    $statusLabel.Location = New-Object System.Drawing.Point(0, 64)
    $statusLabel.Size = New-Object System.Drawing.Size(800, 24)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $statusLabel.ForeColor = $script:Win11Colors.TextSecondary
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $actionCard.Controls.Add($statusLabel)

    # Auto-apply version selection — defined before event handlers that reference it
    $applyVersionSelection = {
        if ($radioWarp.Checked) {
            $script:selectedPaths = @($warpThemePath)
            $versionText = "Warp"
        } elseif ($radioPreview.Checked) {
            $script:selectedPaths = @($warpPreviewThemePath)
            $versionText = "Warp Preview"
        } elseif ($radioBoth.Checked) {
            $script:selectedPaths = @($warpThemePath, $warpPreviewThemePath)
            $versionText = "Both Warp and Warp Preview"
        }
        $checkedListBox.Enabled = $true
        $installSelectedButton.Enabled = $true
        $installAllButton.Enabled = $true
        $selectAllButton.Enabled = $true
        Show-StatusNotification -StatusLabel $statusLabel -Message "Selected: $versionText. Choose themes to install." -Type "Success"
    }

    $radioWarp.Add_CheckedChanged($applyVersionSelection)
    $radioPreview.Add_CheckedChanged($applyVersionSelection)
    $radioBoth.Add_CheckedChanged($applyVersionSelection)

    # Initialize with default selection
    & $applyVersionSelection

    $selectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $true)
        }
        Show-StatusNotification -StatusLabel $statusLabel -Message "All themes selected." -Type "Info"
    })

    $installSelectedButton.Add_Click({
        if ($script:selectedPaths.Count -eq 0) {
            Show-StatusNotification -StatusLabel $statusLabel -Message "Error: No Warp version selected. Please select a version first." -Type "Error"
            return
        }
        $selectedIndices = $checkedListBox.CheckedIndices
        if ($selectedIndices.Count -eq 0) {
            Show-StatusNotification -StatusLabel $statusLabel -Message "Error: No themes selected. Please select at least one theme." -Type "Error"
            return
        }
        $selectedThemes = @()
        foreach ($index in $selectedIndices) { $selectedThemes += $themeFiles[$index] }

        $progressBar.Visible = $true
        $validation = Initialize-DestinationDirectories
        if (-not $validation.Success) {
            Show-StatusNotification -StatusLabel $statusLabel -Message $validation.Message -Type "Error"
            $progressBar.Visible = $false
            return
        }
        Install-Themes -themes $selectedThemes -isInstallAll $false -statusLabel $statusLabel -progressBar $progressBar
        $progressBar.Visible = $false
    })

    $installAllButton.Add_Click({
        if ($script:selectedPaths.Count -eq 0) {
            Show-StatusNotification -StatusLabel $statusLabel -Message "Error: No Warp version selected. Please select a version first." -Type "Error"
            return
        }
        $progressBar.Visible = $true
        $validation = Initialize-DestinationDirectories
        if (-not $validation.Success) {
            Show-StatusNotification -StatusLabel $statusLabel -Message $validation.Message -Type "Error"
            $progressBar.Visible = $false
            return
        }
        Install-Themes -themes $themeFiles -isInstallAll $true -statusLabel $statusLabel -progressBar $progressBar
        $progressBar.Visible = $false
    })

    $exitButton.Add_Click({ $form.Close() })

    $form.ShowDialog()
}

# Main execution
try {
    $themeFiles = Get-ThemeFiles
    New-CombinedInstallerGUI -themeFiles $themeFiles
} catch {
    $errorMsg = "Error: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error")
    exit 1
}
