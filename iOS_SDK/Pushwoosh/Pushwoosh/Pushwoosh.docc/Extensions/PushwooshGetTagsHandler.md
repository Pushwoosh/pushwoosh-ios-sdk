# ``PushwooshGetTagsHandler``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Completion handler called when tags are successfully retrieved from the server.

## Discussion

This closure is called when the `getTags:onFailure:` method successfully retrieves device tags from Pushwoosh servers.

The handler receives a dictionary where keys are tag names and values are the corresponding tag values. The dictionary can contain various types including strings, numbers, booleans, dates, and arrays.

