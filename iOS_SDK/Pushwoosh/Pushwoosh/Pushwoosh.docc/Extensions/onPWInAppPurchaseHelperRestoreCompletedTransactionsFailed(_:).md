# ``PWPurchaseDelegate/onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that an error occurred while restoring transactions.

## Discussion

This method is called when the restore purchases operation fails. Use this to inform the user that their purchases could not be restored and provide appropriate error handling.

## Parameters

- error: Error describing why the restore operation failed
