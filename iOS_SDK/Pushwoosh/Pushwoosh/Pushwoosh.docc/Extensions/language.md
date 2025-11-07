# ``Pushwoosh/language``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Custom application language for push notifications.

## Discussion

Set this property to override the device language for push notification content. The language must be a lowercase two-letter code according to ISO-639-1 standard (e.g., "en", "de", "fr", "es").

By default, the SDK uses the device's system language. Set this property to a specific language code to receive notifications in that language regardless of the device settings. Set to `nil` to revert to using the device language.

This affects which localized content is delivered from Pushwoosh servers.
