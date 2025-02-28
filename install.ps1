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

# Create GUI for theme selection
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Warp Theme Installer"
$form.Size = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"
$form.AutoSize = $true
$form.AutoSizeMode = "GrowAndShrink"
$form.MinimumSize = New-Object System.Drawing.Size(600, 400)

$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 10)
$listView.Size = New-Object System.Drawing.Size(560, 300)
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.MultiSelect = $true
$listView.Columns.Add("Theme Files", -2, [System.Windows.Forms.HorizontalAlignment]::Left)
$listView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$themeFiles | ForEach-Object {
    $item = New-Object System.Windows.Forms.ListViewItem($_)
    $listView.Items.Add($item)
}

$form.Controls.Add($listView)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install Selected"
$installButton.Location = New-Object System.Drawing.Point(10, 320)
$installButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$installButton.Add_Click({
    $selectedThemes = $listView.SelectedItems
    $results = @()
    foreach ($item in $selectedThemes) {
        $file = $item.Text
        $destinationPath = "$warpThemePath\$file"
        if (Test-Path $destinationPath) {
            $results += "$file is already installed."
        } else {
            $fileUrl = "$repoRawUrl/$file"
            Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
            $results += "$file installed successfully! To use it, restart Warp and select it from settings."
        }
    }
    [System.Windows.Forms.MessageBox]::Show(($results -join "`n"), "Installation Results")
})
$form.Controls.Add($installButton)

$installAllButton = New-Object System.Windows.Forms.Button
$installAllButton.Text = "Install All"
$installAllButton.Location = New-Object System.Drawing.Point(150, 320)
$installAllButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$installAllButton.Add_Click({
    $results = @()
    foreach ($file in $themeFiles) {
        $destinationPath = "$warpThemePath\$file"
        if (Test-Path $destinationPath) {
            $results += "$file is already installed."
        } else {
            $fileUrl = "$repoRawUrl/$file"
            Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
            $results += "$file installed successfully! To use it, restart Warp and select it from settings."
        }
    }
    [System.Windows.Forms.MessageBox]::Show(($results -join "`n"), "Installation Results")
})
$form.Controls.Add($installAllButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Location = New-Object System.Drawing.Point(290, 320)
$exitButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$exitButton.Add_Click({ $form.Close() })
$form.Controls.Add($exitButton)

$form.ShowDialog()
