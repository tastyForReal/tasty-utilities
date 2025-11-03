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
$scoop_exe = "$scoop_dir\shims\scoop.ps1"
$pip_exe = "$scoop_dir\apps\python\current\Scripts\pip.exe"

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
    Write-Heading "Updating Scoop..."
    . $scoop_exe update
    
    Write-Heading "Installing Scoop packages..."
    . $scoop_exe install $scoop_packages

    Write-Heading "Cleaning up..."
    . $scoop_exe cleanup *

    Write-Heading "Purging cache..."
    . $scoop_exe cache rm *
}

if (($env:INSTALL_PYTHON_PACKAGES -eq 'on') -and (Test-Path $scoop_exe) -and (Test-Path $pip_exe)) {
    Write-Heading "Installing Python packages (1 of 2)..."
    & $pip_exe `
        "install"`
        "torch"`
        "torchvision"`
        "--index-url"`
        "https://download.pytorch.org/whl/cu130"

    Write-Heading "Installing Python packages (2 of 2)..."
    & $pip_exe `
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
Start-Process -FilePath "robocopy.exe" -NoNewWindow -Wait -ArgumentList $scoop_dir, ".\env\scoop", "/e", "/mt:$([Environment]::ProcessorCount)", "/nc", "/ndl", "/nfl", "/np", "/ns", "/xj"

Write-Heading "Completed."