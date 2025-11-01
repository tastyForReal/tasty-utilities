function Write-Heading {
    param(
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
$scoop_paths = $env:Path -split ";" | Where-Object { $_ -like "*scoop*" }

Write-Heading "Installing Scoop..."
Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
Write-Heading "Installing Scoop packages..."
. "$env:USERPROFILE\scoop\shims\scoop.ps1" install $scoop_packages
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
$normalized_scoop_path = ($scoop_paths -join ";") -replace [regex]::Escape($env:USERPROFILE), '$env:USERPROFILE'
"$env:Path += `"; " + $normalized_scoop_path + "`"" | Out-File -FilePath $pwsh_profile -Encoding ascii
"oh-my-posh init pwsh --config " + $omp_theme + " | Invoke-Expression" | Out-File -FilePath $pwsh_profile -Encoding ascii -Append
Get-Content $pwsh_profile

Write-Heading "Archiving..."
& "$env:USERPROFILE\scoop\shims\7z.exe"`
    "a"`
    "-t7z"`
    "-m0=lzma2"`
    "-mx=9"`
    "-mfb=64"`
    "-md=32m"`
    "-mhe=on"`
    "-p`"725734`""`
    "env.7z"`
    "$env:USERPROFILE\scoop"`
    "Microsoft.PowerShell_profile.ps1"

Write-Heading "Done."