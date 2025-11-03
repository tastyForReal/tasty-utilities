function Write-Heading {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    Write-Host ("-" * $Content.Length)
    Write-Host $Content
    Write-Host ("-" * $Content.Length)
}

$local_username = $env:LOCAL_USERNAME, "DailyDriver" | Where-Object { -not [string]::IsNullOrEmpty($_) } | Select-Object -First 1
$local_userprofile = "C:\Users\$local_username"
$scoop_dir = "$local_userprofile\scoop"
New-Item -ItemType Directory -Path $scoop_dir -Force | Out-Null

$scoop_packages = @(
    "7zip",
    "adb",
    "bun",
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

Invoke-RestMethod -Uri "https://get.scoop.sh" | Out-File ".\install_scoop.ps1" -Encoding ascii
. ".\install_scoop.ps1" -ScoopDir $scoop_dir

if ($env:INSTALL_SCOOP_PACKAGES -eq 'on') {
    Write-Heading "Updating Scoop buckets..."
    . "$local_userprofile\scoop\shims\scoop.ps1" update
    
    Write-Heading "Installing Scoop packages..."
    . "$local_userprofile\scoop\shims\scoop.ps1" install $scoop_packages

    Write-Heading "Cleaning up..."
    . "$local_userprofile\scoop\shims\scoop.ps1" cleanup *

    Write-Heading "Purging cache..."
    . "$local_userprofile\scoop\shims\scoop.ps1" cache rm *
}

if ($env:INSTALL_PYTHON_PACKAGES -eq 'on') {
    Write-Heading "Installing Python packages (1 of 2)..."
    & "$local_userprofile\scoop\apps\python\current\Scripts\pip.exe"`
        "install"`
        "torch"`
        "torchvision"`
        "--index-url"`
        "https://download.pytorch.org/whl/cu130"

    Write-Heading "Installing Python packages (2 of 2)..."
    & "$local_userprofile\scoop\apps\python\current\Scripts\pip.exe"`
        "install"`
        "git+https://github.com/giampaolo/psutil"`
        "git+https://github.com/googleapis/python-genai"`
        "git+https://github.com/spotDL/spotify-downloader"`
        "git+https://github.com/yt-dlp/yt-dlp"`
        "git+https://github.com/Yujia-Yan/Transkun"
}

Write-Heading "Exporting configuration..."
$scoop_paths = $env:Path -split ";" | Where-Object { $_ -like "*scoop*" }
"`$env:Path += `";" + ($scoop_paths -join ";") + "`"" | Out-File -FilePath $pwsh_profile -Encoding ascii
"oh-my-posh init pwsh --config " + $omp_theme + " | Invoke-Expression" | Out-File -FilePath $pwsh_profile -Encoding ascii -Append
Get-Content $pwsh_profile

Write-Heading "Managing junctions..."
. ".\manage_junctions.ps1" -Path $scoop_dir

Write-Heading "Copying contents for archiving..."
New-Item -ItemType Directory -Path ".\env"
Copy-Item $pwsh_profile ".\env"
if (Test-Path ".\recreate_junctions.ps1") { 
    Copy-Item ".\recreate_junctions.ps1" ".\env" 
}
Start-Process -FilePath "robocopy.exe" -NoNewWindow -Wait -ArgumentList $scoop_dir, ".\env\scoop", "/e", "/xj", "/ns", "/nc", "/np", "/nfl", "/ndl", "/mt:$([Environment]::ProcessorCount)"

Write-Heading "Completed."