$ErrorActionPreference = 'Stop'

$core = @(
  'ripgrep',
  'fd',
  'jq',
  'yq',
  'fzf',
  'bat',
  'eza',
  'delta',
  'imagemagick',
  'ffmpeg'
)

foreach ($pkg in $core) {
  Write-Host "Installing $pkg..."
  choco install $pkg -y --no-progress
}

Write-Host 'Agent core toolchain installed.'
Write-Host 'Optional extras: tesseract, shellcheck, hyperfine, gh'

