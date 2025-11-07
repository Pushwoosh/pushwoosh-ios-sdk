# ``Pushwoosh/mergeUserId(_:to:doMerge:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Merges or moves all events from one user ID to another.

## Discussion

Transfers user data and events between user identifiers. If `doMerge` is true, all events from `oldUserId` are moved to `newUserId`. If false, all events for `oldUserId` are removed.

This is useful when consolidating user accounts or handling user identifier changes in your system.

## Parameters

- oldUserId: Source user identifier
- newUserId: Destination user identifier
- doMerge: If false, all events for oldUserId are removed. If true, all events are moved to newUserId.
- completion: Block called when the operation completes
