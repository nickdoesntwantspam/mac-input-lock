cask "mac-input-lock" do
  version "1.0.0"
  sha256 "bd63d38731fc37d543baf1669435753d537bf05fb6eef4b35552e149a82604e5"

  url "https://github.com/nickdoesntwantspam/mac-input-lock/releases/download/v#{version}/Mac-Input-Lock-#{version}.dmg"
  name "Mac Input Lock"
  desc "Temporarily disable keyboard, mouse, and trackpad input"
  homepage "https://github.com/nickdoesntwantspam/mac-input-lock"

  depends_on macos: :sonoma

  app "Mac Input Lock.app"

  zap trash: "~/Library/Preferences/com.nicholaswilliams.MacInputLock.plist"

  caveats <<~EOS
    Mac Input Lock requires Accessibility permission to suppress input.
    Enable it in System Settings → Privacy & Security → Accessibility.
  EOS
end
