# RollControlCenter - Xcode Setup Instructions

This directory contains the Swift source files for an iOS 18+ Control Center widget extension that adds a "Roll Camera" button to the iPhone Control Center.

## Manual Xcode Configuration Steps

### 1. Add a Widget Extension Target

- In Xcode, go to **File > New > Target...**
- Select **Widget Extension** under the iOS section
- Name it **RollControlCenter**
- Set the **Bundle Identifier** to `me.Roll.RollControlCenter`
- Set the **Deployment Target** to **iOS 18.0**
- Uncheck "Include Live Activity" and "Include Configuration App Intent" (not needed)
- Click **Finish**

### 2. Replace Auto-Generated Files

- Delete all auto-generated `.swift` files in the new `RollControlCenter` group
- Add the three Swift files from this directory to the **RollControlCenter** target:
  - `RollControlCenterBundle.swift` - Widget bundle entry point (`@main`)
  - `RollControlWidget.swift` - The Control Center widget definition
  - `LaunchCameraIntent.swift` - The AppIntent that launches the app

### 3. Verify Target Membership

- Select each `.swift` file and confirm it belongs to the **RollControlCenter** target only (not the main Roll target)
- `RollControlCenterBundle.swift` has the `@main` attribute and must not be included in the main app target

### 4. App Group (Optional)

If you need shared data between the main app and the widget extension:
- Go to **Signing & Capabilities** for both the Roll app target and the RollControlCenter target
- Add the **App Groups** capability
- Create a shared group, e.g., `group.me.Roll`

### 5. Build and Test

- Select the **RollControlCenter** scheme and build
- On a device running iOS 18+, open **Control Center**, tap the **+** button, and search for "Roll Camera"
- Tapping the control should launch the Roll app

## How It Works

- `RollCameraToggle` is a `ControlWidget` that renders a button in Control Center
- When tapped, it triggers `LaunchCameraIntent`, an `AppIntent` with `openAppWhenRun = true`
- This causes iOS to open the main Roll app directly
