#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface CDVContentSync : CDVPlugin <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate> {
    @private CDVInvokedUrlCommand* _command;
}
@property (nonatomic) NSURLSession* session;
@property (nonatomic) NSURLSessionDownloadTask *downloadTask;
- (void) sync:(CDVInvokedUrlCommand*)command;

@end
