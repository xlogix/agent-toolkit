class AgentTools < Formula
  desc "Cross-platform installer for coding-agent toolchains"
  homepage "https://github.com/<owner>/<repo>"
  url "https://github.com/<owner>/<repo>/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_TARBALL_SHA256"
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
