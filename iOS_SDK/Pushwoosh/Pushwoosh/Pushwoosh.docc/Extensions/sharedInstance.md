# ``Pushwoosh/sharedInstance()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns the shared Pushwoosh SDK instance.

## Discussion

Access this singleton to interact with the Pushwoosh SDK after initialization. All SDK operations are performed through this shared instance.

The SDK must be initialized via Info.plist with key `Pushwoosh_APPID` before accessing the shared instance.

## Returns

The singleton Pushwoosh instance
