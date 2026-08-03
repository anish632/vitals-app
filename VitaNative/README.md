# Vita native iPhone app

Open [Vita.xcodeproj](Vita.xcodeproj) in Xcode 26.3.

## What is real

- Heart rate: optional rear-camera/torch PPG estimate from the fingertip.
- HealthKit: reads the newest available heart rate, oxygen saturation, blood pressure, VO₂ max, and sleep samples after permission is granted.
- The app does not invent missing measurements. Oxygen saturation, blood pressure, and VO₂ max require supported Apple Health sources or validated connected hardware.

## Run on your iPhone 13

1. Open `Vita.xcodeproj` in Xcode.
2. Select the `Vita` target → **Signing & Capabilities**.
3. Choose your Apple Developer **Team** and make the bundle identifier unique, for example `com.yourname.vita`.
4. Confirm **HealthKit** is enabled.
5. Connect your iPhone, select it as the run destination, and press **Run**.
6. Accept the camera and Apple Health permissions inside the app.

Simulator builds validate the UI, but HealthKit and the camera pulse check require a physical device.

## Upload to TestFlight

1. Create the matching app record in App Store Connect with the same bundle identifier.
2. In Xcode, choose **Any iOS Device (arm64)**.
3. Choose **Product → Archive**.
4. In Organizer, choose **Distribute App → App Store Connect → Upload**.
5. After processing, add the build under **TestFlight** and invite yourself as an internal tester.

Before public release, add a privacy policy, complete App Store privacy disclosures, test HealthKit authorization paths, and review the app's medical/wellness claims.
