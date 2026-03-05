[CmdletBinding()]
param(
  [switch]$Extras,
  [switch]$DryRun,
  [switch]$Strict,
  [ValidateSet("winget", "choco", "scoop")]
  [string]$PackageManager
)

$ErrorActionPreference = "Stop"
$Installed = New-Object System.Collections.Generic.List[string]
$Skipped = New-Object System.Collections.Generic.List[string]
$Failed = New-Object System.Collections.Generic.List[string]

function Write-Info {
  param([string]$Message)
  Write-Host $Message
}

function Write-WarnLine {
  param([string]$Message)
  Write-Warning $Message
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Step {
  param([string[]]$Command)

  if ($DryRun) {
    Write-Info ("[dry-run] " + ($Command -join " "))
    return
  }

  & $Command[0] @($Command[1..($Command.Count - 1)])
}

function Detect-PackageManager {
  if ($PackageManager) { return $PackageManager }
  if (Test-Command "winget") { return "winget" }
  if (Test-Command "choco") { return "choco" }
  if (Test-Command "scoop") { return "scoop" }
  throw "No supported Windows package manager found. Install winget, choco, or scoop."
}

function Get-CorePackages {
  param([string]$Manager)
  switch ($Manager) {
    "winget" { return @(
      "BurntSushi.ripgrep.MSVC",
      "sharkdp.fd",
      "jqlang.jq",
      "MikeFarah.yq",
      "junegunn.fzf",
      "sharkdp.bat",
      "eza-community.eza",
      "dandavison.delta",
      "ImageMagick.ImageMagick",
      "Gyan.FFmpeg"
    ) }
    "choco" { return @(
      "ripgrep",
      "fd",
      "jq",
      "yq",
      "fzf",
      "bat",
      "eza",
      "delta",
      "imagemagick",
      "ffmpeg"
    ) }
    "scoop" { return @(
      "ripgrep",
      "fd",
      "jq",
      "yq",
      "fzf",
      "bat",
      "eza",
      "delta",
      "imagemagick",
      "ffmpeg"
    ) }
    default { throw "Unsupported manager: $Manager" }
  }
}

function Get-ExtraPackages {
  param([string]$Manager)
  switch ($Manager) {
    "winget" { return @(
      "UB-Mannheim.TesseractOCR",
      "koalaman.shellcheck",
      "sharkdp.hyperfine",
      "GitHub.cli",
      "ast-grep.ast-grep",
      "chmln.sd",
      "casey.just",
      "direnv.direnv",
      "ajeetdsouza.zoxide",
      "watchexec.watchexec",
      "Wilfred.difftastic",
      "JesseDuffield.lazygit",
      "HTTPie.HTTPie",
      "fullstorydev.grpcurl"
    ) }
    "choco" { return @(
      "tesseract",
      "shellcheck",
      "hyperfine",
      "gh",
      "ast-grep",
      "sd",
      "just",
      "direnv",
      "zoxide",
      "watchexec",
      "difftastic",
      "lazygit",
      "httpie",
      "grpcurl"
    ) }
    "scoop" { return @(
      "tesseract",
      "shellcheck",
      "hyperfine",
      "gh",
      "ast-grep",
      "sd",
      "just",
      "direnv",
      "zoxide",
      "watchexec",
      "difftastic",
      "lazygit",
      "httpie",
      "grpcurl"
    ) }
    default { throw "Unsupported manager: $Manager" }
  }
}

function Test-PackageInstalled {
  param(
    [string]$Manager,
    [string]$Package
  )
  switch ($Manager) {
    "winget" {
      $result = winget list --id $Package --exact 2>$null
      return ($LASTEXITCODE -eq 0 -and $result -match [regex]::Escape($Package))
    }
    "choco" {
      $result = choco list --local-only --exact $Package 2>$null
      return ($result -match ("^" + [regex]::Escape($Package) + "\s"))
    }
    "scoop" {
      $result = scoop list $Package 2>$null
      return ($LASTEXITCODE -eq 0 -and $result -match [regex]::Escape($Package))
    }
    default { return $false }
  }
}

function Initialize-Manager {
  param([string]$Manager)

  switch ($Manager) {
    "winget" {
      Write-Info "==> Using winget"
    }
    "choco" {
      Write-Info "==> Using chocolatey"
    }
    "scoop" {
      Write-Info "==> Using scoop"
      if (-not $DryRun) {
        scoop bucket add main | Out-Null
        scoop bucket add extras | Out-Null
      } else {
        Write-Info "[dry-run] scoop bucket add main"
        Write-Info "[dry-run] scoop bucket add extras"
      }
    }
  }
}

function Install-OnePackage {
  param(
    [string]$Manager,
    [string]$Package
  )

  if (Test-PackageInstalled -Manager $Manager -Package $Package) {
    Write-Info ("  - {0} (already installed)" -f $Package)
    $Skipped.Add($Package)
    return
  }

  Write-Info ("  - {0}" -f $Package)
  try {
    switch ($Manager) {
      "winget" {
        Invoke-Step @(
          "winget", "install", "--id", $Package, "--exact",
          "--accept-package-agreements", "--accept-source-agreements", "--silent"
        )
      }
      "choco" {
        Invoke-Step @("choco", "install", $Package, "-y", "--no-progress")
      }
      "scoop" {
        Invoke-Step @("scoop", "install", $Package)
      }
    }
    $Installed.Add($Package)
  } catch {
    $Failed.Add($Package)
    Write-WarnLine ("Failed to install '{0}' via {1}. {2}" -f $Package, $Manager, $_.Exception.Message)
  }
}

function Install-Packages {
  param(
    [string]$Manager,
    [string]$Group,
    [string[]]$Packages
  )

  if ($Packages.Count -eq 0) { return }
  Write-Info ("==> Installing {0} tools..." -f $Group)
  foreach ($pkg in $Packages) {
    Install-OnePackage -Manager $Manager -Package $pkg
  }
}

$manager = Detect-PackageManager
Initialize-Manager -Manager $manager

$corePackages = Get-CorePackages -Manager $manager
Install-Packages -Manager $manager -Group "core" -Packages $corePackages

if ($Extras) {
  $extraPackages = Get-ExtraPackages -Manager $manager
  Install-Packages -Manager $manager -Group "extra" -Packages $extraPackages
}

Write-Info ""
Write-Info "==> Summary"
Write-Info ("  Package manager: {0}" -f $manager)
Write-Info ("  Installed: {0}" -f $Installed.Count)
Write-Info ("  Already present: {0}" -f $Skipped.Count)
Write-Info ("  Failed: {0}" -f $Failed.Count)

if ($Failed.Count -gt 0) {
  Write-Info ("  Failed packages: {0}" -f ($Failed -join ", "))
}

if ($Strict -and $Failed.Count -gt 0) {
  exit 1
}

exit 0
