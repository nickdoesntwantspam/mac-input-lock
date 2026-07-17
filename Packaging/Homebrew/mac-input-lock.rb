cask "mac-input-lock" do
  version "1.0.0"
  sha256 "REPLACE_WITH_RELEASE_SHA256"

  url "https://github.com/nickdoesntwantspam/mac-input-lock/releases/download/v#{version}/Mac-Input-Lock-#{version}.dmg"
  name "Mac Input Lock"
  desc "Temporarily disable keyboard, mouse, and trackpad input"
  homepage "https://github.com/nickdoesntwantspam/mac-input-lock"

  depends_on macos: ">= :sonoma"

  app "Mac Input Lock.app"

  caveats <<~EOS
    Mac Input Lock requires Accessibility permission to suppress input.
    Enable it in System Settings → Privacy & Security → Accessibility.
  EOS

  zap trash: "~/Library/Preferences/com.nicholaswilliams.MacInputLock.plist"
end
