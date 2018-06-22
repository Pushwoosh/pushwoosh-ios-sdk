
# PWGDPRManager

| Header | [PWGDPRManager.h](../Framework/Pushwoosh.framework/Versions/A/Headers/PWGDPRManager.h) |

| ------ | ---------------------------------------------------------------------------------------- |

Offers access to the singleton-instance of the manager responsible for channels management required by GDPR.

## Summary

[available](#available) *__property__*
[communicationEnabled](#communicationenabled) *__property__*
[deviceDataRemoved](#devicedataremoved) *__property__*

[+ sharedManager](#sharedmanager)

[- setCommunicationEnabled:completion:](#setcommunicationenabledcompletion)
[- removeAllDeviceDataWithCompletion:](#removealldevicedatawithcompletion)
[- showGDPRConsentUI:](#showgdprconsentui)
[- showGDPRDeletionUI:](#showgdprdeletionui)

## Properties

### available

Indicates availability of the GDPR compliance solution.


```objc
@property (nonatomic, readonly, getter=isAvailable) BOOL available;
```
---

### communicationEnabled

Gets the current status of communication availability. Returns **true** if communication with Pushwoosh servers is enabled and **false** if not.


```objc
@property (nonatomic, readonly, getter=isCommunicationEnabled) BOOL communicationEnabled;
```
---

### deviceDataRemoved

Returns **true** if device data was removed from Pushwoosh servers and **false** if not.


```objc
@property (nonatomic, readonly, getter=isDeviceDataRemoved) BOOL deviceDataRemoved;
```
---


## Class Methods


### sharedManager

A singleton object that represents the GDPR manager

```objc
+ (instancetype)sharedManager;
```

---


## Instance Methods

### setCommunicationEnabled:completion:

Enable/disable all communication with Pushwoosh. Enabled by default.

```objc
- (void)setCommunicationEnabled:(BOOL)enabled completion:(void (^)(NSError *error))completion;
```
---

### removeAllDeviceDataWithCompletion:

Removes all device data from Pushwoosh and stops all interactions and communication permanently.

```objc
- (void)removeAllDeviceDataWithCompletion:(void (^)(NSError *error))completion;
```
---

### showGDPRConsentUI:

Shows GDPR consent form. This method triggers our system GDPRConsent Event and shows the Consent Form Rich Media. More info can be found [here](https://www.pushwoosh.com/docs/the-gdpr-compliance#section-consent-form)

```objc
- (void)showGDPRConsentUI;
```
---

### showGDPRDeletionUI:

Shows GDPR deletion form. This method triggers a system GDPRDeletion Event and displays the Deletion Form Rich Media. More information is available [here](https://www.pushwoosh.com/docs/the-gdpr-compliance#section-deletion-form)

```objc
- (void)showGDPRDeletionUI;
```
---
