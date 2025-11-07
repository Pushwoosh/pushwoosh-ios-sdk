# ``Pushwoosh/setEmails(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers a list of email addresses associated with the current user.

## Discussion

Associates multiple email addresses with the current device for email-based campaigns and multi-channel messaging. All emails in the array must be valid, non-empty strings.

The emails are sent to Pushwoosh servers during the next network sync.

## Parameters

- emails: Array of user's email addresses
