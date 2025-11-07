# ``Pushwoosh/setReverseProxy(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Changes default base URL to a reverse proxy URL.

## Discussion

Use this method to route Pushwoosh API requests through a custom reverse proxy server. This is useful for organizations that require all network traffic to go through their own infrastructure.

The reverse proxy must forward requests to Pushwoosh servers while maintaining the API contract.

## Parameters

- url: The reverse proxy URL
