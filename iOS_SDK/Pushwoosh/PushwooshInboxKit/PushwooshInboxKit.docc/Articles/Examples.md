# Examples

Recipes for the most common configurations.

## Custom cell registry

```swift
final class HeroInboxCell: PushwooshInboxCell { /* custom layout */ }

var attrs = PushwooshInboxKitAttributes()
attrs.cells["hero"] = HeroInboxCell.self
attrs.cellKindResolver = { message in
    (message.imageUrl?.isEmpty ?? true) ? "default" : "hero"
}

let inbox = PushwooshInboxKitViewController(attributes: attrs)
```

## Filter / sort with `transform`

```swift
var attrs = PushwooshInboxKitAttributes()
attrs.transform = { messages in
    messages
        .filter { !$0.isRead }
        .sorted { $0.sendDate > $1.sendDate }
}
```

## Lifecycle delegate

```swift
extension MyHost: PushwooshInboxKitDelegate {
    func inboxKit(_ vc: PushwooshInboxKitViewController, didSelect message: PWInboxMessageProtocol) -> Bool {
        if message.type == .deeplink {
            myRouter.handle(message.actionParams)
            return false
        }
        return true
    }
}
```

## Force light theme

```swift
var attrs = PushwooshInboxKitAttributes()
attrs.enableDarkTheme = false
```

## Hide the pin indicator while keeping pinned-first sorting

```swift
var attrs = PushwooshInboxKitAttributes()
attrs.pinningEnabled = true        // server-pinned messages still float to the top
attrs.pinIndicatorVisible = false  // but the visual chip / glyph is hidden
```

Obj-C:

```objc
[inboxVC setPinIndicatorVisible:NO];
```

Set `pinningEnabled = false` to disable pinned-first ordering entirely; this also hides the indicator. Use `pinIndicatorVisible = false` when you want the ordering but a cleaner look.
