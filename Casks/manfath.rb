cask "manfath" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/Dnymte/manfath/releases/download/v#{version}/Manfath-#{version}.dmg",
      verified: "github.com/Dnymte/manfath/"
  name "Manfath"
  desc "Menu bar app for monitoring localhost ports"
  homepage "https://manfath.dev"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Manfath.app"

  zap trash: [
    "~/Library/Application Support/Manfath",
    "~/Library/Caches/com.manfath.app",
    "~/Library/HTTPStorages/com.manfath.app",
    "~/Library/Preferences/com.manfath.app.plist",
    "~/Library/Saved Application State/com.manfath.app.savedState",
  ]
end
