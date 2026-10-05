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
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-GitHubHeaders {
    return @{
        "User-Agent" = "FourKeyShell-Updater"
        "Accept" = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
}

function Get-LatestRelease([string]$Repository) {
    $uri = "https://api.github.com/repos/$Repository/releases?per_page=20"
    try {
        $parsed = Invoke-RestMethod -UseBasicParsing -Uri $uri -Headers (Get-GitHubHeaders) -Method Get
    } catch {
        throw "Cannot read GitHub releases. Check the network connection and GitHub availability."
    }

    $releases = @($parsed | Where-Object { -not $_.draft } | Sort-Object -Property published_at -Descending)
    if ($releases.Count -eq 0) {
        throw "The repository has no usable GitHub Release yet."
    }
    return $releases[0]
}

function Normalize-Version([string]$Value) {
    return $Value.Trim().TrimStart("v")
}

function Download-ReleaseAsset([string]$Url, [string]$Destination) {
    $downloaded = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $Url -Headers (Get-GitHubHeaders) -OutFile $Destination
            $downloaded = $true
            break
        } catch {
            if ($attempt -lt 3) {
                Write-Host "Download attempt $attempt failed; retrying ..."
                Start-Sleep -Seconds (2 * $attempt)
            }
        }
    }

    if (-not $downloaded) {
        throw "Downloading the test package failed."
    }
}

try {
    $release = Get-LatestRelease $Repo
    $tag = [string]$release.tag_name
    $assets = @($release.assets | Where-Object { $_.name -like "FourKeyShell-test-*.zip" })
    if ($assets.Count -eq 0) {
        throw "The latest Release has no FourKeyShell test package."
    }
    $asset = $assets[0]
    $assetUrl = [string]$asset.browser_download_url
    if ([string]::IsNullOrWhiteSpace($assetUrl) -or -not $assetUrl.StartsWith("https://github.com/")) {
        throw "The Release asset download URL is invalid."
    }

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
    $zipPath = Join-Path $downloadDir $asset.name
    Download-ReleaseAsset $assetUrl $zipPath
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
