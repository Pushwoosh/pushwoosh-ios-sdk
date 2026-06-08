# ``PushwooshNotificationUI``

A ready-made full-screen "stories" UI for an expanded push notification.

## Overview

PushwooshNotificationUI provides ``PushwooshStoriesViewController`` — a drop-in
`UNNotificationContentExtension` view controller that renders an Instagram-style
stories experience: full-bleed images, top progress bars, auto-advance, tap-zone
navigation, per-frame title/subtitle, and an optional deep-link button.

The module links only UIKit, UserNotifications, and UserNotificationsUI (plus
CryptoKit for a stable cache key), so it adds no Pushwoosh Core/Framework weight
to your memory-constrained extension process.

## Usage

In your Notification Content Extension:

```swift
import PushwooshNotificationUI

class NotificationViewController: PushwooshStoriesViewController {}
```

Then set these keys in the extension's Info.plist:

- `UNNotificationExtensionCategory` = `PW_STORIES` (must match `aps.category`)
- `UNNotificationExtensionUserInteractionEnabled` = `YES`
- `UNNotificationExtensionDefaultContentHidden` = `YES`
- `UNNotificationExtensionInitialContentSizeRatio` = e.g. `1.5` (keep in sync with ``PushwooshStoriesViewController/storyAspectRatio``)
- `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).NotificationViewController` (code-only, no storyboard)

## Payload

The stories are described by a `pw_stories` block, alongside an `aps.category`
matching `UNNotificationExtensionCategory`. The parser accepts the block either at
the **payload root** (e.g. via the Pushwoosh API `ios_root_params`) or inside the
custom-data container `u` / `userdata` (the Pushwoosh API `data` field — delivered as
a dictionary or a JSON-encoded string). The root form on the device looks like this:

```json
{
  "aps": { "category": "PW_STORIES" },
  "pw_stories": { "pages": [
    { "image": "https://.../1.jpg", "duration": 5.0,
      "link": "myapp://sale", "button_title": "Buy",
      "title": "Summer Sale", "subtitle": "Up to 70% off" },
    { "image": "https://.../2.jpg" }
  ]}
}
```

Sent through the `data` API field instead (recommended, since it does not depend on
`ios_root_params`), the same block arrives nested under `u` — while `aps.category`
(and `mutable-content` for the pre-cache path) still go through `ios_root_params.aps`,
as there is no dedicated request field for them. The relevant createMessage fields:

```json
{
  "ios_root_params": { "aps": { "category": "PW_STORIES", "mutable-content": 1 } },
  "data": { "pw_stories": { "pages": [ { "image": "https://.../1.jpg" } ] } }
}
```

The parser tries the root first, then `u` / `userdata`, so both delivery styles work
and old pushes keep rendering.

Every field except `image` is optional. `link` (like `image`) must include a URL
scheme. A missing, empty, or malformed payload falls back to the default content
(the alert body) without crashing — override ``PushwooshStoriesViewController/showDefaultContent(for:)``.

## Analytics

Set ``PushwooshStoriesViewController/storiesDelegate`` to observe lifecycle and
engagement and forward it to your analytics (the module itself sends nothing):

```swift
class NotificationViewController: PushwooshStoriesViewController, PushwooshStoriesDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        storiesDelegate = self
    }
    func storiesViewController(_ c: PushwooshStoriesViewController, didTapActionFor page: StoryPage, at index: Int) {
        // forward the per-page click to your backend
    }
}
```

## Instant / offline first frame (App Group pre-cache)

To make the first frame appear instantly (and offline), pre-download the media in
a Notification **Service** Extension into a shared App Group container that the
Content Extension reads from:

1. Enable the **App Groups** capability (same id) on both the Service and Content
   extensions, and override ``PushwooshStoriesViewController/appGroupIdentifier``.
2. From the Service Extension's `didReceive(_:withContentHandler:)`, call
   ``PushwooshStoriesMediaPrefetcher/prefetch(userInfo:appGroupIdentifier:completion:)``.
3. Send the push with `mutable-content: 1` so the Service Extension runs.

Without this, the module still works — images download on display instead.

## Topics

### Stories UI

- ``PushwooshStoriesViewController``

### Payload model

- ``StoryPage``

### Analytics

- ``PushwooshStoriesDelegate``

### Media pre-cache

- ``PushwooshStoriesMediaPrefetcher``
