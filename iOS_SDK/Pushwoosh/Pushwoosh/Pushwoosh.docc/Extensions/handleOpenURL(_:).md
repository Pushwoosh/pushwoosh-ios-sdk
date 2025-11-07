# ``Pushwoosh/handleOpenURL(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Processes deep link URLs.

## Discussion

Handles deep link URLs, primarily used for registering test devices. Call this method from your app delegate's URL handling methods to allow Pushwoosh to process special URLs.

The SDK will return `true` if it handled the URL, or `false` if the URL is not a Pushwoosh URL.

## Parameters

- url: The deep link URL to process

## Returns

Boolean indicating whether Pushwoosh handled the URL
