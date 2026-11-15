# Bubble Cash

An iPhone wallet app with a made-up currency (Bubble Cash). Needs iOS 17 or later.

## Build the .ipa on GitHub (no Mac needed)

1. Unzip this folder. Make a new **private** repo on github.com.
2. Upload everything, including the hidden `.github` folder (on Windows, turn on "Hidden items" in File Explorer > View to see it).
3. Open the repo's **Actions** tab. "Build IPA" starts on its own; if not, click it, then **Run workflow**.
4. When it shows a green check (~10 min), open the run and download **BubbleCash-ipa** under Artifacts. Unzip it to get `BubbleCash.ipa`.

## Install with Sideloadly (Windows)

1. Install iTunes and iCloud from apple.com (not the Microsoft Store versions), then install Sideloadly.
2. Plug in your iPhone, unlock it, and tap **Trust** on the phone.
3. Drag `BubbleCash.ipa` into Sideloadly, enter your Apple ID, and click **Start**.
4. On the iPhone: Settings > Privacy & Security > **Developer Mode** > On (it restarts).
5. Settings > General > **VPN & Device Management** > tap your Apple ID > **Trust**.
6. Open Bubble Cash. The first time you pay, allow Face ID.

With a free Apple ID the app expires after 7 days. Re-run step 3 to refresh it.
