# ``Pushwoosh/setEmails(_:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers a list of email addresses with a completion handler.

## Discussion

Associates multiple email addresses with the current device for email-based campaigns. The completion handler is called when the operation completes, receiving `nil` on success or an error on failure.

## Parameters

- emails: Array of user's email addresses
- completion: Block called when the operation completes. Receives nil on success or an NSError on failure.
