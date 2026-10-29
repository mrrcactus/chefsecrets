# ChefSecrets

Personal iOS recipe app: macros on every card, a "What I have" pantry filter with ingredient swaps, and paste-in import from ChatGPT/Claude/TikTok. SwiftUI + SwiftData, iOS 17+, LiftBlue palette. See PLAN.md.

Build (xcode-select points at CommandLineTools, so set DEVELOPER_DIR):

    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChefSecrets.xcodeproj -scheme ChefSecrets -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build

On your iPhone: open ChefSecrets.xcodeproj → Signing & Capabilities → Team = your Apple ID → pick your phone → ⌘R. With a free Apple ID the app expires after 7 days; just ⌘R again (data is kept).
