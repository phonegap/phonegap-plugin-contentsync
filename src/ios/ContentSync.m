#import "ContentSync.h"

@implementation CDVContentSync

- (void)pluginInitialize {
    self.session = [self backgroundSession];
}

- (void)sync:(CDVInvokedUrlCommand*)command
{
    self->_command = command;
    CDVPluginResult* pluginResult = nil;
    NSString* src = [command.arguments objectAtIndex:0];

    if(src != nil) {
        NSLog(@"Downloading and unzipping from %@", src);
        NSURL *downloadURL = [NSURL URLWithString:src];
        NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
        self.downloadTask = [self.session downloadTaskWithRequest:request];
        [self.downloadTask resume];
        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
        [message setObject:[NSNumber numberWithDouble:0.00] forKey:@"progress"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Arg was null"];
    }
    
    [pluginResult setKeepCallbackAsBool:YES];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
    CDVPluginResult* pluginResult = nil;
    
    if(downloadTask == self.downloadTask) {
        double progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
        NSLog(@"DownloadTask: %@ progress: %lf callbackId: %@", downloadTask, progress, self->_command.callbackId);
        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
        [message setObject:[NSNumber numberWithDouble:progress] forKey:@"progress"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    }
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_command.callbackId];
}

- (void) URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask*)downloadTask didFinishDownloadingToURL:(NSURL *)downloadURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *URLs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [URLs objectAtIndex:0];
    
    NSURL *originalURL = [[downloadTask originalRequest] URL];
    NSURL *destinationURL = [documentsDirectory URLByAppendingPathComponent:[originalURL lastPathComponent]];
    NSError *errorCopy;
    
    [fileManager removeItemAtURL:destinationURL error:NULL];
    
    BOOL success = [fileManager copyItemAtURL:downloadURL toURL:destinationURL error:&errorCopy];
    
    if(success) {
        NSLog(@"Download complete at %@!", destinationURL);
    } else {
        NSLog(@"Download failed!");
    }
}

- (void) URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task didCompleteWithError:(NSError *)error {
    CDVPluginResult* pluginResult = nil;
    [pluginResult setKeepCallbackAsBool:YES];
    
    if(error == nil) {
        NSLog(@"Task: %@ completed successfully", task);
        double progress = (double)task.countOfBytesReceived / (double)task.countOfBytesExpectedToReceive;
        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
        [message setObject:[NSNumber numberWithDouble:progress] forKey:@"progress"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    } else {
        NSLog(@"Task: %@ completed with error: %@", task, [error localizedDescription]);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_command.callbackId];
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_command.callbackId];
    NSLog(@"All tasks are finished");
}

- (NSURLSession*) backgroundSession {
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.example.apple-samplecode.SimpleBackgroundTransfer.BackgroundSession"];
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    });
    return session;
}

@end
