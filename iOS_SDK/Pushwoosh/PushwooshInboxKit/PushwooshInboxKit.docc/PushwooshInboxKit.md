# ``PushwooshInboxKit``

Modern UIKit inbox UI powered by Pushwoosh.

## Overview

`PushwooshInboxKit` ships a `UIViewController` you can drop into any UIKit
navigation flow to render your app's message inbox. It is built on top of the
existing `PWInbox` data layer in `PushwooshCore` and adds:

- six built-in card kinds — banner, captioned, classic, carousel, video, and
  Apple Wallet — chosen per message by the server `displayType` field (or forced
  via code), with graceful fallback to `classic` when a card's media is missing;
- a value-typed `Attributes` configuration container with cell registry,
  transform pipeline, and visual style;
- automatic dark-mode reactivity (no per-color setup);
- swipe-to-delete, mark-as-read on disappear, pull-to-refresh;
- a delegate protocol with default implementations so hosts override only
  the callbacks they care about;
- Obj-C-friendly setters so existing Obj-C apps can integrate without
  bridging headers.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>

### Public Surface

- ``PushwooshInboxKitViewController``
- ``PushwooshInboxKitAttributes``
- ``PushwooshInboxKitDelegate``
- ``PushwooshInboxCell``

### Rich Cards

- ``PushwooshInboxBannerCell``
- ``PushwooshInboxCaptionedCell``
- ``PushwooshInboxClassicCell``
- ``PushwooshInboxCarouselCell``
- ``PushwooshInboxVideoCell``
- ``PushwooshInboxWalletCell``
- ``PushwooshInboxCarouselSlide``
- ``PushwooshInboxVideoContent``
- ``PushwooshInboxWalletPass``
