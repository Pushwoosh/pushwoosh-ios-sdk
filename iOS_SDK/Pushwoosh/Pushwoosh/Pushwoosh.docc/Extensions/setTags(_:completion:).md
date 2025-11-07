# ``Pushwoosh/setTags(_:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sets user tags with a completion handler.

## Discussion

Identical to `setTags:` but provides a callback to confirm the tags were successfully sent to the server. Use this method when you need to know whether the tag operation succeeded or failed.

## Parameters

- tags: Dictionary of tag names and values to set for the current device
- completion: Block called when the operation completes, with nil for success or an error object for failure
