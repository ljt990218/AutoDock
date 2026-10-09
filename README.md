<p align='center'>
  <img src='AutoDock/Assets.xcassets/AppIcon.appiconset/icon_128x128.png' width='96' height='96' alt='AutoDock icon'>
</p>

<h1 align='center'>AutoDock</h1>

<p align='center'>
  English · <a href='README.zh-CN.md'>简体中文</a>
</p>

<p align='center'>
  Automatically switch the macOS Dock position based on your external display.<br>
  Right at work, left at home — just connect your display.
</p>

<p align='center'>
  <img src='https://img.shields.io/badge/macOS-13%2B-007AFF' alt='Requires macOS 13 or later'>
  <img src='https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-555555' alt='Universal build for Apple Silicon and Intel'>
  <a href='LICENSE'><img src='https://img.shields.io/badge/License-MIT-34C759' alt='MIT license'></a>
</p>

AutoDock is a lightweight macOS menu bar utility. Configure a rule for each display once, and the Dock will automatically move to the left, bottom, or right as you switch between your office, home, and other workspaces.

Built with Swift, SwiftUI, and AppKit, with no third-party library dependencies. Rules stay on your Mac, with no account or network service required.

[Features](#features) · [Installation](#installation) · [Quick Start](#quick-start) · [Rule Behavior](#rule-behavior) · [FAQ](#faq) · [Development and Releases](#development-and-releases)

## Features

- **Automatic switching by display**: Assign a Dock position to an external display. AutoDock responds to connections, disconnections, display configuration changes, and wake from sleep.
- **Menu bar controls**: Checkmarks show the current Dock position and active rule. Switch positions manually at any time, and view display details in Manage Rules.
- **Multiple display priorities**: When several displays are connected, rule priority determines the Dock position.
- **Rule management**: Add, edit, delete, enable, or disable rules, with custom display names.
- **Behavior after disconnection**: When no external display is connected, keep the current position or switch to the left, bottom, or right.
- **Launch at login**: Use macOS login items to start AutoDock, with registration and approval status shown in the app.
- **Local diagnostics**: View recent logs and export diagnostic information. If stored data is corrupted, AutoDock preserves the original data and pauses automatic switching.
- **About page**: View the app version, feature overview, source repository, and license information in the management window.

AutoDock reloads the Dock only when the target position differs from the current position. Consecutive display events are coalesced.

## Installation

### System Requirements

| Item | Requirement |
| --- | --- |
| Operating system | macOS 13 Ventura or later |
| Processor | Apple Silicon or Intel; packages include both architectures |

The minimum deployment target and universal architectures are configured in the project. See [Release Status](#release-status) for hardware validation coverage.

### Download and Install

1. Open this repository's [**Releases**](https://github.com/ljt990218/AutoDock/releases) and download a release `.dmg` or `.zip`. If no release is available, [run from source](#run-from-source).
2. Open the DMG or extract the ZIP, then drag `AutoDock.app` into Applications.
3. Launch AutoDock and click the display icon in the menu bar.

> Current packages use ad-hoc signing and have not been signed with a Developer ID or notarized by Apple. macOS may block the first launch. Follow [Apple's official instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) without disabling system security checks.

To update, quit the old version, replace the app in Applications, and launch it again. If launch at login stops working after an update, turn it off and back on, then check the system approval status.

## Quick Start

1. **Connect a display**: Connect the external display you want to configure.
2. **Add a rule**: Click the menu bar icon → Manage Rules → Add Rule for the relevant display, choose a Dock position, and save.
3. **Name the rule**: Use a name such as Office Display or Home Display to make it easier to identify.
4. **Adjust settings**: In Settings, choose the behavior when no external display is connected and optionally enable Launch at Login.

For example:

| Scenario | Configuration | Result |
| --- | --- | --- |
| Office | Office Display → Right | Dock moves to the right when connected |
| Home | Home Display → Left | Dock moves to the left when connected |
| Laptop only | No external display → Bottom | Dock moves to the bottom after all external displays disconnect |

Automatic monitoring is enabled by default, launch at login is disabled, and the Dock keeps its current position when no external display is connected. Connecting a display for the first time does not create a rule automatically.

If launch at login is waiting for system approval, click Open System Login Item Settings on the Settings tab in the management window, then allow the login item in macOS.

## Rule Behavior

| Situation | Behavior |
| --- | --- |
| One enabled rule matches | Apply that rule's Dock position |
| Multiple enabled rules match | Apply the rule with the highest priority; larger values mean higher priority |
| Multiple rules share the highest priority | Keep the current position and report a conflict, even if the target positions are identical |
| No external display matches a rule | Keep the current position |
| Configured and unconfigured displays are connected together | Apply the configured display's rule |
| No external display is connected | Use the configured behavior for no external display |
| Automatic monitoring is disabled | Stop applying rules automatically; manual switching remains available |

New rules have a default priority of `0`. When several configured displays are connected, give the rule you want to apply a higher priority.

Quick Switch is a temporary manual action. AutoDock does not continuously override manual changes. It matches rules again on the next display change or automatic rule update. Closing the management window leaves the app running in the menu bar. Use Quit AutoDock to exit; the current Dock position is preserved.

### Display Identification

Display identity is determined in this order:

1. Valid vendor ID + model ID + hardware serial number
2. Display UUID
3. Valid vendor ID + model ID + actual system name

Rules and connected displays each generate a matching key for comparison. An existing rule with a strong identity does not automatically fall back to name matching when that identity is temporarily unavailable. Custom names are for display only and do not affect identity matching.

- Changing a hub, port, connection type, or DisplayLink driver may change the UUID and require a new rule.
- Without a serial number or UUID, the vendor, model, and name combination cannot reliably distinguish two displays of the same model.
- Mirrored displays may not provide an actual system name. AutoDock still attempts to use the serial number or UUID.
- If different display outputs provide the same identity and match a rule, AutoDock keeps the current position and reports the identification limitation.

See the [Field Mapping documentation](docs/FIELD_MAPPING.md) for the complete fields and matching rules.

## Privacy and Permissions

- Rules and settings are stored only in the current Mac user's local preferences. AutoDock uses no account, cloud sync, or network service.
- No Accessibility, Screen Recording, or Location permission is requested. Launch at login is managed through macOS login items.
- AutoDock only changes the Dock's `orientation` preference and reloads the Dock. It does not change resolution, brightness, display arrangement, or other Dock settings.
- Diagnostic exports may contain display serial numbers, UUIDs, custom names, and original local data. Review and remove sensitive information before sharing.

## FAQ

### Why is there no main window or Dock icon?

AutoDock is a menu bar app. After launching it, click the display icon in the top menu bar. Manage Rules and Settings open the management window. The Rules tab shows display details and all rules, Settings controls launch at login, Diagnostics lets you view and export diagnostic information, and About shows the app version and open-source project information.

### Why does the Dock stay in place after I connect a display?

Make sure automatic monitoring is enabled, the display has an enabled rule, and no rules share the highest priority. If the target position matches the current position, AutoDock does not reload the Dock. The menu shows the active rule and error messages. Hover over the menu bar icon or open the management window for the full status.

A failed display scan is not treated as having no external display connected. If an operation fails, click Retry or check the logs on the Diagnostics tab.

### Can I choose which display shows the Dock?

AutoDock only sets the left, bottom, or right orientation defined by macOS. It does not guarantee which display the Dock appears on.

### Why does a rule stop working after I change the connection?

A display's UUID may change with the port, hub, or driver. See [Display Identification](#display-identification) and create a new rule for the current connection.

### How do I recover from corrupted local data?

If local data cannot be decoded, AutoDock pauses automatic switching and preserves the original content. Export a diagnostic backup first, then reset local rules and settings in Settings. Resetting does not change the system login item registration status.

## Development and Releases

### Run from Source

1. Install an Xcode version that supports macOS 13.
2. Download or clone this repository and open `AutoDock.xcodeproj`.
3. Select the shared **AutoDock** scheme and your local Mac as the run destination.
4. Run from Xcode. The app icon will appear in the menu bar.

The project uses ad-hoc signing by default, requires no Developer ID certificate, and does not enable App Sandbox. The bundle ID is `com.autodock.AutoDock`, and rules are stored in the app's UserDefaults. Keep this identifier unchanged for releases.

### Build Packages

To package locally:

```bash
bash scripts/package.sh 1.0.0
```

By default, output is written to `dist/`:

```text
AutoDock-1.0.0-universal.dmg
AutoDock-1.0.0-universal.zip
AutoDock-1.0.0-SHA256SUMS.txt
```

Set `AUTODOCK_OUTPUT_DIR` to choose an output directory and `AUTODOCK_BUILD_NUMBER` to specify an integer build number. The script builds a universal binary and generates packages. It does not launch the app or change the packaging machine's Dock preferences.

### GitHub Actions Release Workflow

The repository includes a [manual packaging workflow](.github/workflows/package.yml):

1. In **Actions**, select **Package AutoDock** and click **Run workflow**.
2. Select a branch or tag and enter a three-part numeric version, such as `1.0.0`.
3. When the workflow finishes, download the artifacts containing the DMG, ZIP, and SHA-256 checksum file.
4. After completing release acceptance checks, create a GitHub Release for that version and upload the packages and checksum file.

The workflow runs only when triggered manually. It does not run tests or create a Release automatically. Artifacts are retained for 14 days.

### Project Structure

```text
AutoDock.xcodeproj/       Xcode project and shared scheme
AutoDock/
  AutoDockApp.swift       App entry point
  AppDelegate.swift      Menu bar and window lifecycle
  AppModel.swift         App state and automatic switching coordination
  Models/                Display identities, rules, and settings
  Services/              Display monitoring, rule matching, Dock operations, storage, and login items
  Views/                 Native menus and SwiftUI management interface
  Utilities/             Logging
AutoDockTests/           Core logic unit tests
docs/                    Field mapping and historical test records
scripts/package.sh       Universal packaging script
.github/workflows/       Manual packaging workflow
```

### Release Status

According to the [test records from October 6, 2026](docs/TEST_RESULTS.md), the universal Release build, 26 unit tests, package integrity checks, and ad-hoc signature checks have been completed. UI interactions, physical display connections and disconnections, sleep and wake, and launch at login still require acceptance checks. Validation on Intel Macs and macOS 13 has not yet been completed.

<details>
<summary>Hardware and UI acceptance checklist before release</summary>

The following items are pending. Switching time is measured after the display has been successfully enumerated.

| ID | Scenario | Expected result |
| --- | --- | --- |
| A01 | Connect the office display configured for Right while the Dock is elsewhere | Switch to the right within about 3 seconds after successful enumeration |
| A02 | Connect the home display configured for Left while the Dock is elsewhere | Switch to the left within about 3 seconds after successful enumeration |
| A03 | Switch from the office display to the home display | Apply the new rule without restarting the app |
| A04 | Configure each of the four behaviors for no external display, then disconnect | Follow the corresponding setting |
| A05 | Connect only an unconfigured display | Keep the Dock position and prompt to add a rule |
| A06 | Trigger a display event while the Dock is already at the target position | No Dock reload required |
| A07 | Change configurations repeatedly or connect and disconnect rapidly | Coalesce events and handle the final valid state |
| A08 | Create a rule, then quit and restart the app and Mac | Preserve rules and settings |
| A09 | Install and approve launch at login, then log in again | Launch automatically and match rules |
| A10 | Add, edit, disable, and delete rules | Keep UI state and storage consistent; closing the window does not quit the app |

Additional scenarios: sleep and wake, closing and opening the laptop lid, switching between extended and mirrored displays, identical display models, USB-C hubs, DisplayLink, port changes, priority conflicts, manual switching, disabled monitoring, operation failures, and data recovery.

</details>

## Feedback and Contributions

Report bugs or suggest improvements through this repository's [**Issues**](https://github.com/ljt990218/AutoDock/issues). Contributions via [**Pull Requests**](https://github.com/ljt990218/AutoDock/pulls) are also welcome.

When reporting an issue, include your macOS version, Mac chip type, display model and connection type, steps to reproduce, and the expected and actual behavior. Remove serial numbers, UUIDs, and personal names before sharing diagnostic information.

## License

This project is licensed under the [MIT License](LICENSE).
