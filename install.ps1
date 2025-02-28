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
$themeFilesResponse = Invoke-RestMethod -Uri $repoApiUrl
$themeFiles = $themeFilesResponse | Where-Object { $_.name -match "\.yaml$" } | ForEach-Object { $_.name }

# Create modern GUI for theme selection
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Text = "Warp Theme Installer"
$form.Size = New-Object System.Drawing.Size(400, 400)
$form.StartPosition = "CenterScreen"

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(10, 10)
$checkedListBox.Size = New-Object System.Drawing.Size(360, 250)
$themeFiles | ForEach-Object { $checkedListBox.Items.Add($_) }
$form.Controls.Add($checkedListBox)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install Selected"
$installButton.Location = New-Object System.Drawing.Point(10, 270)
$installButton.Add_Click({
    $selectedThemes = $checkedListBox.CheckedItems
    $results = @()
    foreach ($file in $selectedThemes) {
        $destinationPath = "$warpThemePath\$file"
        if (Test-Path $destinationPath) {
            $results += "$file is already installed."
        } else {
            $fileUrl = "$repoRawUrl/$file"
            Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
            $results += "$file installed successfully!"
        }
    }
    $resultsMessage = "Installation Results:`n`n" + ($results -join "`n") + "`n`nTo use the new themes, restart Warp and select them from the settings."
    [System.Windows.Forms.MessageBox]::Show($resultsMessage, "Installation Results")
})
$form.Controls.Add($installButton)

$installAllButton = New-Object System.Windows.Forms.Button
$installAllButton.Text = "Install All"
$installAllButton.Location = New-Object System.Drawing.Point(150, 270)
$installAllButton.Add_Click({
    $results = @()
    foreach ($file in $themeFiles) {
        $destinationPath = "$warpThemePath\$file"
        if (Test-Path $destinationPath) {
            $results += "$file is already installed."
        } else {
            $fileUrl = "$repoRawUrl/$file"
            Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
            $results += "$file installed successfully!"
        }
    }
    $resultsMessage = "Installation Results:`n`n" + ($results -join "`n") + "`n`nTo use the new themes, restart Warp and select them from the settings."
    [System.Windows.Forms.MessageBox]::Show($resultsMessage, "Installation Results")
})
$form.Controls.Add($installAllButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Location = New-Object System.Drawing.Point(290, 270)
$exitButton.Add_Click({ $form.Close() })
$form.Controls.Add($exitButton)

$form.ShowDialog()
