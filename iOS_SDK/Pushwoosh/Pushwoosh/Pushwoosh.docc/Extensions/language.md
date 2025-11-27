# ``Pushwoosh/language``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Custom application language for push notifications.

## Overview

Override the device language for notification content localization. This affects which language version of your push notifications is delivered from Pushwoosh servers.

## Format

Use lowercase two-letter ISO-639-1 language codes:
- `"en"` - English
- `"de"` - German
- `"fr"` - French
- `"es"` - Spanish
- `"ru"` - Russian
- `"ja"` - Japanese

## Default Behavior

By default, Pushwoosh uses the device's system language. Set this property to override, or set to `nil` to revert to device language.

## Example

Let user choose notification language:

```swift
func updateNotificationLanguage(_ languageCode: String) {
    Pushwoosh.configure.language = languageCode

    userDefaults.set(languageCode, forKey: "notificationLanguage")
}
```

Sync with app's localization:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    if let appLanguage = Bundle.main.preferredLocalizations.first {
        Pushwoosh.configure.language = appLanguage
    }

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Language selection in settings:

```swift
class LanguageSettingsViewController: UIViewController {

    let languages = [
        ("en", "English"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("es", "Español")
    ]

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (code, _) = languages[indexPath.row]

        Pushwoosh.configure.language = code

        Bundle.setLanguage(code)

        reloadApp()
    }
}
```

## See Also

- ``Pushwoosh/setTags(_:)``
