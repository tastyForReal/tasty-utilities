$default_username = "DailyDriver"
$powershell_profile_filename = "Microsoft.PowerShell_profile.ps1"
$archive_dir = ".\env"

$scoop_installer_url = "https://get.scoop.sh"
$scoop_installer_script = ".\install_scoop.ps1"
$scoop_packages = @(
    "7zip", "adb", "bun", "cloc", "dotnet-sdk", "fastfetch", "ffmpeg",
    "gh", "git", "jq", "nodejs", "oh-my-posh", "python@3.13.9", "wget"
)

$pytorch_index_url = "https://download.pytorch.org/whl/cu130"
$pytorch_packages = @("torch", "torchvision")
$python_git_packages = @(
    "git+https://github.com/giampaolo/psutil",
    "git+https://github.com/googleapis/python-genai",
    "git+https://github.com/spotDL/spotify-downloader",
    "git+https://github.com/yt-dlp/yt-dlp",
    "git+https://github.com/Yujia-Yan/Transkun"
)

$oh_my_posh_theme_url = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomicBit.omp.json"

$manage_junctions_script = ".\manage_junctions.ps1"
$recreate_junctions_script = ".\recreate_junctions.ps1"

function Write-Heading {
    param(
        [Parameter(Mandatory = $true)]
        [string]$content
    )
    Write-Host ("-" * $content.Length)
    Write-Host $content
    Write-Host ("-" * $content.Length)
}

$local_username = $env:LOCAL_USERNAME, $default_username | Where-Object { -not [string]::IsNullOrEmpty($_) } | Select-Object -First 1
$local_userprofile = Join-Path "C:\Users" $local_username
$scoop_dir = Join-Path $local_userprofile "scoop"
$scoop_exe = Join-Path $scoop_dir "shims\scoop.ps1"
$pip_exe = Join-Path $scoop_dir "apps\python\current\Scripts\pip.exe"

Write-Heading "Installing Scoop..."

New-Item -ItemType Directory -Path $scoop_dir -Force | Out-Null
Invoke-RestMethod -Uri $scoop_installer_url | Out-File -FilePath $scoop_installer_script -Encoding ascii
. $scoop_installer_script -ScoopDir $scoop_dir

if ($env:INSTALL_SCOOP_PACKAGES -eq 'on') {
    Write-Heading "Updating Scoop..."
    . $scoop_exe update

    Write-Heading "Installing Scoop packages..."
    . $scoop_exe install $scoop_packages

    Write-Heading "Cleaning up old package versions..."
    . $scoop_exe cleanup *

    Write-Heading "Purging package cache..."
    . $scoop_exe cache rm *
}

if (($env:INSTALL_PYTHON_PACKAGES -eq 'on') -and (Test-Path $scoop_exe) -and (Test-Path $pip_exe)) {
    Write-Heading "Installing Python packages (PyTorch)..."
    $pip_args_pytorch = "install", ($pytorch_packages -join ' '), "--index-url", $pytorch_index_url
    Start-Process -FilePath $pip_exe -ArgumentList $pip_args_pytorch -NoNewWindow -Wait -PassThru

    Write-Heading "Installing Python packages (from Git)..."
    $pip_args_git = "install", ($python_git_packages -join ' ')
    Start-Process -FilePath $pip_exe -ArgumentList $pip_args_git -NoNewWindow -Wait -PassThru
}

Write-Heading "Exporting configuration to PowerShell profile..."

$scoop_paths = $env:Path -split ";" | Where-Object { $_ -like "*scoop*" }
$profile_content = @(
    "`$env:Path += `";$($scoop_paths -join ';')`"",
    "oh-my-posh init pwsh --config `"$oh_my_posh_theme_url`" | Invoke-Expression"
)
$profile_content | Out-File -FilePath $powershell_profile_filename -Encoding ascii
Get-Content $powershell_profile_filename

Write-Heading "Managing junctions..."

. $manage_junctions_script -Path $scoop_dir

Write-Heading "Copying contents for archiving..."

New-Item -ItemType Directory -Path $archive_dir -Force | Out-Null
Copy-Item -Path $powershell_profile_filename -Destination $archive_dir
if (Test-Path -Path $recreate_junctions_script) {
    Copy-Item -Path $recreate_junctions_script -Destination $archive_dir
}
$robocopy_args = @(
    $scoop_dir,
    (Join-Path $archive_dir "scoop"),
    "/e",
    "/mt:$([Environment]::ProcessorCount)",
    "/nc", "/ndl", "/nfl", "/np", "/ns", "/xj"
)
Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopy_args -NoNewWindow -Wait

Write-Heading "Completed."