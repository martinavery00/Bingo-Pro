param(
    [Parameter(Mandatory = $true)]
    [string] $WorkspacePath,

    [ValidatePattern('^[A-Za-z]$')]
    [string] $DriveLetter = 'X'
)

$ErrorActionPreference = 'Stop'

$expectedPath = [System.IO.Path]::GetFullPath($WorkspacePath).TrimEnd('\')
$driveName = $DriveLetter.ToUpperInvariant()
$mapping = & subst.exe | Where-Object { $_ -match "^${driveName}:\\:" }

if ($mapping) {
    $mappedPath = ($mapping -replace '^.*=>\s*', '').TrimEnd('\')
    if (-not $mappedPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "${driveName}: is already mapped to '$mappedPath', not '$expectedPath'. Choose another drive letter in .vscode/launch.json and .vscode/tasks.json."
    }

    Write-Host "${driveName}: is already mapped to $expectedPath"
    exit 0
}

& subst.exe "${driveName}:" $expectedPath
if ($LASTEXITCODE -ne 0) {
    throw "Could not map ${driveName}: to '$expectedPath'."
}

Write-Host "Mapped ${driveName}: to $expectedPath"
