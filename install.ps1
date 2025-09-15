# Ensure script-scope variables for controls are available everywhere
$script:checkedListBox = $null
$script:statusBar = $null
$script:buttonPanel = $null
$script:installSelectedButton = $null
$script:installAllButton = $null
$script:exitButton = $null
$script:selectAllButton = $null
# Define variables
$repoRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/yaml_files"
$backgroundsRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/backgrounds"
$repoApiUrl = "https://api.github.com/repos/SilentGlasses/warp_themes/contents/yaml_files"
$warpThemePath = "${env:AppData}\warp\Warp\data\themes"
$warpPreviewThemePath = "${env:AppData}\warp\WarpPreview\data\themes"

# To keep track of selected version
$script:selectedPaths = @()

# Ensure the destination directories exist
function Confirm-DestinationDirectoriesExist { # Renamed from Ensure-DestinationDirectories
    foreach ($path in $script:selectedPaths) {
        if (-not (Test-Path $path)) {
            Write-Host "Creating theme directory for $(if ($path.Contains('preview')) { 'Warp Preview' } else { 'Warp' })..."
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

# Get a list of YAML theme files from the repository
function Get-ThemeFiles {
    Write-Host "Fetching list of theme files..."
    try {
        $themeFilesResponse = Invoke-RestMethod -Uri $repoApiUrl
        $themeNames = @()
        foreach ($item in $themeFilesResponse) {
            if ($item.name -match "\.yaml$") {
                $themeNames += $item.name
            }
        }
        return $themeNames
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

# Install Themes Function
function Install-Themes {
    param ($themes, $isInstallAll)
    $installedThemes = @{}
    $alreadyInstalledThemes = @{}
    $themeBackgroundStatus = @{}
    
    foreach ($installPath in $script:selectedPaths) {
        $versionName = if ($installPath -like "*preview*") { "Warp Preview" } else { "Warp" }
        Write-Host "Installing themes for $versionName..."

        # Reset notInstalledThemes for each version
        $notInstalledThemes = @()

        foreach ($file in $themes) {
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
                $themeName = Split-Path $file -LeafBase
                Write-Host "Installing $themeName to $versionName..."
                
                try {
                    $fileUrl = "$repoRawUrl/$file"
                    $destinationPath = "$installPath\$file"
                    Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -ErrorAction Stop # Added -ErrorAction Stop
                    
                    if (-not $installedThemes.ContainsKey($versionName)) {
                        $installedThemes[$versionName] = @()
                    }
                    $installedThemes[$versionName] += $file
                    
                    # Check for background image in the theme file
                    $themeContent = Get-Content -Path $destinationPath -Raw
                    if ($themeContent -match 'background_image:\s*\n\s*path:\s*[''"]([^''"]+)[''"]') {
                        $bgImageFile = $matches[1]
                        $bgImageDestination = "$installPath\$bgImageFile"
                        
                        # Check if background image already exists
                        if (Test-Path $bgImageDestination) {
                            $themeBackgroundStatus["${versionName}::${file}"] = "exists"
                        } else {
                            try {
                                $bgImageUrl = "$backgroundsRawUrl/$bgImageFile"
                                Invoke-WebRequest -Uri $bgImageUrl -OutFile $bgImageDestination -ErrorAction Stop
                                $themeBackgroundStatus["${versionName}::${file}"] = "installed"
                            } catch {
                                $themeBackgroundStatus["${versionName}::${file}"] = "failed"
                                Write-Host "Warning: Could not download background image for $themeName in $versionName - $($_.Exception.Message)"
                            }
                        }
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Error installing $themeName for $versionName - $($_.Exception.Message)", "Error")
                }
            }
        }
    }

    $message = ""
    
    # Check if all themes are already installed in all versions
    $totalAlreadyInstalled = 0
    foreach ($version in $alreadyInstalledThemes.Keys) {
        $totalAlreadyInstalled += $alreadyInstalledThemes[$version].Count
    }
    
    $totalExpected = $themes.Count * $script:selectedPaths.Count 
    
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
                $message += "`n${version}:`n"
                foreach ($theme in $installedThemes[$version]) {
                    $themeName = Split-Path $theme -LeafBase
                    $statusSuffix = ""
                    
                    # Add background image status if applicable
                    if ($themeBackgroundStatus.ContainsKey("${version}::${theme}")) {
                        switch ($themeBackgroundStatus["${version}::${theme}"]) {
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
                $message += "`n${version}:`n"
                foreach ($theme in $alreadyInstalledThemes[$version]) {
                    $themeName = Split-Path $theme -LeafBase
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
    foreach ($path in $script:selectedPaths) {
        $versionName = if ($path -like "*preview*") { "Warp Preview" } else { "Warp" }
        $message += "`n  - ${versionName}: $path"
    }

    [System.Windows.Forms.MessageBox]::Show($message, "Installation Summary")
}

# Create combined GUI for version and theme selection
function New-CombinedInstallerGUI {
    param ($themeFiles)
    [void](Add-Type -AssemblyName System.Windows.Forms)
    [void](Add-Type -AssemblyName System.Drawing)

    # Make the process DPI-aware
    Set-ProcessDPIAware
    
    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Warp Theme Installer"
    $form.Size = New-Object System.Drawing.Size(800, 700)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(243, 243, 243)
    $form.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $form.Padding = New-Object System.Windows.Forms.Padding(20)
    
    # Main TableLayoutPanel to organize sections
    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainLayout.RowCount = 4  # Version section, separator, theme section, status bar
    $mainLayout.ColumnCount = 1
    $mainLayout.Padding = New-Object System.Windows.Forms.Padding(0)
    $mainLayout.Margin = New-Object System.Windows.Forms.Padding(0)
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 75))) 
    $form.Controls.Add($mainLayout)
    
    #
    # TOP SECTION - VERSION SELECTION
    #
    $versionPanel = New-Object System.Windows.Forms.Panel
    $versionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $versionPanel.Padding = New-Object System.Windows.Forms.Padding(0)
    $versionPanel.Margin = New-Object System.Windows.Forms.Padding(0)
    $mainLayout.Controls.Add($versionPanel, 0, 0)

    # Use a vertical FlowLayoutPanel for proper stacking
    $versionFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $versionFlow.Dock = [System.Windows.Forms.DockStyle]::Fill
    $versionFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $versionFlow.WrapContents = $false
    $versionFlow.AutoSize = $true
    $versionPanel.Controls.Add($versionFlow)

    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Select Warp version for theme installation:"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.AutoSize = $true
    $versionFlow.Controls.Add($titleLabel)

    # Top separator
    $topSeparator = New-Object System.Windows.Forms.Label
    $topSeparator.Text = "-----------------------------------------"
    $topSeparator.AutoSize = $true
    $topSeparator.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $versionFlow.Controls.Add($topSeparator)

    # Radio buttons panel (horizontal)
    $radioPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $radioPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $radioPanel.WrapContents = $false
    $radioPanel.AutoSize = $true
    $versionFlow.Controls.Add($radioPanel)

    # Radio buttons
    $radioWarp = New-Object System.Windows.Forms.RadioButton
    $radioWarp.Text = "Install for Warp"
    $radioWarp.AutoSize = $true
    $radioWarp.Checked = $true
    $radioPanel.Controls.Add($radioWarp)

    $radioPreview = New-Object System.Windows.Forms.RadioButton
    $radioPreview.Text = "Install for Warp Preview"
    $radioPreview.AutoSize = $true
    $radioPanel.Controls.Add($radioPreview)

    $radioBoth = New-Object System.Windows.Forms.RadioButton
    $radioBoth.Text = "Install for both versions"
    $radioBoth.AutoSize = $true
    $radioPanel.Controls.Add($radioBoth)

    # Apply version selection
    $applyVersionButton = New-Object System.Windows.Forms.Button
    $applyVersionButton.Text = "Apply Version Selection"
    $applyVersionButton.Width = 200
    $applyVersionButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $applyVersionButton.ForeColor = [System.Drawing.Color]::White
    $applyVersionButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $versionFlow.Controls.Add($applyVersionButton)

    # Select All button - adds convenience for selecting all themes
    $script:selectAllButton = New-Object System.Windows.Forms.Button
    $script:selectAllButton.Text = "Select All Themes"
    $script:selectAllButton.Width = 150
    $script:selectAllButton.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $script:selectAllButton.ForeColor = [System.Drawing.Color]::Black
    $script:selectAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $script:selectAllButton.Enabled = $false
    $script:selectAllButton.Add_Click({
        for ($i = 0; $i -lt $script:checkedListBox.Items.Count; $i++) {
            $script:checkedListBox.SetItemChecked($i, $true)
        }
        $script:statusBar.Text = "All themes selected."
    })
    $versionFlow.Controls.Add($script:selectAllButton)
    
    #
    # MIDDLE SECTION - SEPARATOR
    #
    $separatorPanel = New-Object System.Windows.Forms.Panel
    $separatorPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $separatorPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $mainLayout.Controls.Add($separatorPanel, 0, 1)
    
    $middleLabel = New-Object System.Windows.Forms.Label
    $middleLabel.Text = "Theme Selection"
    $middleLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10, [System.Drawing.FontStyle]::Bold)
    $middleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $middleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $separatorPanel.Controls.Add($middleLabel)
    
    #
    # BOTTOM SECTION - THEME SELECTION
    #
    $themePanel = New-Object System.Windows.Forms.Panel
    $themePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainLayout.Controls.Add($themePanel, 0, 2)
    
    # Initialize the CheckedListBox
    $script:checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $script:checkedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:checkedListBox.CheckOnClick = $true
    $script:checkedListBox.MultiColumn = $true
    $script:checkedListBox.ColumnWidth = 270
    $script:checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $script:checkedListBox.ItemHeight = 30
    $script:checkedListBox.Padding = New-Object System.Windows.Forms.Padding(10)
    $script:checkedListBox.Enabled = $false  # Disabled until version is selected
    foreach ($theme in $themeFiles) {
        [void]$script:checkedListBox.Items.Add($theme)
    }
    $themePanel.Controls.Add($script:checkedListBox)
    
    #
    # BOTTOM SECTION - ACTION BUTTONS AND STATUS
    #
    $actionPanel = New-Object System.Windows.Forms.Panel
    $actionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainLayout.Controls.Add($actionPanel, 0, 3)
    
    # Status bar
    $script:statusBar = New-Object System.Windows.Forms.Label
    $script:statusBar.Text = "Please select a Warp version and apply selection."
    $script:statusBar.Location = New-Object System.Drawing.Point(20, 45)
    $script:statusBar.Size = New-Object System.Drawing.Size(760, 30) 
    $script:statusBar.Font = New-Object System.Drawing.Font("Segoe UI Variable", 9)
    $script:statusBar.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $actionPanel.Controls.Add($script:statusBar)
    
    # Button panel
    $script:buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $script:buttonPanel.Location = New-Object System.Drawing.Point(20, 10)
    $script:buttonPanel.Size = New-Object System.Drawing.Size(760, 35)
    $script:buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $script:buttonPanel.AutoSize = $true
    $script:buttonPanel.WrapContents = $false
    $actionPanel.Controls.Add($script:buttonPanel)
    
    # Install Selected button
    $script:installSelectedButton = New-Object System.Windows.Forms.Button
    $script:installSelectedButton.Text = "Install Selected"
    $script:installSelectedButton.AutoSize = $true
    $script:installSelectedButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $script:installSelectedButton.ForeColor = [System.Drawing.Color]::White
    $script:installSelectedButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $script:installSelectedButton.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $script:installSelectedButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 20, 0)
    $script:installSelectedButton.Width = 150
    $script:installSelectedButton.Enabled = $false
    $script:installSelectedButton.Add_Click({
        if ($script:selectedPaths.Count -eq 0) {
            $script:statusBar.Text = "Error: No Warp version selected. Please select a version first."
            return
        }
        
        $selectedThemes = $script:checkedListBox.CheckedItems
        
        if ($selectedThemes.Count -eq 0) {
            $script:statusBar.Text = "Error: No themes selected. Please select at least one theme."
            return
        }
        
        $script:statusBar.Text = "Installing selected themes..."
        Confirm-DestinationDirectoriesExist # Updated call
        Install-Themes -themes $selectedThemes -isInstallAll $false
        $script:statusBar.Text = "Installation completed."
    })
    $script:buttonPanel.Controls.Add($script:installSelectedButton)
    
    # Install All button
    $script:installAllButton = New-Object System.Windows.Forms.Button
    $script:installAllButton.Text = "Install All"
    $script:installAllButton.AutoSize = $true
    $script:installAllButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $script:installAllButton.ForeColor = [System.Drawing.Color]::White
    $script:installAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $script:installAllButton.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $script:installAllButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 20, 0)
    $script:installAllButton.Width = 150
    $script:installAllButton.Enabled = $false
    $script:installAllButton.Add_Click({
        if ($script:selectedPaths.Count -eq 0) {
            $script:statusBar.Text = "Error: No Warp version selected. Please select a version first."
            return
        }
        
        $script:statusBar.Text = "Installing all themes..."
        Confirm-DestinationDirectoriesExist # Updated call
        Install-Themes -themes $themeFiles -isInstallAll $true
        $script:statusBar.Text = "Installation completed."
    })
    $script:buttonPanel.Controls.Add($script:installAllButton)
    
    # Exit button
    $script:exitButton = New-Object System.Windows.Forms.Button
    $script:exitButton.Text = "Exit"
    $script:exitButton.AutoSize = $true
    $script:exitButton.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $script:exitButton.ForeColor = [System.Drawing.Color]::Black
    $script:exitButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $script:exitButton.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $script:exitButton.Margin = New-Object System.Windows.Forms.Padding(0)
    $script:exitButton.Width = 100
    $script:exitButton.Add_Click({
        $form.Close()
    })
    $script:buttonPanel.Controls.Add($script:exitButton)
    
    # (moved above into $versionFlow)

    # Now that all controls are created, add the event handler for Apply Version Selection
    $applyVersionButton.Add_Click({
        
        if ($radioWarp.Checked) {
            $script:selectedPaths = @($warpThemePath)
            $script:statusBar.Text = "Selected: Warp"
        } elseif ($radioPreview.Checked) {
            $script:selectedPaths = @($warpPreviewThemePath)
            $script:statusBar.Text = "Selected: Warp Preview"
        } else {
            $script:selectedPaths = @($warpThemePath, $warpPreviewThemePath)
            $script:statusBar.Text = "Selected: Both Warp and Warp Preview"
        }

        # Enable theme selection controls
        $script:checkedListBox.Enabled = $true
        $script:installSelectedButton.Enabled = $true
        $script:installAllButton.Enabled = $true
        $script:selectAllButton.Enabled = $true
    })
    
    # Event handler for Apply Version Selection button is defined above
    
    # Show the form
    $null = $form.ShowDialog()
}

# Main execution
try {
    # Get theme files
    $themeFiles = Get-ThemeFiles
    
    # Launch the combined installer
    New-CombinedInstallerGUI -themeFiles $themeFiles
} catch {
    [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Error")
    exit 1
}
