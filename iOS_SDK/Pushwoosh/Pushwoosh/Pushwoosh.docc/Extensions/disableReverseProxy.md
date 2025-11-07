# ``Pushwoosh/disableReverseProxy()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Disables reverse proxy configuration.

## Discussion

Reverts API requests to use the default Pushwoosh server URLs. Call this method to restore normal operation after previously configuring a reverse proxy with `setReverseProxy:`.
