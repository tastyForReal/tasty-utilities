param (
    [string]$OhMyPoshThemeUrl,
    [string]$PowershellProfileName
)

function Write-Heading {
    param (
        [string]$Content
    )
    $border = "-" * $Content.Length
    Write-Host $border
    Write-Host $Content
    Write-Host $border
}

# --- Get updated PATH after setting up Scoop ---
Write-Heading "Retrieving updated PATH environment variable..."
# In PowerShell, $env:Path is directly accessible and updated by Scoop installations
# We can just use the current $env:Path
$updated_path = $env:Path

# --- Export PowerShell Profile Configuration ---
Write-Heading "Exporting configuration to PowerShell profile..."
$path_env = $updated_path
$scoop_paths = $path_env.Split(';') | Where-Object { $_ -like "*scoop*" }

$profile_content = @(
    "`$env:Path += `";$($scoop_paths -join ';')`""
    "oh-my-posh init pwsh --config `"$OhMyPoshThemeUrl`" | Invoke-Expression"
) -join "`n"

# Write to the current directory, replicating original setup.js behavior
Set-Content -Path $PowershellProfileName -Value $profile_content -Encoding UTF8
Get-Content -Path $PowershellProfileName
