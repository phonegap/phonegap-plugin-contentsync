#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import "SSZipArchive.h"

@interface CDVContentSync : CDVPlugin <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate, SSZipArchiveDelegate> {
    @private CDVInvokedUrlCommand* _command;
}
@property (nonatomic) NSURLSession* session;
@property (nonatomic) NSURLSessionDownloadTask *downloadTask;
- (void) sync:(CDVInvokedUrlCommand*)command;

@end
