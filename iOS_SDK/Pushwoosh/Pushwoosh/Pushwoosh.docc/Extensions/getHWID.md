# ``Pushwoosh/getHWID()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns the Pushwoosh Hardware ID (HWID) for this device.

## Discussion

The HWID is a unique device identifier used in all Pushwoosh API calls and for device tracking in the Pushwoosh Control Panel. On iOS, this corresponds to `UIDevice.identifierForVendor`.

The HWID is generated on first SDK initialization and persists across app launches. Use this identifier to reference the device in Pushwoosh API calls.

## Returns

The unique Pushwoosh device identifier
