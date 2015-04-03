#import "ContentSync.h"


@implementation ContentSyncTask

- (ContentSyncTask *)init {
    self = (ContentSyncTask*)[super init];
    if(self) {
        self.downloadTask = nil;
        self.command = nil;
    }
    
    return self;
}
@end

@implementation ContentSync

- (void)pluginInitialize {
    self.session = [self backgroundSession];
}

- (void)sync:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* src = [command.arguments objectAtIndex:0];

    if(src != nil) {
        NSLog(@"Downloading and unzipping from %@", src);
        NSURL *downloadURL = [NSURL URLWithString:src];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL];
        
        // Setting headers
        NSDictionary *headers = [command argumentAtIndex:3 withDefault:nil andClass:[NSDictionary class]];
        if(headers != nil) {
            for (NSString* header in [headers allKeys]) {
                NSLog(@"Setting header %@ %@", header, [headers objectForKey:header]);
                [request addValue:[headers objectForKey:header] forHTTPHeaderField:header];
            }
        }
        
        if(!self.syncTasks) {
            self.syncTasks = [NSMutableArray arrayWithCapacity:1];
        }
        NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithRequest:request];
        
        ContentSyncTask* sData = [[ContentSyncTask alloc] init];
        
        sData.downloadTask = downloadTask;
        sData.command = command;
        
        [self.syncTasks addObject:sData];
        
        [downloadTask resume];
        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:[NSNumber numberWithInteger:0] forKey:@"progress"];
        [message setObject:[NSNumber numberWithInteger:Downloading] forKey:@"status"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Arg was null"];
    }
    
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)cancel:(CDVInvokedUrlCommand *)command {
    ContentSyncTask* sTask = [self findSyncDataByCallbackID:command.callbackId];
    if(sTask) {
        CDVPluginResult* pluginResult = nil;
        [[sTask downloadTask] cancel];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    }
}

- (ContentSyncTask *)findSyncDataByDownloadTask:(NSURLSessionDownloadTask*)downloadTask {
    for(ContentSyncTask* sTask in self.syncTasks) {
        if(sTask.downloadTask == downloadTask) {
            return sTask;
        }
    }
    return nil;
}

- (ContentSyncTask *)findSyncDataByPath {
    for(ContentSyncTask* sTask in self.syncTasks) {
        if([sTask.archivePath isEqualToString:[self currentPath]]) {
            return sTask;
        }
    }
    return nil;
}

- (ContentSyncTask *)findSyncDataByCallbackID:(NSString*)callbackId {
    for(ContentSyncTask* sTask in self.syncTasks) {
        if([sTask.command.callbackId isEqualToString:callbackId]) {
            return sTask;
        }
    }
    return nil;
}

- (void)URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
    CDVPluginResult* pluginResult = nil;
    
    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:downloadTask];
    
    if(sTask) {
        double progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
        //NSLog(@"DownloadTask: %@ progress: %lf callbackId: %@", downloadTask, progress, sTask.command.callbackId);
        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:[NSNumber numberWithInteger:((progress / 2) * 100)] forKey:@"progress"];
        [message setObject:[NSNumber numberWithInteger:Downloading] forKey:@"status"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    } else {
        NSLog(@"Could not find download task");
    }
}

- (void) URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask*)downloadTask didFinishDownloadingToURL:(NSURL *)downloadURL {
    
    __weak ContentSync* weakSelf = self;
    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:downloadTask];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *URLs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [URLs objectAtIndex:0];
    
    NSURL *originalURL = [[downloadTask originalRequest] URL];
    NSURL *sourceURL = [documentsDirectory URLByAppendingPathComponent:[originalURL lastPathComponent]];
    NSError *errorCopy;
    
    [fileManager removeItemAtURL:sourceURL error:NULL];
    BOOL success = [fileManager copyItemAtURL:downloadURL toURL:sourceURL error:&errorCopy];
    
    __block NSString* callbackId = sTask.command.callbackId;
    
    if(sTask) {
        [self.commandDelegate runInBackground:^{
            CDVPluginResult* pluginResult = nil;
            NSString* id = [sTask.command.arguments objectAtIndex:1];
            
            //NSLog(@"Download URL %@", downloadURL);
            @try {
                if(success) {
                    NSURL *extractURL = [documentsDirectory URLByAppendingPathComponent:id];
                    sTask.archivePath = [sourceURL path];
                    NSError *error;
                    NSString* type = [sTask.command.arguments objectAtIndex:2];
                    bool overwrite = ([type compare:@"replace"] ? YES : NO);
                    if(![SSZipArchive unzipFileAtPath:[sourceURL path] toDestination:[extractURL path] overwrite:overwrite password:nil error:&error delegate:weakSelf]) {
                        NSLog(@"Sync Failed - %@", [error localizedDescription]);
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Sync Failed"];
                    }
                } else {
                    NSLog(@"Sync Failed - Copy Failed - %@", [errorCopy localizedDescription]);
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Sync Failed"];
                }
            }
            @catch (NSException *exception) {
                NSLog(@"Sync Failed - %@", [exception debugDescription]);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Sync Failed"];
            }
            [pluginResult setKeepCallbackAsBool:YES];
            
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }];
    }
}

- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo {
    self.currentPath = path;
}

- (void) zipArchiveProgressEvent:(NSInteger)loaded total:(NSInteger)total {
    ContentSyncTask* sTask = [self findSyncDataByPath];
    if(sTask) {
        //NSLog(@"Extracting %ld / %ld", (long)loaded, (long)total);
        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:[NSNumber numberWithInteger:((0.5 + ( ((double)loaded / (double)total) ) / 2) * 100)] forKey:@"progress"];
        [message setObject:[NSNumber numberWithInteger:Extracting] forKey:@"status"];
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    }
}
// TODO GET RID OF THIS
- (BOOL) copyCordovaAssets:(NSString*)unzippedPath {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *errorCopy;
    NSArray* cordovaAssets = [NSArray arrayWithObjects:@"cordova.js",@"cordova_plugins.js",@"plugins", nil];
    NSURL* destinationURL = [NSURL fileURLWithPath:unzippedPath];
    NSString* suffix = @"/www";
    
    if([fileManager fileExistsAtPath:[unzippedPath stringByAppendingString:suffix]]) {
        destinationURL = [destinationURL URLByAppendingPathComponent:suffix];
        NSLog(@"Found %@ folder. Will copy Cordova assets to it.", suffix);
    }
    
    for(NSString* asset in cordovaAssets) {
        NSURL* assetSourceURL = [NSURL fileURLWithPath:[[self commandDelegate] pathForResource:asset]];
        NSURL* assetDestinationURL = [destinationURL URLByAppendingPathComponent:[assetSourceURL lastPathComponent]];
        [fileManager removeItemAtURL:assetDestinationURL error:NULL];
        BOOL success = [fileManager copyItemAtURL:assetSourceURL toURL:assetDestinationURL error:&errorCopy];
        
        if(!success) {
            return NO;
        }
    }
    
    return YES;
}

- (void) zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath {
    NSLog(@"unzipped path %@", unzippedPath);
    ContentSyncTask* sTask = [self findSyncDataByPath];
    if(sTask) {
        // FIXME: GET RID OF THIS SHIT / Copying cordova assets
        if([[[sTask command] argumentAtIndex:4 withDefault:@(NO)] boolValue] == YES) {
            NSLog(@"Copying Cordova Assets to %@ as requested", unzippedPath);
            if(![self copyCordovaAssets:unzippedPath]) {
                NSLog(@"Something fucked up!");
            };
        }
        // XXX this is to match the Android implementation
        
        NSMutableDictionary* message = nil;
        CDVPluginResult* pluginResult = nil;
        message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:[NSNumber numberWithInteger:100] forKey:@"progress"];
        [message setObject:[NSNumber numberWithInteger:Complete] forKey:@"status"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        
        message = [NSMutableDictionary dictionaryWithCapacity:1];
        [message setObject:unzippedPath forKey:@"localPath"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [pluginResult setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        [[self syncTasks] removeObject:sTask];
    }
}

- (void) URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task didCompleteWithError:(NSError *)error {
    
    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:(NSURLSessionDownloadTask*)task];
    
    if(sTask) {
        CDVPluginResult* pluginResult = nil;
        
        if(error == nil) {
            NSLog(@"Task: %@ completed successfully", task);
            double progress = (double)task.countOfBytesReceived / (double)task.countOfBytesExpectedToReceive;
            NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
            [message setObject:[NSNumber numberWithDouble:((progress / 2) * 100)] forKey:@"progress"];
            [message setObject:[NSNumber numberWithInt:Downloading] forKey:@"status"];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        } else {
            NSLog(@"Task: %@ completed with error: %@", task, [error localizedDescription]);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
//    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
//    
//    [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_command.callbackId];
    NSLog(@"All tasks are finished");
}

- (NSURLSession*) backgroundSession {
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >=8.0f)
        {
            configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.example.apple-samplecode.SimpleBackgroundTransfer.BackgroundSession"];
        }
        else
        {
            configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:@"com.example.apple-samplecode.SimpleBackgroundTransfer.BackgroundSession"];
        }
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    });
    return session;
}

@end
