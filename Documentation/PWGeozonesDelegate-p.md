
# <a name="heading"></a>protocol PWGeozonesDelegate&lt;NSObject&gt;  

## Members  

<table>
	<tr>
		<td><a href="#1a087b38919d5a2b83f65a9a0d68e0b170">- (void)didStartLocationTrackingWithManager:(PWGeozonesManager *)geozonesManager</a></td>
	</tr>
	<tr>
		<td><a href="#1ab76f66f2ece02dfd0edffd793fcbb140">- (void)geozonesManager:(PWGeozonesManager *)geozonesManager startingLocationTrackingDidFail:(NSError *)error</a></td>
	</tr>
	<tr>
		<td><a href="#1a4950bc18057554a4b1d002d2ba837c85">- (void)geozonesManager:(PWGeozonesManager *)geozonesManager didSendLocation:(CLLocation *)location</a></td>
	</tr>
</table>


----------  
  

#### <a name="1a087b38919d5a2b83f65a9a0d68e0b170"></a>- (void)didStartLocationTrackingWithManager:(PWGeozonesManager \*)geozonesManager  
Tells the delegate that location tracking did start. 

----------  
  

#### <a name="1ab76f66f2ece02dfd0edffd793fcbb140"></a>- (void)geozonesManager:(PWGeozonesManager \*)geozonesManager startingLocationTrackingDidFail:(NSError \*)error  
Tells the delegate that location tracking did fail. 

----------  
  

#### <a name="1a4950bc18057554a4b1d002d2ba837c85"></a>- (void)geozonesManager:(PWGeozonesManager \*)geozonesManager didSendLocation:(CLLocation \*)location  
Tells the delegate that location was successfully sent. 