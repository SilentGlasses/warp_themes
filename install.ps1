# Define variables
$repoRawUrl = "https://raw.githubusercontent.com/SilentGlasses/warp_themes/main/yaml_files"  # Updated repo URL
$repoApiUrl = "https://api.github.com/repos/SilentGlasses/warp_themes/contents/yaml_files"  # Updated GitHub API URL for listing files
$warpThemePath = "$env:AppData\Roaming\warp\Warp\data\themes"

# Ensure the destination directory exists
if (-not (Test-Path $warpThemePath)) {
    Write-Host "Creating Warp theme directory..."
    New-Item -ItemType Directory -Path $warpThemePath -Force | Out-Null
}

# Get a list of YAML theme files from the repository
Write-Host "Fetching list of theme files..."
try {
    $themeFilesResponse = Invoke-RestMethod -Uri $repoApiUrl
    $themeFiles = $themeFilesResponse | Where-Object { $_.name -match "\.yaml$" } | ForEach-Object { $_.name }
} catch {
    Write-Host "Error fetching theme files: $_"
    exit 1
}

# Create GUI for theme selection
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Text = "Warp Theme Installer"
$form.Size = New-Object System.Drawing.Size(400, 400)
$form.StartPosition = "CenterScreen"

$listBox.Location = New-Object System.Drawing.Point(10, 10)
$listBox.Size = New-Object System.Drawing.Size(360, 250)
$listBox.SelectionMode = "MultiExtended"
$themeFiles | ForEach-Object { $listBox.Items.Add($_) }
$form.Controls.Add($listBox)

$installThemes = {
    param ($themes)
    foreach ($file in $themes) {
        $destinationPath = "$warpThemePath\$file"
        if (Test-Path $destinationPath) {
            [System.Windows.Forms.MessageBox]::Show("$file is already installed.", "Info")
        } else {
            try {
                $fileUrl = "$repoRawUrl/$file"
                Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
                [System.Windows.Forms.MessageBox]::Show("$file installed successfully!`nTo use it, restart Warp and select it from settings.", "Success")
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error installing $file: $_", "Error")
            }
        }
    }
}

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install Selected"
$installButton.Location = New-Object System.Drawing.Point(10, 270)
$installButton.Add_Click({
    $selectedThemes = $listBox.SelectedItems
    $installThemes.Invoke($selectedThemes)
})
$form.Controls.Add($installButton)

$installAllButton = New-Object System.Windows.Forms.Button
$installAllButton.Text = "Install All"
$installAllButton.Location = New-Object System.Drawing.Point(150, 270)
$installAllButton.Add_Click({
    $installThemes.Invoke($themeFiles)
})
$form.Controls.Add($installAllButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Location = New-Object System.Drawing.Point(290, 270)
$exitButton.Add_Click({ $form.Close() })
$form.Controls.Add($exitButton)

$form.ShowDialog()