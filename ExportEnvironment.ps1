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

$updated_path = $env:Path

Write-Heading "Exporting configuration to PowerShell profile..."
$path_env = $updated_path
$scoop_paths = $path_env.Split(';') | Where-Object { $_ -like "*scoop*" }

$profile_content = @(
    "`$env:Path += `";$($scoop_paths -join ';')`""
    "oh-my-posh init pwsh --config `"$OhMyPoshThemeUrl`" | Invoke-Expression"
) -join "`n"

Set-Content -Path $PowershellProfileName -Value $profile_content -Encoding UTF8
Get-Content -Path $PowershellProfileName
