# ``Pushwoosh/disableReverseProxy()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Disables reverse proxy configuration.

## Overview

Reverts API requests to use default Pushwoosh server URLs after previously configuring a reverse proxy with ``setReverseProxy(_:)``.

## Use Cases

- Switching between enterprise and standard environments
- Debugging proxy issues
- Testing direct connectivity

## Example

Toggle proxy based on network:

```swift
func updateNetworkConfiguration(useProxy: Bool) {
    if useProxy {
        Pushwoosh.configure.setReverseProxy("https://proxy.company.com")
    } else {
        Pushwoosh.configure.disableReverseProxy()
    }
}
```

Disable proxy for debugging:

```swift
func enableDirectConnection() {
    Pushwoosh.configure.disableReverseProxy()

    Pushwoosh.debug.setLogLevel(.verbose)
}
```

## See Also

- ``Pushwoosh/setReverseProxy(_:)``
