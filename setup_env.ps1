function Write-Heading {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    Write-Host ("=" * 32)
    Write-Host $Content
    Write-Host ("=" * 32)
}

$scoop_packages = @(
    "7zip",
    "adb",
    "cloc",
    "dotnet-sdk",
    "fastfetch",
    "ffmpeg",
    "gh",
    "git",
    "jq",
    "nodejs",
    "oh-my-posh",
    "python@3.13.9", # NOTE: spotdl requires Python <3.14,>=3.10
    "wget"
)
$pwsh_profile = "Microsoft.PowerShell_profile.ps1"
$omp_theme = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomicBit.omp.json"

Write-Heading "Installing Scoop..."
Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
Write-Heading "Installing Scoop packages..."
. "$env:USERPROFILE\scoop\shims\scoop.ps1" install $scoop_packages
Write-Heading "Sleeping for 5 seconds..."
Start-Sleep 5
Write-Heading "Updating Scoop..."
. "$env:USERPROFILE\scoop\shims\scoop.ps1" update *
Write-Heading "Cleaning up..."
. "$env:USERPROFILE\scoop\shims\scoop.ps1" cleanup *
Write-Heading "Purging cache..."
. "$env:USERPROFILE\scoop\shims\scoop.ps1" cache rm *

Write-Heading "Installing Python packages (1 of 2)..."
& "$env:USERPROFILE\scoop\apps\python\current\Scripts\pip.exe"`
    "install"`
    "torch"`
    "torchvision"`
    "--index-url"`
    "https://download.pytorch.org/whl/cu130"
    
Write-Heading "Installing Python packages (2 of 2)..."
& "$env:USERPROFILE\scoop\apps\python\current\Scripts\pip.exe"`
    "install"`
    "git+https://github.com/giampaolo/psutil"`
    "git+https://github.com/googleapis/python-genai"`
    "git+https://github.com/spotDL/spotify-downloader"`
    "git+https://github.com/yt-dlp/yt-dlp"`
    "git+https://github.com/Yujia-Yan/Transkun"

Write-Heading "Exporting configuration..."
$scoop_paths = $env:Path -split ";" | Where-Object { $_ -like "*scoop*" }
$normalized_scoop_path = ($scoop_paths -join ";") -replace [regex]::Escape($env:USERPROFILE), '$env:USERPROFILE'
"`$env:Path += `";" + $normalized_scoop_path + "`"" | Out-File -FilePath $pwsh_profile -Encoding ascii
"oh-my-posh init pwsh --config " + $omp_theme + " | Invoke-Expression" | Out-File -FilePath $pwsh_profile -Encoding ascii -Append
Get-Content $pwsh_profile

Write-Heading "Creating directory for archiving..."
New-Item -ItemType Directory -Path ".\env"
New-Item -ItemType Junction -Path ".\env\scoop" -Target "$env:USERPROFILE\scoop"
Move-Item $pwsh_profile ".\env"