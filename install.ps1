# Define variables
$repoRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/yaml_files"
$backgroundsRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/backgrounds"
$repoApiUrl = "https://api.github.com/repos/SilentGlasses/warp_themes/contents/yaml_files"
$warpThemePath = "${env:AppData}\warp\Warp\data\themes"
$warpPreviewThemePath = "${env:AppData}\warp-preview\Warp\data\themes"

# To keep track of selected version
$global:selectedPaths = @()

# Ensure the destination directories exist
function Ensure-DestinationDirectories {
    foreach ($path in $global:selectedPaths) {
        if (-not (Test-Path $path)) {
            Write-Host "Creating theme directory for $($path.Contains('preview') ? 'Warp Preview' : 'Warp')..."
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

# Install Themes Function
function Install-Themes {
    param ($themes, $isInstallAll)
    $installedThemes = @{}
    $alreadyInstalledThemes = @{}
    $themeBackgroundStatus = @{}
    
    foreach ($installPath in $global:selectedPaths) {
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
                    Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
                    
                    if (-not $installedThemes.ContainsKey($versionName)) {
                        $installedThemes[$versionName] = @()
                    }
                    $installedThemes[$versionName] += $file
                    
                    # Check for background image in the theme file
                    $themeContent = Get-Content -Path $destinationPath -Raw
                    if ($themeContent -match "background_image:\s*\n\s*path:\s*['\"]([^'\"]+)['\"]") {
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
                                Write-Host "Warning: Could not download background image for $themeName in $versionName: $($_.Exception.Message)"
                            }
                        }
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Error installing $themeName for $versionName: $(${($_.Exception.Message)})", "Error")
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
                $message += "`n$version:`n"
                foreach ($theme in $installedThemes[$version]) {
                    $themeName = Split-Path $theme -LeafBase
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
                $message += "`n$version:`n"
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
    foreach ($path in $global:selectedPaths) {
        $versionName = if ($path -like "*preview*") { "Warp Preview" } else { "Warp" }
        $message += "`n  - $versionName: $path"
    }

    [System.Windows.Forms.MessageBox]::Show($message, "Installation Summary")
}

# Create combined GUI for version and theme selection
function New-CombinedInstallerGUI {
    param ($themeFiles)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

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
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))
    $form.Controls.Add($mainLayout)
    
    #
    # TOP SECTION - VERSION SELECTION
    #
    $versionPanel = New-Object System.Windows.Forms.Panel
    $versionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $versionPanel.Padding = New-Object System.Windows.Forms.Padding(0)
    $versionPanel.Margin = New-Object System.Windows.Forms.Padding(0)
    $mainLayout.Controls.Add($versionPanel, 0, 0)
    
    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Select Warp version for theme installation:"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.AutoSize = $true
    $versionPanel.Controls.Add($titleLabel)
    
    # Top separator
    $topSeparator = New-Object System.Windows.Forms.Label
    $topSeparator.Text = "-----------------------------------------"
    $topSeparator.Location = New-Object System.Drawing.Point(20, 50)
    $topSeparator.AutoSize = $true
    $topSeparator.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $versionPanel.Controls.Add($topSeparator)
    
    # Radio buttons panel
    $radioPanel = New-Object System.Windows.Forms.Panel
    $radioPanel.Location = New-Object System.Drawing.Point(20, 80)
    $radioPanel.Size = New-Object System.Drawing.Size(760, 70)
    $versionPanel.Controls.Add($radioPanel)
    
    # Radio buttons
    $radioWarp = New-Object System.Windows.Forms.RadioButton
    $radioWarp.Text = "Install for Warp"
    $radioWarp.Location = New-Object System.Drawing.Point(10, 10)
    $radioWarp.AutoSize = $true
    $radioWarp.Checked = $true
    $radioPanel.Controls.Add($radioWarp)
    
    $radioPreview = New-Object System.Windows.Forms.RadioButton
    $radioPreview.Text = "Install for Warp Preview"
    $radioPreview.Location = New-Object System.Drawing.Point(200, 10)
    $radioPreview.AutoSize = $true
    $radioPanel.Controls.Add($radioPreview)
    
    $radioBoth = New-Object System.Windows.Forms.RadioButton
    $radioBoth.Text = "Install for both versions"
    $radioBoth.Location = New-Object System.Drawing.Point(450, 10)
    $radioBoth.AutoSize = $true
    $radioPanel.Controls.Add($radioBoth)
    
    # Apply version selection
    $applyVersionButton = New-Object System.Windows.Forms.Button
    $applyVersionButton.Text = "Apply Version Selection"
    $applyVersionButton.Location = New-Object System.Drawing.Point(20, 150)
    $applyVersionButton.Width = 200
    $applyVersionButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $applyVersionButton.ForeColor = [System.Drawing.Color]::White
    $applyVersionButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $applyVersionButton.Add_Click({
        if ($radioWarp.Checked) {
            $global:selectedPaths = @($warpThemePath)
            $statusBar.Text = "Selected: Warp"
        } elseif ($radioPreview.Checked) {
            $global:selectedPaths = @($warpPreviewThemePath)
            $statusBar.Text = "Selected: Warp Preview"
        } else {
            $global:selectedPaths = @($warpThemePath, $warpPreviewThemePath)
            $statusBar.Text = "Selected: Both Warp and Warp Preview"
        }
        
        # Enable theme selection controls
        $checkedListBox.Enabled = $true
        $installSelectedButton.Enabled = $true
        $installAllButton.Enabled = $true
    })
    $versionPanel.Controls.Add($applyVersionButton)
    
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
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.MultiColumn = $true
    $checkedListBox.ColumnWidth = 270
    $checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $checkedListBox.ItemHeight = 30
    $checkedListBox.Padding = New-Object System.Windows.Forms.Padding(10)
    $checkedListBox.Enabled = $false  # Disabled until version is selected
    $themeFiles | ForEach-Object { $checkedListBox.Items.Add($_) }
    $themePanel.Controls.Add($checkedListBox)
    
    #
    # BOTTOM SECTION - ACTION BUTTONS AND STATUS
    #
    $actionPanel = New-Object System.Windows.Forms.Panel
    $actionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainLayout.Controls.Add($actionPanel, 0, 3)
    
    # Status bar
    $statusBar = New-Object System.Windows.Forms.Label
    $statusBar.Text = "Please select a Warp version and apply selection."
    $statusBar.Location = New-Object System.Drawing.Point(20, 45)
    $statusBar.Size = New-Object System.Drawing.Size(760, 25)
    $statusBar.Font = New-Object System.Drawing.Font("Segoe UI Variable", 9)
    $statusBar.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $actionPanel.Controls.Add($statusBar)
    
    # Button panel
    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Location = New-Object System.Drawing.Point(20, 10)
    $buttonPanel.Size = New-Object System.Drawing.Size(760, 35)
    $buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $buttonPanel.AutoSize = $true
    $buttonPanel.WrapContents = $false
    $actionPanel.Controls.Add($buttonPanel)
    
    # Install Selected button
    $installSelectedButton = New-Object System.Windows.Forms.Button
    $installSelectedButton.Text = "Install Selected"
    $installSelectedButton.AutoSize = $true
    $installSelectedButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $installSelectedButton.ForeColor = [System.Drawing.Color]::White
    $installSelectedButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $installSelectedButton.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $installSelectedButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 20, 0)
    $installSelectedButton.Width = 150
    $installSelectedButton.Enabled = $false
    $installSelectedButton.Add_Click({
        if ($global:selectedPaths.Count -eq 0) {
            $statusBar.Text = "Error: No Warp version selected. Please select a version first."
            return
        }
        
        $selectedThemes = $checkedListBox.CheckedItems
        
        if ($selectedThemes.Count -eq 0) {
            $statusBar.Text = "Error: No themes selected. Please select at least one theme."
            return
        }
        
        $statusBar.Text = "Installing selected themes..."
        Ensure-DestinationDirectories
        Install-Themes -themes $selectedThemes -isInstallAll $false
        $statusBar.Text = "Installation completed."
    })
    $buttonPanel.Controls.Add($installSelectedButton)
    
    # Install All button
    $installAllButton = New-Object System.Windows.Forms.Button
    $installAllButton.Text = "Install All"
    $installAllButton.AutoSize = $true
    $installAllButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $installAllButton.ForeColor = [System.Drawing.Color]::White
    $installAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $installAllButton.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $installAllButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 20, 0)
    $installAllButton.Width = 150
    $installAllButton.Enabled = $false
    $installAllButton.Add_Click({
        if ($global:selectedPaths.Count -eq 0) {
            $statusBar.Text = "Error: No Warp version selected. Please select a version first."
            return
        }
        
        $statusBar.Text = "Installing all themes..."
        Ensure-DestinationDirectories
        Install-Themes -themes $themeFiles -isInstallAll $true
        $statusBar.Text = "Installation completed."
    })
    $buttonPanel.Controls.Add($installAllButton)
    
    # Exit button
    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Text = "Exit"
    $exitButton.AutoSize = $true
    $exitButton.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $exitButton.ForeColor = [System.Drawing.Color]::Black
    $exitButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $exitButton.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
    $exitButton.Margin = New-Object System.Windows.Forms.Padding(0)
    $exitButton.Width = 100
    $exitButton.Add_Click({
        $form.Close()
    })
    $buttonPanel.Controls.Add($exitButton)
    
    # Select All button - adds convenience for selecting all themes
    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Text = "Select All Themes"
    $selectAllButton.Location = New-Object System.Drawing.Point(650, 150)
    $selectAllButton.Width = 150
    $selectAllButton.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $selectAllButton.ForeColor = [System.Drawing.Color]::Black
    $selectAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $selectAllButton.Enabled = $false
    $selectAllButton.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $true)
        }
        $statusBar.Text = "All themes selected."
    })
    $versionPanel.Controls.Add($selectAllButton)
    
    # When apply version is clicked, also enable the select all button
    $applyVersionButton.Add_Click.Add({
        $selectAllButton.Enabled = $true
    })
    
    # Show the form
    $form.ShowDialog()
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
