# ``PushwooshErrorHandler``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Completion handler called when an operation fails.

## Discussion

This closure is called when a Pushwoosh operation fails, providing an error object describing what went wrong.

The handler receives an optional `NSError` parameter. If the error is `nil`, the operation succeeded (though typically success handlers use different callback types).

Use this handler to respond to failures appropriately, such as displaying error messages to users, logging errors, or retrying operations.

