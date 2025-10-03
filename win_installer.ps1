# Warp Theme Installer - Windows 11 Design Enhanced
# PowerShell 5.1 Compatible Version

# Define variables
$repoRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/yaml_files"
$backgroundsRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/backgrounds"
$repoApiUrl = "https://api.github.com/repos/SilentGlasses/warp_themes/contents/yaml_files"
$warpThemePath = "${env:AppData}\warp\Warp\data\themes"
$warpPreviewThemePath = "${env:AppData}\warp-preview\Warp\data\themes"

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
$global:selectedPaths = @()

# PowerShell 5.1 compatible function to get filename without extension
function Get-FileNameWithoutExtension {
    param([string]$FilePath)
    $fileName = Split-Path $FilePath -Leaf
    $lastDot = $fileName.LastIndexOf('.')
    if ($lastDot -gt 0) {
        return $fileName.Substring(0, $lastDot)
    }
    return $fileName
}

# Ensure the destination directories exist
function Ensure-DestinationDirectories {
    foreach ($path in $global:selectedPaths) {
        if (-not (Test-Path $path)) {
            $versionName = if ($path.Contains('preview')) { 'Warp Preview' } else { 'Warp' }
            Write-Host "Creating theme directory for $versionName..."
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

# Get a list of YAML theme files from the repository
function Get-ThemeFiles {
    Write-Host "Fetching list of theme files..."
    try {
        $themeFilesResponse = Invoke-RestMethod -Uri $repoApiUrl
        return $themeFilesResponse | Where-Object { $_.name -match "\.yaml$" } | ForEach-Object { $_.name }
    } catch {
        Write-Host "Error fetching theme files: $($_)"
        exit 1
    }
}

# Function to make the process DPI-aware
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

# Create a modern Windows 11 style button
function New-ModernButton {
    param(
        [string]$Text,
        [System.Drawing.Color]$BackColor = $script:Win11Colors.Primary,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::White,
        [System.Drawing.Color]$HoverColor = $script:Win11Colors.PrimaryHover,
        [System.Drawing.Color]$BorderColor = $script:Win11Colors.Border,
        [int]$Width = 120,
        [int]$Height = 36
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
    
    # Store original colors for hover effect
    $button.Tag = @{
        OriginalBackColor = $BackColor
        HoverColor = $HoverColor
    }
    
    # Add hover effects
    $button.Add_MouseEnter({
        $this.BackColor = $this.Tag.HoverColor
    })
    $button.Add_MouseLeave({
        $this.BackColor = $this.Tag.OriginalBackColor
    })
    
    return $button
}

# Show notification in status area instead of popup
function Show-StatusNotification {
    param(
        [System.Windows.Forms.Label]$StatusLabel,
        [string]$Message,
        [string]$Type = "Info" # Info, Success, Warning, Error
    )
    
    $color = switch ($Type) {
        "Success" { $script:Win11Colors.Success }
        "Warning" { $script:Win11Colors.Warning }
        "Error" { $script:Win11Colors.Error }
        default { $script:Win11Colors.TextPrimary }
    }
    
    $StatusLabel.Text = $Message
    $StatusLabel.ForeColor = $color
}

# Create a beautiful modern result dialog
function Show-ModernResultDialog {
    param(
        [hashtable]$installedThemes,
        [hashtable]$alreadyInstalledThemes,
        [hashtable]$themeBackgroundStatus,
        [bool]$isInstallAll,
        [int]$totalAlreadyInstalled,
        [int]$totalExpected,
        [array]$selectedPaths
    )
    
    # Create the form
    $resultForm = New-Object System.Windows.Forms.Form
    $resultForm.Text = "Installation Complete"
    $resultForm.Size = New-Object System.Drawing.Size(700, 600)
    $resultForm.MinimumSize = New-Object System.Drawing.Size(600, 400)
    $resultForm.StartPosition = "CenterParent"
    $resultForm.BackColor = $script:Win11Colors.Background
    $resultForm.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $resultForm.Padding = New-Object System.Windows.Forms.Padding(24)
    
    # Main container
    $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainPanel.RowCount = 3
    $mainPanel.ColumnCount = 1
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70))) | Out-Null
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 60))) | Out-Null
    $resultForm.Controls.Add($mainPanel)
    
    # Header section
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $headerPanel.BackColor = $script:Win11Colors.Background
    $mainPanel.Controls.Add($headerPanel, 0, 0)
    
    # Single clean title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Theme Installation Summary"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $script:Win11Colors.TextPrimary
    $titleLabel.Location = New-Object System.Drawing.Point(0, 20)
    $titleLabel.AutoSize = $true
    $headerPanel.Controls.Add($titleLabel)
    
    # Calculate installed count for content logic
    $installedCount = 0
    foreach ($version in $installedThemes.Keys) {
        $installedCount += $installedThemes[$version].Count
    }
    
    # Content area with scroll
    $scrollPanel = New-Object System.Windows.Forms.Panel
    $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.BackColor = $script:Win11Colors.Surface
    $scrollPanel.AutoScroll = $true
    $scrollPanel.Padding = New-Object System.Windows.Forms.Padding(24)
    $mainPanel.Controls.Add($scrollPanel, 0, 1)
    
    # Content container
    $contentPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $contentPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $contentPanel.WrapContents = $false
    $contentPanel.AutoSize = $true
    $contentPanel.Width = 600
    $scrollPanel.Controls.Add($contentPanel)
    
    $yPosition = 0
    
    # Show newly installed themes
    if ($installedCount -gt 0) {
        $sectionLabel = New-Object System.Windows.Forms.Label
        $sectionLabel.Text = "NEWLY INSTALLED THEMES"
        $sectionLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 12, [System.Drawing.FontStyle]::Bold)
        $sectionLabel.ForeColor = $script:Win11Colors.Success
        $sectionLabel.AutoSize = $true
        $sectionLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
        $contentPanel.Controls.Add($sectionLabel)
        
        foreach ($version in $installedThemes.Keys) {
            # Version header
            $versionLabel = New-Object System.Windows.Forms.Label
            $versionLabel.Text = "${version}:"
            $versionLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10, [System.Drawing.FontStyle]::Bold)
            $versionLabel.ForeColor = $script:Win11Colors.Primary
            $versionLabel.AutoSize = $true
            $versionLabel.Margin = New-Object System.Windows.Forms.Padding(20, 8, 0, 4)
            $contentPanel.Controls.Add($versionLabel)
            
            # Theme list for this version
            foreach ($theme in $installedThemes[$version]) {
                $themeName = Get-FileNameWithoutExtension -FilePath $theme
                $themePanel = New-Object System.Windows.Forms.Panel
                $themePanel.Height = 24
                $themePanel.Width = 560
                $themePanel.Margin = New-Object System.Windows.Forms.Padding(40, 1, 0, 1)
                
                $themeLabel = New-Object System.Windows.Forms.Label
                $themeLabel.Text = "- $themeName"
                $themeLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
                $themeLabel.ForeColor = $script:Win11Colors.TextPrimary
                $themeLabel.AutoSize = $true
                $themeLabel.Location = New-Object System.Drawing.Point(0, 2)
                $themePanel.Controls.Add($themeLabel)
                
                # Background image status
                if ($themeBackgroundStatus.ContainsKey("$version::$theme")) {
                    $statusLabel = New-Object System.Windows.Forms.Label
                    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 8)
                    $statusLabel.AutoSize = $true
                    $statusLabel.Location = New-Object System.Drawing.Point(300, 4)
                    
                    switch ($themeBackgroundStatus["$version::$theme"]) {
                        "installed" { 
                            $statusLabel.Text = "(with background image)"
                            $statusLabel.ForeColor = $script:Win11Colors.Success
                        }
                        "exists" { 
                            $statusLabel.Text = "(background already exists)"
                            $statusLabel.ForeColor = $script:Win11Colors.TextSecondary
                        }
                        "failed" { 
                            $statusLabel.Text = "(no background image)"
                            $statusLabel.ForeColor = $script:Win11Colors.Warning
                        }
                    }
                    $themePanel.Controls.Add($statusLabel)
                }
                
                $contentPanel.Controls.Add($themePanel)
            }
        }
    }
    
    # Show already installed themes
    if ($totalAlreadyInstalled -gt 0) {
        if ($installedCount -gt 0) {
            $spacer = New-Object System.Windows.Forms.Label
            $spacer.Height = 20
            $spacer.Width = 600
            $contentPanel.Controls.Add($spacer)
        }
        
        $sectionLabel = New-Object System.Windows.Forms.Label
        $sectionLabel.Text = "ALREADY INSTALLED THEMES"
        $sectionLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 12, [System.Drawing.FontStyle]::Bold)
        $sectionLabel.ForeColor = $script:Win11Colors.TextSecondary
        $sectionLabel.AutoSize = $true
        $sectionLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
        $contentPanel.Controls.Add($sectionLabel)
        
        foreach ($version in $alreadyInstalledThemes.Keys) {
            $versionLabel = New-Object System.Windows.Forms.Label
            $versionLabel.Text = "${version}:"
            $versionLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10, [System.Drawing.FontStyle]::Bold)
            $versionLabel.ForeColor = $script:Win11Colors.Primary
            $versionLabel.AutoSize = $true
            $versionLabel.Margin = New-Object System.Windows.Forms.Padding(20, 8, 0, 4)
            $contentPanel.Controls.Add($versionLabel)
            
            foreach ($theme in $alreadyInstalledThemes[$version]) {
                $themeName = Get-FileNameWithoutExtension -FilePath $theme
                $themeLabel = New-Object System.Windows.Forms.Label
                $themeLabel.Text = "- $themeName"
                $themeLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
                $themeLabel.ForeColor = $script:Win11Colors.TextSecondary
                $themeLabel.AutoSize = $true
                $themeLabel.Margin = New-Object System.Windows.Forms.Padding(40, 1, 0, 1)
                $contentPanel.Controls.Add($themeLabel)
            }
        }
    }
    
    # Installation paths section
    $spacer = New-Object System.Windows.Forms.Label
    $spacer.Height = 20
    $spacer.Width = 600
    $contentPanel.Controls.Add($spacer)
    
    $pathsLabel = New-Object System.Windows.Forms.Label
    $pathsLabel.Text = "INSTALLATION PATHS"
    $pathsLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Display", 12, [System.Drawing.FontStyle]::Bold)
    $pathsLabel.ForeColor = $script:Win11Colors.TextPrimary
    $pathsLabel.AutoSize = $true
    $pathsLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
    $contentPanel.Controls.Add($pathsLabel)
    
    foreach ($path in $selectedPaths) {
        $versionName = if ($path -like "*preview*") { "Warp Preview" } else { "Warp" }
        $pathLabel = New-Object System.Windows.Forms.Label
        $pathLabel.Text = "- $versionName`: $path"
        $pathLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 8)
        $pathLabel.ForeColor = $script:Win11Colors.TextSecondary
        $pathLabel.AutoSize = $true
        $pathLabel.Margin = New-Object System.Windows.Forms.Padding(20, 1, 0, 1)
        $contentPanel.Controls.Add($pathLabel)
    }
    
    # Instructions
    if ($installedCount -gt 0) {
        $spacer = New-Object System.Windows.Forms.Label
        $spacer.Height = 16
        $spacer.Width = 600
        $contentPanel.Controls.Add($spacer)
        
        $instructionLabel = New-Object System.Windows.Forms.Label
        $instructionLabel.Text = "TIP: To use your new themes, restart Warp and select them from Settings > Appearance > Themes"
        $instructionLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9, [System.Drawing.FontStyle]::Italic)
        $instructionLabel.ForeColor = $script:Win11Colors.Primary
        $instructionLabel.AutoSize = $true
        $instructionLabel.MaximumSize = New-Object System.Drawing.Size(560, 0)
        $instructionLabel.Margin = New-Object System.Windows.Forms.Padding(20, 8, 0, 0)
        $contentPanel.Controls.Add($instructionLabel)
    }
    
    # Button area
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttonPanel.BackColor = $script:Win11Colors.Background
    $mainPanel.Controls.Add($buttonPanel, 0, 2)
    
    $okButton = New-ModernButton -Text "OK" -Width 120 -Height 36
    # Center the button horizontally: (652 - 120) / 2 = 266
    $okButton.Location = New-Object System.Drawing.Point(266, 12)
    $okButton.Add_Click({ $resultForm.Close() })
    $buttonPanel.Controls.Add($okButton)
    
    $resultForm.ShowDialog() | Out-Null
}

# Install Themes Function with improved progress reporting
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
    $totalOperations = $themes.Count * $global:selectedPaths.Count
    $currentOperation = 0
    
    foreach ($installPath in $global:selectedPaths) {
        $versionName = if ($installPath -like "*preview*") { "Warp Preview" } else { "Warp" }
        Show-StatusNotification -StatusLabel $statusLabel -Message "Installing themes for $versionName..." -Type "Info"

        # Reset notInstalledThemes for each version
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
            foreach ($file in $notInstalledThemes) {
                $themeName = Get-FileNameWithoutExtension -FilePath $file
                Show-StatusNotification -StatusLabel $statusLabel -Message "Installing $themeName to $versionName..." -Type "Info"
                
                try {
                    $fileUrl = "$repoRawUrl/$file"
                    $destinationPath = "$installPath\$file"
                    Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
                    
                    if (-not $installedThemes.ContainsKey($versionName)) {
                        $installedThemes[$versionName] = @()
                    }
                    $installedThemes[$versionName] += $file
                    
                    # Check for background image in the theme file
                    $themeContent = Get-Content -Path $destinationPath -Raw
                    if ($themeContent -match 'background_image:\s*\n\s*path:\s*["'']([^"'']+)["'']') {
                        $bgImageFile = $matches[1]
                        $bgImageDestination = "$installPath\$bgImageFile"
                        
                        # Check if background image already exists
                        if (Test-Path $bgImageDestination) {
                            $themeBackgroundStatus["$versionName::$file"] = "exists"
                        } else {
                            try {
                                $bgImageUrl = "$backgroundsRawUrl/$bgImageFile"
                                Invoke-WebRequest -Uri $bgImageUrl -OutFile $bgImageDestination -ErrorAction Stop
                                $themeBackgroundStatus["$versionName::$file"] = "installed"
                            } catch {
                                $themeBackgroundStatus["$versionName::$file"] = "failed"
                                Write-Host "Warning: Could not download background image for $themeName in $versionName`: $($_.Exception.Message)"
                            }
                        }
                    }
                } catch {
                    Show-StatusNotification -StatusLabel $statusLabel -Message "Error installing $themeName for $versionName`: $($_.Exception.Message)" -Type "Error"
                }
            }
        }
    }

    # Build result message
    $message = ""
    
    # Check if all themes are already installed in all versions
    $totalAlreadyInstalled = 0
    foreach ($version in $alreadyInstalledThemes.Keys) {
        $totalAlreadyInstalled += $alreadyInstalledThemes[$version].Count
    }
    
    $totalExpected = $themes.Count * $global:selectedPaths.Count
    
    if ($isInstallAll -and $totalAlreadyInstalled -eq $totalExpected) {
        $message = "All themes are already installed in selected version(s)!"
    } else {
        # Add installed themes to message
        $installedCount = 0
        foreach ($version in $installedThemes.Keys) {
            $installedCount += $installedThemes[$version].Count
        }
        
        if ($installedCount -gt 0) {
            $message += "The following themes have been installed successfully:`n"
            
            foreach ($version in $installedThemes.Keys) {
                $message += "`n$version`:`n"
                foreach ($theme in $installedThemes[$version]) {
                    $themeName = Get-FileNameWithoutExtension -FilePath $theme
                    $statusSuffix = ""
                    
                    # Add background image status if applicable
                    if ($themeBackgroundStatus.ContainsKey("$version::$theme")) {
                        switch ($themeBackgroundStatus["$version::$theme"]) {
                            "installed" { $statusSuffix = " (with background image)" }
                            "exists" { $statusSuffix = " (background image already exists)" }
                            "failed" { $statusSuffix = " (background image not found)" }
                        }
                    }
                    
                    $message += "  - $themeName$statusSuffix`n"
                }
            }
            
            $message += "`nTo use them, restart Warp and select them from settings."
        }
        
        # Add already installed themes to message
        if ($totalAlreadyInstalled -gt 0) {
            if ($message -ne "") { $message += "`n`n" }
            $message += "The following themes were already installed:`n"
            
            foreach ($version in $alreadyInstalledThemes.Keys) {
                $message += "`n$version`:`n"
                foreach ($theme in $alreadyInstalledThemes[$version]) {
                    $themeName = Get-FileNameWithoutExtension -FilePath $theme
                    $message += "  - $themeName`n"
                }
            }
        }
        
        if ($installedCount -eq 0 -and $totalAlreadyInstalled -eq 0) {
            $message = "No new themes were installed."
        }
    }
    
    # Add installation paths
    $message += "`n`nInstallation paths:"
    foreach ($path in $global:selectedPaths) {
        $versionName = if ($path -like "*preview*") { "Warp Preview" } else { "Warp" }
        $message += "`n  - $versionName`: $path"
    }

    # Create a beautiful modern result dialog
    Show-ModernResultDialog -installedThemes $installedThemes -alreadyInstalledThemes $alreadyInstalledThemes -themeBackgroundStatus $themeBackgroundStatus -isInstallAll $isInstallAll -totalAlreadyInstalled $totalAlreadyInstalled -totalExpected $totalExpected -selectedPaths $global:selectedPaths
    
    if ($progressBar) {
        $progressBar.Value = 0
    }
    Show-StatusNotification -StatusLabel $statusLabel -Message "Installation completed." -Type "Success"
}

# Create combined GUI with Windows 11 design language
function New-CombinedInstallerGUI {
    param ($themeFiles)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Make the process DPI-aware
    Set-ProcessDPIAware
    
    # Create the main form with Windows 11 styling
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Warp Theme Installer"
    $form.Size = New-Object System.Drawing.Size(900, 750)
    $form.MinimumSize = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $script:Win11Colors.Background
    $form.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $form.Padding = New-Object System.Windows.Forms.Padding(24)
    
    # Main container with proper spacing
    $mainContainer = New-Object System.Windows.Forms.TableLayoutPanel
    $mainContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainContainer.RowCount = 5
    $mainContainer.ColumnCount = 1
    $mainContainer.Padding = New-Object System.Windows.Forms.Padding(0)
    $mainContainer.Margin = New-Object System.Windows.Forms.Padding(0)
    
    # Define row styles with Windows 11 spacing
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80))) | Out-Null  # Header
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) | Out-Null # Version selection
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50))) | Out-Null  # Theme section header
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null  # Theme list
    $mainContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) | Out-Null # Actions and status
    $form.Controls.Add($mainContainer)
    
    #
    # HEADER SECTION
    #
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
    
    #
    # VERSION SELECTION SECTION
    #
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
    
    # Radio button container
    $radioContainer = New-Object System.Windows.Forms.FlowLayoutPanel
    $radioContainer.Location = New-Object System.Drawing.Point(0, 35)
    $radioContainer.Size = New-Object System.Drawing.Size(800, 40)
    $radioContainer.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $radioContainer.WrapContents = $false
    $versionCard.Controls.Add($radioContainer)
    
    # Modern radio buttons with auto-selection
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
    
    # Auto-apply version selection function (MUST BE DEFINED BEFORE EVENT HANDLERS)
    $applyVersionSelection = {
        if ($radioWarp.Checked) {
            $global:selectedPaths = @($warpThemePath)
            $versionText = "Warp"
        } elseif ($radioPreview.Checked) {
            $global:selectedPaths = @($warpPreviewThemePath)
            $versionText = "Warp Preview"
        } elseif ($radioBoth.Checked) {
            $global:selectedPaths = @($warpThemePath, $warpPreviewThemePath)
            $versionText = "Both Warp and Warp Preview"
        }
        
        # Enable controls
        $checkedListBox.Enabled = $true
        $installSelectedButton.Enabled = $true
        $installAllButton.Enabled = $true
        $selectAllButton.Enabled = $true
        
        Show-StatusNotification -StatusLabel $statusLabel -Message "Selected: $versionText. Choose themes to install." -Type "Success"
    }
    
    # Add event handlers for automatic selection (AFTER FUNCTION IS DEFINED)
    $radioWarp.Add_CheckedChanged($applyVersionSelection)
    $radioPreview.Add_CheckedChanged($applyVersionSelection)
    $radioBoth.Add_CheckedChanged($applyVersionSelection)
    
    #
    # THEME SECTION HEADER
    #
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
    
    #
    # THEME SELECTION AREA
    #
    $themeCard = New-Object System.Windows.Forms.Panel
    $themeCard.Dock = [System.Windows.Forms.DockStyle]::Fill
    $themeCard.BackColor = $script:Win11Colors.Surface
    $themeCard.Padding = New-Object System.Windows.Forms.Padding(20)
    $mainContainer.Controls.Add($themeCard, 0, 3)
    
    # Theme list with modern styling
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.MultiColumn = $true
    $checkedListBox.ColumnWidth = 280
    $checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $checkedListBox.ItemHeight = 32
    $checkedListBox.BackColor = $script:Win11Colors.Surface
    $checkedListBox.ForeColor = $script:Win11Colors.TextPrimary
    $checkedListBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $checkedListBox.Enabled = $false
    $checkedListBox.IntegralHeight = $false
    
    # Add themes to the list
    $themeFiles | ForEach-Object { 
        $displayName = Get-FileNameWithoutExtension -FilePath $_
        $checkedListBox.Items.Add($displayName) | Out-Null
    }
    $themeCard.Controls.Add($checkedListBox)
    
    #
    # ACTION AND STATUS SECTION
    #
    $actionCard = New-Object System.Windows.Forms.Panel
    $actionCard.Dock = [System.Windows.Forms.DockStyle]::Fill
    $actionCard.BackColor = $script:Win11Colors.Surface
    $actionCard.Padding = New-Object System.Windows.Forms.Padding(20)
    $mainContainer.Controls.Add($actionCard, 0, 4)
    
    # Button panel
    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Location = New-Object System.Drawing.Point(0, 0)
    $buttonPanel.Size = New-Object System.Drawing.Size(800, 44)
    $buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $buttonPanel.WrapContents = $false
    $actionCard.Controls.Add($buttonPanel)
    
    # Modern action buttons
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
    
    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(0, 48)
    $progressBar.Size = New-Object System.Drawing.Size(800, 6)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $progressBar.Visible = $false
    $actionCard.Controls.Add($progressBar)
    
    # Status label
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Ready to install themes. Select themes and click Install Selected or Install All."
    $statusLabel.Location = New-Object System.Drawing.Point(0, 64)
    $statusLabel.Size = New-Object System.Drawing.Size(800, 24)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
    $statusLabel.ForeColor = $script:Win11Colors.TextSecondary
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $actionCard.Controls.Add($statusLabel)
    
    #
    # EVENT HANDLERS AND INITIALIZATION
    #
    
    # Initialize with default selection (Warp is already checked)
    & $applyVersionSelection
    
    # Select all themes
    $selectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $true)
        }
        Show-StatusNotification -StatusLabel $statusLabel -Message "All themes selected." -Type "Info"
    })
    
    # Install selected themes
    $installSelectedButton.Add_Click({
        if ($global:selectedPaths.Count -eq 0) {
            Show-StatusNotification -StatusLabel $statusLabel -Message "Error: No Warp version selected. Please select a version first." -Type "Error"
            return
        }
        
        $selectedIndices = $checkedListBox.CheckedIndices
        if ($selectedIndices.Count -eq 0) {
            Show-StatusNotification -StatusLabel $statusLabel -Message "Error: No themes selected. Please select at least one theme." -Type "Error"
            return
        }
        
        $selectedThemes = @()
        foreach ($index in $selectedIndices) {
            $selectedThemes += $themeFiles[$index]
        }
        
        $progressBar.Visible = $true
        Ensure-DestinationDirectories
        Install-Themes -themes $selectedThemes -isInstallAll $false -statusLabel $statusLabel -progressBar $progressBar
        $progressBar.Visible = $false
    })
    
    # Install all themes
    $installAllButton.Add_Click({
        if ($global:selectedPaths.Count -eq 0) {
            Show-StatusNotification -StatusLabel $statusLabel -Message "Error: No Warp version selected. Please select a version first." -Type "Error"
            return
        }
        
        $progressBar.Visible = $true
        Ensure-DestinationDirectories
        Install-Themes -themes $themeFiles -isInstallAll $true -statusLabel $statusLabel -progressBar $progressBar
        $progressBar.Visible = $false
    })
    
    # Exit
    $exitButton.Add_Click({
        $form.Close()
    })
    
    # Show the form
    $form.ShowDialog()
}

# Main execution
try {
    # Get theme files
    $themeFiles = Get-ThemeFiles
    
    # Launch the installer
    New-CombinedInstallerGUI -themeFiles $themeFiles
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Error")
    exit 1
}