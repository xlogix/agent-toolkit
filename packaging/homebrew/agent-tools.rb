class AgentTools < Formula
  desc "Cross-platform installer for coding-agent toolchains"
  homepage "https://github.com/xlogix/agent-toolkit"
  url "https://github.com/xlogix/agent-toolkit/archive/refs/tags/v2026.03.05.tar.gz"
  sha256 "0c89df98e3190002692ca80bc0f24eafb053228913bb5dca7fd02039390c790a"
  license "MIT"

  depends_on "ripgrep"
  depends_on "fd"
  depends_on "jq"
  depends_on "yq"
  depends_on "fzf"
  depends_on "bat"
  depends_on "eza"
  depends_on "git-delta"
  depends_on "imagemagick"
  depends_on "ffmpeg"

  def install
    bin.install "agent-tools.sh" => "agent-tools"
    bin.install "install.sh" => "agent-tools-install"
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/agent-tools --help")
  end
end
