<div align="center">

  <img src="https://nuvio.tv/assets/nuvio-app-logo-wordmark.webp" alt="Nuvio" width="320" />

  <p>
    A free, open-source media app for your phone, your desktop, and the TV you already own.
    <br />
    Bring your own sources. Nuvio turns them into a library with artwork, ratings, subtitles, and your place saved on every screen.
  </p>

  [Website](https://nuvio.tv) · [GitHub releases](https://github.com/NuvioMedia/NuvioMobile/releases/latest) · [Support Nuvio](https://nuvio.tv/support)

</div>

## Get Nuvio Mobile

- [Android on Google Play](https://play.google.com/store/apps/details?id=com.nuvio.app)
- [Android APK](https://github.com/NuvioMedia/NuvioMobile/releases/latest)
- iOS via AltStore or SideStore: add [this source URL](https://raw.githubusercontent.com/NuvioMedia/NuvioMobile/cmp-rewrite/store.json) in the app's Sources section, then install Nuvio.

## Build from source

```bash
git clone https://github.com/NuvioMedia/NuvioMobile.git
cd NuvioMobile
```

### Android

Android development requires Android Studio and the Android SDK.

```bash
./gradlew :androidApp:assembleFullDebug
```

### iOS

iOS development requires macOS and Xcode.

```bash
env NUVIO_IOS_DISTRIBUTION=full xcodebuild \
  -project iosApp/iosApp.xcodeproj \
  -scheme iosApp \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath build/ios-derived-full-simulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The shared app is built with Kotlin Multiplatform and Compose Multiplatform.

### TestFlight

On a Mac signed into Xcode with access to the Apple Developer team, provide App Store Connect credentials and run. Set `NUVIO_SUPABASE_URL` and `NUVIO_SUPABASE_ANON_KEY` in the environment or `local.properties`; the release build rejects missing auth configuration.

```bash
APPLE_TEAM_ID=YOUR_TEAM_ID \
APPLE_ID=you@example.com \
APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx \
  ./scripts/release/testflight.sh
```

The script builds and uploads a signed Release IPA for `com.nuvio.app.NuvioHEGN9W2S9J`. Use `--no-upload` to build/export without uploading, or `--build-number NUMBER` to choose the numeric build number. The App Store Connect record is **Nuvio Media Player** (SKU `nuvio-ios`).

To sync the upstream and fork branches, then build and upload in one step, run:

```bash
./scripts/release/sync-upstream-testflight.sh
```

It expects a clean `cmp-rewrite` checkout tracking `personal/cmp-rewrite`, with `origin` pointing to `NuvioMedia/NuvioMobile` and `personal` to your fork. It fetches both, merges them into the local branch, pushes the result to your fork, then runs the TestFlight release script. Merge conflicts stop the script; resolve and commit them before rerunning. Release options such as `--no-upload` and `--build-number NUMBER` are forwarded.

## License

[GNU General Public License v3.0](./LICENSE)
