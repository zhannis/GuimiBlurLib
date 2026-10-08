[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDirectory
)

$ErrorActionPreference = 'Stop'
$taskRepository = Split-Path -Parent $PSScriptRoot
$taskSource = (Resolve-Path -LiteralPath $SourceDirectory).Path
$taskManifestPath = Join-Path $taskRepository 'artifacts.json'
$taskManifest = Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
$taskExpectedFiles = @{
    'guimi-blur-lib' = 'GuimiBlurLib-release.aar'
    'guimi-blur-ext-lib' = 'GuimiBlurExtLib-release.aar'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

if ($taskManifest.formatVersion -ne 1 -or $taskManifest.artifacts.Count -ne 2) {
    throw 'Invalid artifacts.json. Expected the base and extension release AARs.'
}
if (@($taskManifest.artifacts.id | Sort-Object -Unique).Count -ne 2) {
    throw 'artifacts.json must contain distinct base and extension entries.'
}

# Validate both inputs before replacing either artifact.
$taskInputs = foreach ($taskArtifact in $taskManifest.artifacts) {
    $taskFileName = $taskExpectedFiles[$taskArtifact.id]
    if (-not $taskFileName -or $taskArtifact.file -ne "aars/$taskFileName") {
        throw "Unexpected artifact path: $($taskArtifact.file)"
    }
    $taskInput = Join-Path $taskSource $taskFileName
    $taskOutput = Join-Path $taskRepository $taskArtifact.file
    if (-not (Test-Path -LiteralPath $taskInput -PathType Leaf)) {
        throw "Missing release AAR: $taskInput"
    }
    if ([IO.Path]::GetFullPath($taskInput) -eq [IO.Path]::GetFullPath($taskOutput)) {
        throw 'Choose the private build output directory, not this repository\aars.'
    }
    $taskArchive = [IO.Compression.ZipFile]::OpenRead($taskInput)
    try {
        if (-not $taskArchive.GetEntry('AndroidManifest.xml') -or
            -not $taskArchive.GetEntry('classes.jar')) {
            throw "Not an Android library AAR: $taskInput"
        }
    } finally {
        $taskArchive.Dispose()
    }
    [PSCustomObject]@{
        Artifact = $taskArtifact
        Input = $taskInput
        Output = $taskOutput
        Hash = (Get-FileHash -LiteralPath $taskInput -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

foreach ($taskItem in $taskInputs) {
    Copy-Item -LiteralPath $taskItem.Input -Destination $taskItem.Output -Force
    $taskItem.Artifact.sha256 = $taskItem.Hash
    Write-Output "Imported $($taskItem.Artifact.id): $($taskItem.Hash)"
}
$taskJson = $taskManifest | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($taskManifestPath, $taskJson + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
Write-Output 'Next: update releaseVersion and run .\gradlew.bat verifyPublications --offline.'
