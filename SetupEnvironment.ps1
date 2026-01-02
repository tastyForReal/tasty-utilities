# --- Configuration Constants ---
$DEFAULT_USERNAME = "DailyDriver"
$POWERSHELL_PROFILE = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1"
$ARCHIVE_DIR = Join-Path $PSScriptRoot "env"
$SCOOP_INSTALLER_URL = "https://get.scoop.sh"
$SCOOP_INSTALLER_SCRIPT = Join-Path $PSScriptRoot "InstallScoop.ps1"

$SCOOP_PACKAGES = @(
    "7zip",
    "adb",
    "aria2",
    "bun",
    "cloc",
    "dotnet-sdk",
    "dotnet-sdk-preview",
    "fastfetch",
    "ffmpeg",
    "gh",
    "git",
    "jq",
    "nodejs",
    "oh-my-posh",
    "python@3.13.9"
)

$PYTORCH_INDEX_URL = "https://download.pytorch.org/whl/cu130"
$PYTORCH_PACKAGES = @("torch", "torchvision")

$PYTHON_PACKAGES = @(
    "git+https://github.com/giampaolo/psutil",
    "git+https://github.com/googleapis/python-genai",
    "git+https://github.com/spotDL/spotify-downloader",
    "git+https://github.com/yt-dlp/yt-dlp",
    "git+https://github.com/Yujia-Yan/Transkun"
)

$NPM_PACKAGES = @("@google/gemini-cli@latest")

$OH_MY_POSH_THEME_URL = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomicBit.omp.json"

$MANAGE_JUNCTIONS_SCRIPT = Join-Path $PSScriptRoot "ManageJunctions.ps1"
$RECREATE_JUNCTIONS_SCRIPT = Join-Path $PSScriptRoot "RecreateJunctions.ps1"
$EXPORT_ENVIRONMENT_SCRIPT = Join-Path $PSScriptRoot "ExportEnvironment.ps1"

# --- Helper Functions ---
function Write-Heading {
    param([string]$Content)
    $border = "-" * $Content.Length
    Write-Host $border
    Write-Host $Content
    Write-Host $border
}

function Invoke-ExternalCommand {
    param(
        [string]$CommandPath,
        [string[]]$Arguments = @()
    )
    $argString = if ($Arguments) { $Arguments -join " " } else { "" }
    Write-Host "> Executing: $CommandPath $argString"
    & $CommandPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $CommandPath $argString"
    }
}

# --- Main Script Logic ---
try {
    $local_username = if ($env:LOCAL_USERNAME) { $env:LOCAL_USERNAME } else { $DEFAULT_USERNAME }
    $local_userprofile = "C:\Users\$local_username"
    $scoop_dir = Join-Path $local_userprofile "scoop"
    $shims_dir = Join-Path $scoop_dir "shims"
    $scoop_ps1 = Join-Path $shims_dir "scoop.ps1"
    $pip_exe = Join-Path $scoop_dir "apps\python\current\Scripts\pip.exe"
    $bun_cmd = Join-Path $scoop_dir "apps\bun\current\bun.exe"

    # --- Install Scoop ---
    Write-Heading "Installing Scoop..."
    New-Item -ItemType Directory -Force -Path $scoop_dir | Out-Null

    Write-Host "Downloading Scoop installer from $SCOOP_INSTALLER_URL..."
    $installer_content = (Invoke-WebRequest -Uri $SCOOP_INSTALLER_URL -UseBasicParsing).Content
    Set-Content -Path $SCOOP_INSTALLER_SCRIPT -Value $installer_content -Encoding utf8

    $old_policy = Get-ExecutionPolicy -Scope Process
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    Write-Host "> Executing: $SCOOP_INSTALLER_SCRIPT -ScoopDir $scoop_dir"
    & $SCOOP_INSTALLER_SCRIPT -ScoopDir $scoop_dir

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy $old_policy -Force

    # Make scoop available immediately
    $env:Path = "$shims_dir;$env:Path"

    # --- Install Scoop packages ---
    if ($env:INSTALL_SCOOP_PACKAGES -eq "on") {
        Write-Heading "Adding additional bucket(s)..."
        Invoke-ExternalCommand "scoop" @("bucket", "add", "versions")

        Write-Heading "Updating Scoop..."
        Invoke-ExternalCommand "scoop" @("update")

        Write-Heading "Installing Scoop packages..."
        Invoke-ExternalCommand "scoop" @("install") + $SCOOP_PACKAGES

        Write-Heading "Purging package cache..."
        Invoke-ExternalCommand "scoop" @("cache", "rm", "*")
    }

    # --- Install NPM/Bun packages ---
    if ($env:INSTALL_NPM_PACKAGES -eq "on") {
        if (Test-Path $bun_cmd) {
            Write-Heading "Installing Bun packages..."
            $bun_args = @("add", "-g") + $NPM_PACKAGES
            Invoke-ExternalCommand $bun_cmd $bun_args
        } else {
            Write-Warning "Bun not found at $bun_cmd. Skipping NPM/Bun package installation."
        }
    }

    # --- Install Python packages ---
    if ($env:INSTALL_PYTHON_PACKAGES -eq "on") {
        if ((Test-Path $pip_exe)) {
            Write-Heading "Installing Python packages (stage 1 of 2)..."
            $pytorch_args = @("install") + $PYTORCH_PACKAGES + @("--index-url", $PYTORCH_INDEX_URL)
            Invoke-ExternalCommand $pip_exe $pytorch_args

            Write-Heading "Installing Python packages (stage 2 of 2)..."
            $python_args = @("install") + $PYTHON_PACKAGES
            Invoke-ExternalCommand $pip_exe $python_args
        } else {
            Write-Warning "pip.exe not found at $pip_exe. Skipping Python package installation."
        }
    }

    # --- Export PowerShell Profile configuration ---
    Write-Heading "Exporting configuration to PowerShell profile..."
    & $EXPORT_ENVIRONMENT_SCRIPT -OhMyPoshThemeUrl $OH_MY_POSH_THEME_URL -PowershellProfileName $POWERSHELL_PROFILE

    # --- Manage junctions created by Scoop ---
    Write-Heading "Managing junctions..."
    & $MANAGE_JUNCTIONS_SCRIPT -Path $scoop_dir

    # --- Archive contents ---
    Write-Heading "Copying contents for archiving..."
    New-Item -ItemType Directory -Force -Path $ARCHIVE_DIR | Out-Null

    Copy-Item -Path $POWERSHELL_PROFILE -Destination $ARCHIVE_DIR

    if (Test-Path $RECREATE_JUNCTIONS_SCRIPT) {
        Copy-Item -Path $RECREATE_JUNCTIONS_SCRIPT -Destination $ARCHIVE_DIR
    }

    $robocopy_dest = Join-Path $ARCHIVE_DIR "scoop"
    $robocopy_args = @(
        $scoop_dir,
        $robocopy_dest,
        "/e",
        "/mt:$([Environment]::ProcessorCount)",
        "/nc", "/ndl", "/nfl", "/np", "/ns", "/xj"
    )

    Write-Host "> Executing: robocopy $($robocopy_args -join ' ')"
    robocopy @robocopy_args

    $rc = $LASTEXITCODE
    Write-Host "Robocopy exit code: $rc"

    if ($rc -ge 8) {
        Write-Error "Robocopy encountered critical failures (exit code $rc >= 8). See https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy#exit-return-codes for details."
        exit $rc
    } else {
        Write-Host "Robocopy completed without critical errors (exit code $rc <= 7)."
        exit 0 # Ensure the script exits with code 0 for CI workflows
    }
}
catch {
    Write-Error "`n--- SCRIPT FAILED ---"
    Write-Error $_.Exception.Message
    exit 1
}