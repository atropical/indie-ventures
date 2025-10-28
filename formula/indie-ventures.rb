class IndieVentures < Formula
  desc "Self-hosted Supabase manager for running multiple isolated projects"
  homepage "https://github.com/atropical/indie-ventures"
  url "https://github.com/atropical/indie-ventures/archive/v0.1.0-alpha.tar.gz"
  sha256 "" # Will be generated on release
  license "OSL-3.0"
  version "0.1.0-alpha"

  depends_on "gum"
  depends_on "docker"
  depends_on "docker-compose"
  depends_on "jq"

  def install
    # Install everything to libexec
    libexec.install "bin"
    libexec.install "lib"
    libexec.install "templates"

    # Create wrapper script in bin that sets up the environment
    (bin/"indie").write <<~EOS
      #!/bin/bash
      export INDIE_LIB_DIR="#{libexec}/lib"
      export INDIE_TEMPLATES_DIR="#{libexec}/templates"
      exec "#{libexec}/bin/indie" "$@"
    EOS
  end

  def caveats
    <<~EOS
      ⚠️  LOCAL DEVELOPMENT ONLY ⚠️

      This Homebrew installation is intended for local development and testing.

      For production servers, use the direct installation method:
        curl -fsSL https://raw.githubusercontent.com/atropical/indie-ventures/main/install.sh | sudo bash

      DO NOT install Homebrew as root on production servers.

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      Indie Ventures has been installed!

      To get started:
        1. Initialize: indie init
        2. Add project: indie add
        3. List projects: indie list

      Documentation: https://github.com/atropical/indie-ventures

      Dependencies:
        - Docker (required for running services)
        - Gum (for beautiful CLI prompts)
        - jq (for JSON processing)

      All dependencies should be automatically installed via Homebrew.
    EOS
  end

  test do
    system "#{bin}/indie", "version"
  end
end
