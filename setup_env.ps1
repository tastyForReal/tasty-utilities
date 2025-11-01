function Write-Heading {
    param(
        [string]$Content
    )

    Write-Host ("=" * 32)
    Write-Host $Content
    Write-Host ("=" * 32)
}

$p7z_args = @(
    "a",
    "-t7z",
    "-m0=lzma2",
    "-mx=9",
    "-mfb=64",
    "-md=32m",
    "-mhe=on",
    "-p`"725734`"",
    "env.7z",
    "$env:USERPROFILE\scoop",
    "Microsoft.PowerShell_profile.ps1"
)
$scoop_packages = @(
    "7zip",
    "adb",
    "cloc",
    "fastfetch",
    "ffmpeg",
    "gh",
    "git",
    "jq",
    "nodejs",
    "oh-my-posh",
    "python",
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

$pip_process_stage_one = @{
    FilePath     = "$env:USERPROFILE\scoop\apps\python\current\Scripts\pip.exe"
    ArgumentList = @(
        "install",
        "torch",
        "torchvision",
        "--index-url",
        "https://download.pytorch.org/whl/cu130"
    )
    NoNewWindow  = $true
    Wait         = $true
}
    
Write-Heading "Installing Python packages (1 of 2)..."
Start-Process @pip_process_stage_one

$pip_process_stage_two = @{
    FilePath     = "$env:USERPROFILE\scoop\apps\python\current\Scripts\pip.exe"
    ArgumentList = @(
        "install",
        "git+https://github.com/giampaolo/psutil",
        "git+https://github.com/googleapis/python-genai",
        "git+https://github.com/spotDL/spotify-downloader",
        "git+https://github.com/yt-dlp/yt-dlp",
        "git+https://github.com/Yujia-Yan/Transkun"
    )
    NoNewWindow  = $true
    Wait         = $true
}
    
Write-Heading "Installing Python packages (2 of 2)..."
Start-Process @pip_process_stage_two

Write-Heading "Exporting configuration..."
$normalized_scoop_path = ($scoop_paths -join ";") -replace [regex]::Escape($env:USERPROFILE), '$env:USERPROFILE'
"$env:Path += `"; " + $normalized_scoop_path + "`"" | Out-File -FilePath $pwsh_profile -Encoding ascii
"oh-my-posh init pwsh --config " + $omp_theme + " | Invoke-Expression" | Out-File -FilePath $pwsh_profile -Encoding ascii -Append
Get-Content $pwsh_profile

$p7z_process = @{
    FilePath     = "$env:USERPROFILE\scoop\shims\7z.exe"
    ArgumentList = $p7z_args
    NoNewWindow  = $true
    Wait         = $true
}

Write-Heading "Archiving..."
Start-Process @p7z_process

Write-Heading "Done."