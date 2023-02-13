[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)][string]$song,
	[Parameter(Mandatory = $false)][bool]$openAfterSuccess
)

if (!($env:OS -eq 'Windows_NT')) {
	Write-Host 'This script can only be run on Windows operating systems.'
	Exit 1
}

function Test-CommandExistence {
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$CommandName
	)

	$result = Get-Command $CommandName -ErrorAction SilentlyContinue
	if ($result) {
		return $true
	}

	return $false
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Check if Chocolatey is already installed
if (!(Test-CommandExistence 'choco')) {
	# Install Chocolatey
	Set-ExecutionPolicy Bypass -Scope Process -Force
	Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Check if FFmpeg is already installed
if (!(Test-CommandExistence 'ffmpeg')) {
	# Install FFmpeg
	choco install ffmpeg
}

# Check if Python is already installed
if (!(Test-CommandExistence 'python')) {
	# Install Python
	choco install python
}

# Refresh the environment to pick up the newly installed packages
refreshenv

# Check if the "spotdl" pip package is already installed
if (!(python -c 'import spotdl; print(spotdl.__version__)' -eq $null)) {
	# Install the "spotdl" pip package
	pip install spotdl
}

$song = "`"$song`""

Start-Process -FilePath 'python' -ArgumentList "-m spotdl $song" -NoNewWindow -Wait

$mp3FilePath = Get-ChildItem -Path . -Filter *.mp3 | Select-Object -First 1 -ExpandProperty FullName

$fileName = [IO.Path]::GetFileNameWithoutExtension($mp3FilePath)
$artist, $title = $fileName -split ' - '

$ffprobeOutput = & 'ffprobe.exe' '-i' $mp3FilePath '-show_entries' 'format=duration' '-v' 'quiet' '-of' 'csv=p=0'
$duration = [double]$ffprobeOutput

$ticksPerQuarterNote = 960.0
$ticks = $ticksPerQuarterNote * $duration

# Download the .RPP template file and store it as a string
$uri = 'https://raw.githubusercontent.com/tastyFr/tasty-utilities/master/CreatePianoReaperProj/template.rpp'
$templateFile = Invoke-WebRequest $uri	-UseBasicParsing
$templateString = $templateFile.Content

# Rename the file
$newFileName = "$artist - $title.rpp"

# Replace contents in the file
$templateString = $templateString.Replace('LENGTH 240', "LENGTH $duration")
$templateString = $templateString.Replace('E 230400', "E $ticks")
$templateString = $templateString.Replace('FILE ""', 'FILE "' + [IO.Path]::GetFileName($mp3FilePath) + '"')

# Save the current file to the current directory
Set-Content -Path $newFileName -Value $templateString

# Create a folder named after the song artist
New-Item -ItemType Directory -Path $artist -Force

# Create a folder inside the song artist folder, named after the song title
New-Item -ItemType Directory -Path "$artist/$title" -Force

# Put both the downloaded .MP3 and .RPP files into the song title folder
Move-Item $mp3FilePath "$artist/$title" -Force
Move-Item $newFileName "$artist/$title" -Force

$stopwatch.Stop()
Write-Host ''
Write-Host "Time elapsed: $($stopwatch.Elapsed.TotalSeconds) seconds"

$reaperInstallPath = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\REAPER').InstallLocation

if ($openAfterSuccess) {
	if (![string]::IsNullOrEmpty($reaperInstallPath)) {
		Start-Process "$reaperInstallPath\reaper.exe" -ArgumentList [IO.Path]::Combine($pwd, $artist, $title, "$artist - $title.rpp")
		Exit 0
	}

	Write-Warning 'REAPER is not installed. Aborting.'
}