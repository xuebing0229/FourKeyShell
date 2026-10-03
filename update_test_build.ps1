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
        throw "GitHub CLI (gh) 未安装或不在 PATH 中。"
    }
    return $command.Source
}

function Get-LatestRelease([string]$GhPath, [string]$Repository) {
    $json = & $GhPath api "repos/$Repository/releases?per_page=20"
    if ($LASTEXITCODE -ne 0) {
        throw "无法读取 GitHub Release；请确认 gh 已登录并有该私有仓库的访问权限。"
    }
    $releases = @($json | ConvertFrom-Json | Where-Object { -not $_.draft } | Sort-Object { [DateTime]$_.published_at } -Descending)
    if ($releases.Count -eq 0) {
        throw "仓库还没有可用的 GitHub Release。"
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
        throw "最新 Release 没有 FourKeyShell 测试包。"
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
        throw "安装目录不存在。"
    }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("FourKeyShell-update-" + [Guid]::NewGuid().ToString("N"))
    $downloadDir = Join-Path $tempRoot "download"
    $expandedDir = Join-Path $tempRoot "expanded"
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    New-Item -ItemType Directory -Path $expandedDir -Force | Out-Null

    Write-Host "下载 $tag ..."
    & $gh release download $tag --repo $Repo --pattern $asset.name --dir $downloadDir --clobber
    if ($LASTEXITCODE -ne 0) {
        throw "下载测试包失败。"
    }
    $zipPath = Join-Path $downloadDir $asset.name
    Expand-Archive -LiteralPath $zipPath -DestinationPath $expandedDir -Force

    if ($ProcessId -gt 0) {
        try {
            Wait-Process -Id $ProcessId -Timeout 20 -ErrorAction SilentlyContinue
        } catch {
            # 进程已退出即可继续覆盖。
        }
    }

    Write-Host "覆盖安装到 $InstallDir ..."
    Get-ChildItem -LiteralPath $expandedDir -Force | Copy-Item -Destination $InstallDir -Recurse -Force
    $exePath = Join-Path $InstallDir $ExecutableName
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "覆盖安装完成，但找不到 $ExecutableName。"
    }
    Write-Host "更新完成，正在启动 $tag ..."
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
