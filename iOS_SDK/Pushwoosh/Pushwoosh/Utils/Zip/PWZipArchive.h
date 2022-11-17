//
//  IAZipArchive.h
//

#import <Foundation/Foundation.h>

@class PWZipArchive;

@protocol PWZipArchiveDelegate <NSObject>

@optional
- (void) zipArchive:(PWZipArchive *) zipArchive errorWithMessage: (NSString*) msg;
- (BOOL) overWriteOperation: (NSString*) file;

@end

@interface PWZipArchive : NSObject

@property (nonatomic, weak) id <PWZipArchiveDelegate> delegate;

- (BOOL) createZipFile2:(NSString*) zipFile;
- (BOOL) createZipFile2:(NSString*) zipFile password:(NSString*) password;
- (BOOL) addFileToZip:(NSString*) file newname:(NSString*) newname;
- (BOOL) closeZipFile2;

- (BOOL) unzipOpenFile:(NSString*) zipFile;
- (BOOL) unzipOpenFile:(NSString*) zipFile password:(NSString*) password;
- (BOOL) unzipFileTo:(NSString*) path overWrite:(BOOL) overwrite;
- (BOOL) unzipCloseFile;

@end
