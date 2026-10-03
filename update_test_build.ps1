[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidateSet("Check", "Install")] [string]$Mode,
    [Parameter(Mandatory = $true)] [string]$Repo,
    [Parameter(Mandatory = $true)] [string]$CurrentVersion,
    [string]$InstallDir = "",
    [int]$ProcessId = 0,
    [string]$ExecutableName = "FourKeyShell.exe"
)

$ErrorActionPreference = "Stop"

function Get-GhPath {
    $command = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "GitHub CLI (gh) is not installed or is not on PATH."
    }
    return $command.Source
}

function Get-LatestRelease([string]$GhPath, [string]$Repository) {
    $json = (& $GhPath api "repos/$Repository/releases?per_page=20" | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot read GitHub releases. Make sure gh is logged in and can access the private repository."
    }
    $parsed = ConvertFrom-Json -InputObject ([string]$json)
    $releases = @($parsed | Where-Object { -not $_.draft } | Sort-Object -Property published_at -Descending)
    if ($releases.Count -eq 0) {
        throw "The repository has no usable GitHub Release yet."
    }
    return $releases[0]
}

function Normalize-Version([string]$Value) {
    return $Value.Trim().TrimStart("v")
}

try {
    $gh = Get-GhPath
    $release = Get-LatestRelease $gh $Repo
    $tag = [string]$release.tag_name
    $assets = @($release.assets | Where-Object { $_.name -like "FourKeyShell-test-*.zip" })
    if ($assets.Count -eq 0) {
        throw "The latest Release has no FourKeyShell test package."
    }
    $asset = $assets[0]

    if ((Normalize-Version $tag) -eq (Normalize-Version $CurrentVersion)) {
        Write-Output "CURRENT|$tag|$($asset.name)"
        exit 0
    }

    if ($Mode -eq "Check") {
        Write-Output "UPDATE|$tag|$($asset.name)"
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($InstallDir) -or -not (Test-Path -LiteralPath $InstallDir)) {
        throw "The install directory does not exist."
    }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("FourKeyShell-update-" + [Guid]::NewGuid().ToString("N"))
    $downloadDir = Join-Path $tempRoot "download"
    $expandedDir = Join-Path $tempRoot "expanded"
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    New-Item -ItemType Directory -Path $expandedDir -Force | Out-Null

    Write-Host "Downloading $tag ..."
    $downloaded = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        & $gh release download $tag --repo $Repo --pattern $asset.name --dir $downloadDir --clobber
        if ($LASTEXITCODE -eq 0) {
            $downloaded = $true
            break
        }
        if ($attempt -lt 3) {
            Write-Host "Download attempt $attempt failed; retrying ..."
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
    if (-not $downloaded) {
        throw "Downloading the test package failed."
    }
    $zipPath = Join-Path $downloadDir $asset.name
    Expand-Archive -LiteralPath $zipPath -DestinationPath $expandedDir -Force

    if ($ProcessId -gt 0) {
        try {
            Wait-Process -Id $ProcessId -Timeout 20 -ErrorAction SilentlyContinue
        } catch {
            # The process already exited; continue with the replacement.
        }
    }

    Write-Host "Replacing files in $InstallDir ..."
    Get-ChildItem -LiteralPath $expandedDir -Force | Copy-Item -Destination $InstallDir -Recurse -Force
    $exePath = Join-Path $InstallDir $ExecutableName
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "The replacement finished, but $ExecutableName was not found."
    }
    Write-Host "Update complete. Starting $tag ..."
    Start-Process -FilePath $exePath -WorkingDirectory $InstallDir
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
} catch {
    Write-Error $_.Exception.Message
    if ($Mode -eq "Install" -and -not [string]::IsNullOrWhiteSpace($InstallDir)) {
        $exePath = Join-Path $InstallDir $ExecutableName
        if (Test-Path -LiteralPath $exePath) {
            Start-Process -FilePath $exePath -WorkingDirectory $InstallDir
        }
    }
    exit 1
}
