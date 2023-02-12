[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)][string]$Search,
	[Parameter(Mandatory = $false)][bool]$Open
)

if (!([Environment]::OSVersion.Platform -eq 'Win32NT')) {
	Write-Error 'You must be running on Windows to do this!'
	Exit 1
}

function CommandExists {
	param($Command)

	if (Get-Command $Command -ErrorAction SilentlyContinue) {
		return $true
	}

	return $false
}

$stopwatch = New-Object Diagnostics.Stopwatch
$stopwatch.Start()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install Chocolatey and the packages
if (!(CommandExists choco)) {
	Write-Host 'Installing Chocolatey...'
	Set-ExecutionPolicy Bypass -Scope Process -Force
	Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

	if (!(CommandExists python)) {
		Write-Host 'Installing Python...'
		choco upgrade -y python
		refreshenv
	}

	if (!(CommandExists ffmpeg)) {
		Write-Host 'Installing ffmpeg...'
		choco upgrade -y ffmpeg
		refreshenv
	}

	if (!(CommandExists spotdl)) {
		Write-Host 'Installing spotdl...'
		python -m pip install spotdl
		refreshenv
	}
}

Start-Process -FilePath 'python' -ArgumentList "-m spotdl `"$Search`"" -NoNewWindow -Wait

$songFile = (Get-ChildItem -Path $pwd -Filter *.mp3)[0].FullName
$songFileName = [IO.Path]::GetFileNameWithoutExtension($songFile)
$songArtist = ($songFileName -split ' - ')[0]
$songTitle = ($songFileName -split ' - ')[1]
$songDir = [IO.Path]::Combine($pwd, $songArtist, $songTItle)
$songInfo = ffprobe "$songFile" -v quiet -print_format json -show_entries format=duration | ConvertFrom-Json
$songLength = [Convert]::ToDouble($songInfo.format.duration)

$ticksPerQuarterNote = 960.0
$durationInTicks = $songLength * $ticksPerQuarterNote

$rppLink = 'https://raw.githubusercontent.com/tastyFr/tasty-utilities/master/CreatePianoReaperProj/template.rpp'
$rpp = (New-Object Net.WebClient).DownloadString($rppLink)
$rpp = $rpp.Replace('LENGTH 240', "LENGTH $songLength")
$rpp = $rpp.Replace('E 230400', "E $durationInTicks")
$rpp = $rpp.Replace('FILE ""', "FILE `"$songFileName.mp3`"")
$rppFile = [IO.Path]::Combine($songDir, "$songFileName.rpp")

New-Item  -Path		   $songDir	 -ItemType	  Directory -Force
Move-Item -LiteralPath $songFile -Destination $songDir	-Force
New-Item  -Path		   $rppFile	 -ItemType	  File		-Force -Value $rpp

if ($Open) {
	$reaperPath = [IO.Path]::Combine('HKLM:', 'SOFTWARE', 'Microsoft', 'Windows', 'CurrentVersion', 'Uninstall', 'REAPER')
	if (!(Test-Path $reaperPath)) {
		Write-Error 'REAPER is not installed.'
		$stopwatch.Stop()
		Exit 1
	}

	$reaperAppPath = Resolve-Path (Get-ItemProperty $reaperPath).InstallLocation
	if ([string]::IsNullOrEmpty($reaperAppPath)) {
		Write-Error 'Unable to retrieve REAPER app path.'
		$stopwatch.Stop()
		Exit 1
	}

	& ([IO.Path]::Combine($reaperAppPath, 'reaper.exe')) $rppFile
}

$stopwatch.Stop()
$time = $stopwatch.ElapsedMilliseconds

Write-Host ''
Write-Host "Successfully created in $($time)ms"
Write-Host ''

Exit 0