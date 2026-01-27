# ``PushwooshKeychain``

Persistent HWID storage across app reinstallation for QA and testing.

## Overview

PushwooshKeychain provides persistent device identification (HWID) that survives app reinstallation. This module is designed for QA and testing scenarios where you need to maintain the same device identity across multiple app installs.

The module stores HWID in iOS Keychain on first launch and retrieves it on subsequent launches, even after the app has been reinstalled.

> Important: This module automatically disables itself in App Store builds to ensure production safety. It only works in Simulator, Debug, and TestFlight environments.

## How It Works

1. On first launch, the module generates an HWID and stores it in the iOS Keychain
2. On subsequent launches (including after reinstallation), the module retrieves the stored HWID
3. The SDK uses this persistent HWID instead of generating a new one

## Usage

Simply link the PushwooshKeychain module to your project. No additional code is required — the SDK automatically detects and uses it.

```swift
import PushwooshKeychain

// Check if persistent HWID is active
if PushwooshKeychainImplementation.isEnabled {
    print("Persistent HWID is active")
}

// Get current environment
let environment = PushwooshKeychainImplementation.currentEnvironment
// Returns: .simulator, .debug, .testFlight, or .appStore

// Clear persistent HWID (for testing)
PushwooshKeychainImplementation.clearPersistentHWID()
```

## Environment Detection

The module automatically detects the current runtime environment:

| Environment | Detection Method | Keychain Enabled |
|-------------|------------------|------------------|
| Simulator | `#targetEnvironment(simulator)` | Yes |
| Debug | `embedded.mobileprovision` present | Yes |
| TestFlight | `sandboxReceipt` receipt file | Yes |
| App Store | No provisioning, production receipt | **No** |

## Topics

### Core Classes

- ``PushwooshKeychainImplementation``

### Environment

- ``PWAppEnvironment``

### Properties

- ``PushwooshKeychainImplementation/isEnabled``
- ``PushwooshKeychainImplementation/currentEnvironment``

### Methods

- ``PushwooshKeychainImplementation/getPersistentHWID()``
- ``PushwooshKeychainImplementation/clearPersistentHWID()``
