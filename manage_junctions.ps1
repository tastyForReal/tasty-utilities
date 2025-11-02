param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
)

$output_script_path = ".\recreate_junctions.ps1"

Write-Host "Starting junction management process..."

Write-Host "Searching for junction points..."
$junctions = Get-ChildItem -Path $Path -Recurse -Attributes ReparsePoint | Where-Object { $_.LinkType -eq 'Junction' }

if ($null -eq $junctions -or $junctions.Count -eq 0) {
    Write-Host "No junction points found in the current directory or its subdirectories."
    return
}

Write-Host "Found $($junctions.Count) junction(s):"
$junctions | ForEach-Object { Write-Host " - $($_.FullName) -> $($_.Target)" }

Write-Host "Generating recreation script at '$output_script_path'..."

$recreation_commands = @()

foreach ($junction in $junctions) {
    $junction_path = $junction.FullName
    $target = $junction.Target
    $command_string = "New-Item -ItemType Junction -Path '$junction_path' -Target '$target' -Force"
    $recreation_commands += $command_string
}

$recreation_commands | Set-Content -Path $output_script_path -Encoding ascii
Write-Host "Successfully created '$output_script_path'."

Write-Host "Removing original junction points to save disk space..."

foreach ($junction in $junctions) {
    Remove-Item -Path $junction.FullName -Force
}

Write-Host "Process complete."