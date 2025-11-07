# ``Pushwoosh/getUserId()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns the current user identifier.

## Discussion

Retrieves the user ID that was previously set using `setUserId:`. If no user ID has been set, this method returns the Hardware ID (HWID) as the default identifier.

The user ID defaults to the HWID until explicitly set with `setUserId:`.

## Returns

The current user identifier, or the HWID if no user ID has been set
