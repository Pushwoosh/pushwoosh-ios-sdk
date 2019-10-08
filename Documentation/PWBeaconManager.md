
# <a name="heading"></a>class PWBeaconManager : NSObject  
Pushwoosh iBeacon tracking manager.<br/>One of the following keys shoud be added to Info.plist for using iBeacon functionality:<br/>NSLocationAlwaysUsageDescription – if you would like your application to react to beacons while running in the background and when it’s closed; NSLocationWhenInUseUsageDescription – if you would like your app to look for beacons only then it’s running in the foreground. 
## Members  

<table>
	<tr>
		<td><a href="#1aed6b6ebe81dbbb0f5e667de212f45b97">+ (instancetype)sharedManager</a></td>
	</tr>
	<tr>
		<td><a href="#1a0eb05c7897a3fd256a5fe06bd31dc71f">- (void)startBeaconTracking</a></td>
	</tr>
	<tr>
		<td><a href="#1a26912658ca27f1e97009191559650b08">- (void)stopBeaconTracking</a></td>
	</tr>
</table>


----------  
  

#### <a name="1aed6b6ebe81dbbb0f5e667de212f45b97"></a>+ (instancetype)sharedManager  


----------  
  

#### <a name="1a0eb05c7897a3fd256a5fe06bd31dc71f"></a>- (void)startBeaconTracking  
Start iBeacon tracking. 

----------  
  

#### <a name="1a26912658ca27f1e97009191559650b08"></a>- (void)stopBeaconTracking  
Stops iBeacon tracking 