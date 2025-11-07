# ``Pushwoosh/stopServerCommunication()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops communication with Pushwoosh server.

## Discussion

Temporarily disables network communication with Pushwoosh servers. Use this to pause SDK operations without unregistering the device.

All pending operations will be queued and sent when communication resumes via `startServerCommunication()`.
