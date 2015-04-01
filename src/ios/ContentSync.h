#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import "SSZipArchive.h"

enum ProgressState {
    Stopped = 0,
    Downloading,
    Extracting,
    Complete
};
typedef NSUInteger ProgressState;

@interface ContentSyncTask: NSObject

@property (nonatomic) CDVInvokedUrlCommand* command;
@property (nonatomic) NSURLSessionDownloadTask* downloadTask;
@property (nonatomic) NSString* archivePath;

@end

@interface ContentSync : CDVPlugin <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate, SSZipArchiveDelegate>

@property (nonatomic) NSString* currentPath;
@property (nonatomic) NSMutableArray *syncTasks;
@property (nonatomic) NSURLSession* session;

- (void) sync:(CDVInvokedUrlCommand*)command;
- (void) cancel:(CDVInvokedUrlCommand*)command;

@end
