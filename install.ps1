# Define variables
$repoRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/yaml_files"
$repoApiUrl = "https://api.github.com/repos/SilentGlasses/warp_themes/contents/yaml_files"
$warpThemePath = "${env:AppData}\warp\Warp\data\themes"

# Ensure the destination directory exists
function Ensure-DestinationDirectory {
    if (-not (Test-Path $warpThemePath)) {
        Write-Host "Creating Warp theme directory..."
        New-Item -ItemType Directory -Path $warpThemePath -Force | Out-Null
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
    $installedThemes = @()
    $alreadyInstalledThemes = @()
    $notInstalledThemes = @()
    foreach ($file in $themes) {
        $destinationPath = "$warpThemePath\$file"
        if (Test-Path $destinationPath) {
            $alreadyInstalledThemes += $file
        } else {
            $notInstalledThemes += $file
        }
    }

    if ($notInstalledThemes.Count -gt 0) {
        foreach ($file in $notInstalledThemes) {
            try {
                $fileUrl = "$repoRawUrl/$file"
                Invoke-WebRequest -Uri $fileUrl -OutFile "$warpThemePath\$file"
                $installedThemes += $file
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error installing ${file}: $(${($_.Exception.Message)})", "Error")
            }
        }
    }

    $message = ""
    if ($isInstallAll -and $alreadyInstalledThemes.Count -eq $themes.Count) {
        $message = "All themes are already installed!"
    } else {
        if ($installedThemes.Count -gt 0) {
            $installedList = $installedThemes -join "`n"
            $message += "The following themes have been installed successfully:`n$installedList`nTo use them, restart Warp and select them from settings."
        }
        if ($alreadyInstalledThemes.Count -gt 0) {
            $alreadyInstalledList = $alreadyInstalledThemes -join "`n"
            $message += "The following themes were already installed:`n$alreadyInstalledList`n"
        }
        if ($installedThemes.Count -eq 0 -and $alreadyInstalledThemes.Count -eq 0) {
            $message = "No new themes were installed."
        }
    }

    [System.Windows.Forms.MessageBox]::Show($message, "Installation Summary")
}

# Create GUI for theme selection
function New-ThemeInstallerGUI {
    param ($themeFiles)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Make the process DPI-aware
    Set-ProcessDPIAware

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Warp Theme Installer"
    $form.Size = New-Object System.Drawing.Size(600, 750)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(243, 243, 243)
    $form.Font = New-Object System.Drawing.Font("Segoe UI Variable", 12)
    $form.Padding = New-Object System.Windows.Forms.Padding(20)

    # Initialize the CheckedListBox
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.MultiColumn = $true
    $checkedListBox.ColumnWidth = 270
    $checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI Variable", 12)
    $checkedListBox.Padding = New-Object System.Windows.Forms.Padding(10)
    $themeFiles | ForEach-Object { $checkedListBox.Items.Add($_) }
    $form.Controls.Add($checkedListBox)

    # Install Buttons
    $buttonsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonsPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $buttonsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $buttonsPanel.AutoSize = $true
    $buttonsPanel.WrapContents = $false
    $buttonsPanel.Padding = New-Object System.Windows.Forms.Padding(20)
    $buttonsPanel.Margin = New-Object System.Windows.Forms.Padding(0, 20, 0, 20)
    $form.Controls.Add($buttonsPanel)

    $buttonNames = @("Install Selected", "Install All", "Exit")
    $buttonActions = @(
        { $selectedThemes = $checkedListBox.CheckedItems; Install-Themes -themes $selectedThemes -isInstallAll $false },
        { Install-Themes -themes $themeFiles -isInstallAll $true },
        { $form.Close() }
    )

    for ($i = 0; $i -lt 3; $i++) {
        $button = New-Object System.Windows.Forms.Button
        $button.Text = $buttonNames[$i]
        $button.AutoSize = $true
        $button.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $button.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
        $button.ForeColor = [System.Drawing.Color]::White
        $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $button.Font = New-Object System.Drawing.Font("Segoe UI Variable", 10)
        $button.Margin = New-Object System.Windows.Forms.Padding(20)
        $button.Width = 180
        $button.Add_Click($buttonActions[$i])
        $buttonsPanel.Controls.Add($button)
    }

    $form.ShowDialog()
}

# Main
Ensure-DestinationDirectory
$themeFiles = Get-ThemeFiles
New-ThemeInstallerGUI -themeFiles $themeFiles
