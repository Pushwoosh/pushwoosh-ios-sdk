# ``Pushwoosh/getTags(_:onFailure:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Retrieves the current device's tags from the Pushwoosh server.

## Discussion

Fetches all tags currently set for this device. Tags are returned as a dictionary where keys are tag names and values are the corresponding tag values.

The operation is performed asynchronously and does not block the calling thread.

## Parameters

- successHandler: Block called when tags are successfully retrieved. Receives a dictionary containing all device tags.
- errorHandler: Block called if the request fails. Receives an error describing the failure.
