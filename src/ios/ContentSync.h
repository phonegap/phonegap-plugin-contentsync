#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import "SSZipArchive.h"

@interface CDVContentSyncTask: NSObject

@property (nonatomic) CDVInvokedUrlCommand* command;
@property (nonatomic) NSURLSessionDownloadTask* downloadTask;
@property (nonatomic) NSString* archivePath;

@end

@interface CDVContentSync : CDVPlugin <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate, SSZipArchiveDelegate>

@property (nonatomic) NSString* currentPath;
@property (nonatomic) NSMutableArray *syncTasks;
@property (nonatomic) NSURLSession* session;
- (void) sync:(CDVInvokedUrlCommand*)command;

@end
