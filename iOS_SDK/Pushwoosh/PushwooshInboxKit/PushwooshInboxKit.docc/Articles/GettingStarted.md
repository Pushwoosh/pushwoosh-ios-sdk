# Getting Started

Drop the inbox controller into your app.

## Overview

`PushwooshInboxKit` is shipped as an optional XCFramework alongside the main
SDK. After adding the `PushwooshXCFramework/PushwooshInboxKit` subspec (or the
SPM library), instantiate ``PushwooshInboxKitViewController`` and push it onto
your navigation stack.

## Swift

```swift
import PushwooshInboxKit

let inbox = PushwooshInboxKitViewController(attributes: PushwooshInboxKitAttributes())
inbox.delegate = self
navigationController?.pushViewController(inbox, animated: true)
```

To show the default inbox screen without importing the module, ask the SDK for it. The result is `nil` when `PushwooshInboxKit` is not linked:

```swift
import PushwooshFramework

if let inbox = Pushwoosh.InboxKit.makeViewController() {
    navigationController?.pushViewController(inbox, animated: true)
}
```

## Objective-C

```objc
@import PushwooshInboxKit;

PushwooshInboxKitViewController *inbox = [PushwooshInboxKitViewController new];
[inbox setBackgroundColor:UIColor.systemBackgroundColor];
[inbox setEmptyMessage:@"Nothing here yet"];
[self.navigationController pushViewController:inbox animated:YES];
```

The controller refreshes itself on `viewWillAppear`, on
`PWInboxMessagesDidUpdateNotification`, and on push delivery. No additional
plumbing required.
