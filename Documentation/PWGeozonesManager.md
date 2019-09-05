
# <a name="heading"></a>class PWGeozonesManager : NSObject  

## Members  

<table>
	<tr>
		<td><a href="#1a830d5f66c2b73dc6e5fe4e14ff98041f">@property BOOL enabled</a></td>
	</tr>
	<tr>
		<td><a href="#1ad4095a386eda8589144936ba627f7b6c">@property id&lt;PWGeozonesDelegate&gt; delegate</a></td>
	</tr>
	<tr>
		<td><a href="#1ae326ce30b7c6c4eded1b4c06c886e6c7">+ (instancetype)sharedManager</a></td>
	</tr>
	<tr>
		<td><a href="#1a94634dda3df6dc88f78e8ce4a8cab8c9">- (void)startLocationTracking</a></td>
	</tr>
	<tr>
		<td><a href="#1ab3f706ee6f61ea8c341de968225f1b53">- (void)stopLocationTracking</a></td>
	</tr>
	<tr>
		<td><a href="#1aaa89ca54aa0fbd55f63b6d008eab405e">- (void)sendLocation:(CLLocation *)location</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a830d5f66c2b73dc6e5fe4e14ff98041f"></a>@property BOOL enabled  
Indicates that location tracking has started. 

----------  
  

#### <a name="1ad4095a386eda8589144936ba627f7b6c"></a>@property id&lt;PWGeozonesDelegate&gt; delegate  
Delegate that would receive the information about events for geozones manager. 

----------  
  

#### <a name="1ae326ce30b7c6c4eded1b4c06c886e6c7"></a>+ (instancetype)sharedManager  
A singleton object that represents the geozones manager. 

----------  
  

#### <a name="1a94634dda3df6dc88f78e8ce4a8cab8c9"></a>- (void)startLocationTracking  
Starts location tracking. 

----------  
  

#### <a name="1ab3f706ee6f61ea8c341de968225f1b53"></a>- (void)stopLocationTracking  
Stops location tracking. 

----------  
  

#### <a name="1aaa89ca54aa0fbd55f63b6d008eab405e"></a>- (void)sendLocation:(CLLocation \*)location  
Explicitly sends geolocation to the server for GeoFencing push technology. Also called internally in startLocationTracking and stopLocationTracking functions.<br/><br/><br/><strong>Parameters</strong><br/>
<table>
	<tr>
		<td><strong>location</strong></td>
		<td>Location to be sent. </td>
	</tr>
</table>
