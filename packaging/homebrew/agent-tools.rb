class AgentTools < Formula
  desc "Cross-platform installer for coding-agent toolchains"
  homepage "https://github.com/xlogix/agent-toolkit"
  url "https://github.com/xlogix/agent-toolkit/archive/refs/tags/v2026.03.06.1.tar.gz"
  sha256 "2c977830e56d91936fc2ea5e15cec9f21bf0662b919842a647cf43d446c1d1b0"
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
