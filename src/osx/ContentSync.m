/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "ContentSync.h"

@implementation ContentSyncTask

- (ContentSyncTask*) init {
    self = (ContentSyncTask*) [super init];
    if (self) {
        self.appId = nil;
        self.downloadTask = nil;
        self.command = nil;
        self.archivePath = nil;
        self.progress = 0;
        self.extractArchive = YES;
    }

    return self;
}
@end

@implementation ContentSync

- (CDVPlugin*) initWithWebView:(WebView*) theWebView {
    [NSURLProtocol registerClass:[NSURLProtocolNoCache class]];
    return self;
}

- (CDVPluginResult*) preparePluginResult:(NSInteger) progress status:(NSInteger) status {
    CDVPluginResult* pluginResult = nil;

    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
    message[@"progress"] = @(progress);
    message[@"status"] = @(status);
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];

    return pluginResult;
}

/**
 * Returns the _applicationStorageDirectory_ similar to the one of the file plugin
 */
+ (NSURL*) getStorageDirectory {
    NSError* error;
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* supportDir = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    if (supportDir == nil) {
        NSLog(@"unable to get support directory: %@", error);
        return nil;
    }

    NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSURL *dirPath = [supportDir URLByAppendingPathComponent:bundleID];

    if (![fm fileExistsAtPath:dirPath.path]) {
        if (![fm createDirectoryAtURL:dirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"unable to create support directory: %@", error);
            return nil;
        }
    }
    return dirPath;
}

- (void) sync:(CDVInvokedUrlCommand*) command __unused {
    NSString* src = [command argumentAtIndex:0 withDefault:nil];
    // checking if 'src' is valid (CB-9918)
    if ([src isKindOfClass:[WebUndefined class]]) {
        src = nil;
    }

    NSString* type = [command argumentAtIndex:2];
    BOOL local = [type isEqualToString:@"local"];

    if (local) {
        NSString* appId = [command argumentAtIndex:1];
        NSLog(@"Requesting local copy of %@", appId);
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSURL* storageDirectory = [ContentSync getStorageDirectory];
        NSURL* appPath = [storageDirectory URLByAppendingPathComponent:appId];

        if ([fileManager fileExistsAtPath:[appPath path]]) {
            NSLog(@"Found local copy %@", [appPath path]);
            CDVPluginResult* pluginResult = nil;

            NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
            message[@"localPath"] = [appPath path];
            message[@"cached"] = @"true";
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
        BOOL copyCordovaAssets = [[command argumentAtIndex:4 withDefault:@(NO)] boolValue];
        BOOL copyRootApp = [[command argumentAtIndex:5 withDefault:@(NO)] boolValue];

        if (copyRootApp || copyCordovaAssets) {
            CDVPluginResult* pluginResult = nil;
            NSError* error = nil;

            NSLog(@"Creating app directory %@", [appPath path]);
            [fileManager createDirectoryAtPath:[appPath path] withIntermediateDirectories:YES attributes:nil error:&error];

            NSError* errorSetting = nil;
            BOOL success = [appPath setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&errorSetting];

            if (!success) {
                NSLog(@"WARNING: %@ might be backed up to iCloud!", [appPath path]);
            }

            if (error != nil) {
                [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:LOCAL_ERR];
                NSLog(@"%@", [error localizedDescription]);
            } else {
                if (copyRootApp) {
                    NSLog(@"Copying Root App");
                    [self copyCordovaAssets:[appPath path] copyRootApp:YES];
                } else {
                    NSLog(@"Copying Cordova Assets");
                    [self copyCordovaAssets:[appPath path] copyRootApp:NO];
                }
                if (src == nil) {
                    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
                    message[@"localPath"] = [appPath path];
                    message[@"cached"] = @"true";
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                    return;
                }
            }
        }
    }

    __weak ContentSync* weakSelf = self;

    [self.commandDelegate runInBackground:^{
        [weakSelf startDownload:command extractArchive:YES];
    }];
}

- (void) download:(CDVInvokedUrlCommand*) command __unused {
    __weak ContentSync* weakSelf = self;

    [self.commandDelegate runInBackground:^{
        [weakSelf startDownload:command extractArchive:NO];
    }];
}

- (BOOL) isZipArchive:(NSString*) filePath {
    NSFileHandle* fh = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSData* data = [fh readDataOfLength:4];
    if ([data length] == 4) {
        const char* bytes = [data bytes];
        if (bytes[0] == 'P' && bytes[1] == 'K' && bytes[2] == 3 && bytes[3] == 4) {
            return YES;
        }
    }
    return NO;
}

- (void) startDownload:(CDVInvokedUrlCommand*) command extractArchive:(BOOL) extractArchive {

    CDVPluginResult* pluginResult = nil;
    NSString* src = [command argumentAtIndex:0 withDefault:nil];
    NSString* appId = [command argumentAtIndex:1];
    NSNumber* timeout = [command argumentAtIndex:6 withDefault:@15.0];

    self.session = [self backgroundSession:timeout];

    // checking if 'src' is valid (CB-9918)
    if ([src isKindOfClass:[WebUndefined class]]) {
        src = nil;
    }
    NSURL* srcURL = [NSURL URLWithString:src];

    if (srcURL && srcURL.scheme && srcURL.host) {

        BOOL trustHost = [[command argumentAtIndex:7 withDefault:@(NO)] boolValue];

        if (!self.trustedHosts) {
            self.trustedHosts = [NSMutableArray arrayWithCapacity:1];
        }

        if (trustHost) {
            NSLog(@"WARNING: Trusting host %@", [srcURL host]);
            [self.trustedHosts addObject:[srcURL host]];
        }

        NSLog(@"startDownload from %@", src);
        NSURL* downloadURL = [NSURL URLWithString:src];

        // downloadURL is nil if malformed URL
        if (downloadURL == nil) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:INVALID_URL_ERR];
        } else {
            NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:downloadURL];
            request.timeoutInterval = 15.0;
            // Setting headers
            NSDictionary* headers = [command argumentAtIndex:3 withDefault:nil andClass:[NSDictionary class]];
            if (headers != nil) {
                for (NSString* header in [headers allKeys]) {
                    NSLog(@"Setting header %@ %@", header, headers[header]);
                    [request addValue:headers[header] forHTTPHeaderField:header];
                }
            }

            if (!self.syncTasks) {
                self.syncTasks = [NSMutableArray arrayWithCapacity:1];
            }
            NSURLSessionDownloadTask* downloadTask = [self.session downloadTaskWithRequest:request];

            ContentSyncTask* sData = [[ContentSyncTask alloc] init];

            sData.appId = appId ? appId : [srcURL lastPathComponent];
            sData.downloadTask = downloadTask;
            sData.command = command;
            sData.progress = 0;
            sData.extractArchive = extractArchive;

            [self.syncTasks addObject:sData];

            [downloadTask resume];

            pluginResult = [self preparePluginResult:sData.progress status:Downloading];
        }

    } else {
        NSLog(@"Invalid src URL %@", src);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:INVALID_URL_ERR];
    }

    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

- (void) cancel:(CDVInvokedUrlCommand*) command __unused {
    NSString* appId = [command argumentAtIndex:0 withDefault:nil];
    NSLog(@"Cancelling download %@", appId);
    if (appId) {
        ContentSyncTask* sTask = [self findSyncDataByAppId:appId];
        if (sTask) {
            CDVPluginResult* pluginResult = nil;
            [[sTask downloadTask] cancel];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }
}

- (ContentSyncTask*) findSyncDataByDownloadTask:(NSURLSessionDownloadTask*) downloadTask {
    for (ContentSyncTask* sTask in self.syncTasks) {
        if (sTask.downloadTask == downloadTask) {
            return sTask;
        }
    }
    return nil;
}

- (ContentSyncTask*) findSyncDataByPath {
    for (ContentSyncTask* sTask in self.syncTasks) {
        if ([sTask.archivePath isEqualToString:[self currentPath]]) {
            return sTask;
        }
    }
    return nil;
}

- (ContentSyncTask*) findSyncDataByAppId:(NSString*) appId {
    for (ContentSyncTask* sTask in self.syncTasks) {
        if ([sTask.appId isEqualToString:appId]) {
            return sTask;
        }
    }
    return nil;
}

/**
 * If implemented, when a connection level authentication challenge
 * has occurred, this delegate will be given the opportunity to
 * provide authentication credentials to the underlying
 * connection. Some types of authentication will apply to more than
 * one request on a given connection to a server (SSL Server Trust
 * challenges).  If this delegate message is not implemented, the
 * behavior will be to use the default handling, which may involve user
 * interaction.
 */
- (void) URLSession:(NSURLSession*) session
didReceiveChallenge:(NSURLAuthenticationChallenge*) challenge
  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential*)) completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSLog(@"Received challenge for host %@", challenge.protectionSpace.host);
        if ([self.trustedHosts containsObject:challenge.protectionSpace.host]) {
            NSURLCredential* credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        } else {
            completionHandler(NSURLSessionAuthChallengeUseCredential, nil);
//            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
    }
}

/**
 * Sent periodically to notify the delegate of download progress.
 */
- (void)       URLSession:(NSURLSession*) session
             downloadTask:(NSURLSessionDownloadTask*) downloadTask
             didWriteData:(int64_t) bytesWritten
        totalBytesWritten:(int64_t) totalBytesWritten
totalBytesExpectedToWrite:(int64_t) totalBytesExpectedToWrite {

    CDVPluginResult* pluginResult = nil;

    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:downloadTask];

    if (sTask) {
        double progress = (double) totalBytesWritten / (double) totalBytesExpectedToWrite;
        //NSLog(@"DownloadTask: %@ progress: %lf callbackId: %@", downloadTask, progress, sTask.command.callbackId);
        progress = (sTask.extractArchive ? ((progress / 2) * 100) : progress * 100);
        sTask.progress = (NSInteger) progress;
        pluginResult = [self preparePluginResult:sTask.progress status:Downloading];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    } else {
        NSLog(@"Could not find download task");
    }
}

/**
 * Sent when a download task that has completed a download.  The delegate should
 * copy or move the file at the given location to a new location as it will be
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
- (void)       URLSession:(NSURLSession*) session
             downloadTask:(NSURLSessionDownloadTask*) downloadTask
didFinishDownloadingToURL:(NSURL*) downloadURL {

    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSURL* storageDirectory = [ContentSync getStorageDirectory];

    NSURL* originalURL = [[downloadTask originalRequest] URL];
    NSURL* sourceURL = [storageDirectory URLByAppendingPathComponent:[originalURL lastPathComponent]];
    NSError* errorCopy;

    [fileManager removeItemAtURL:sourceURL error:NULL];
    BOOL success = [fileManager copyItemAtURL:downloadURL toURL:sourceURL error:&errorCopy];

    if (success) {
        ContentSyncTask* sTask = [self findSyncDataByDownloadTask:downloadTask];
        if (sTask) {
            sTask.archivePath = [sourceURL path];
            if (sTask.extractArchive && [self isZipArchive:[sourceURL path]]) {
                // FIXME there is probably a better way to do this
                NSURL* extractURL = [storageDirectory URLByAppendingPathComponent:[sTask appId]];
                NSString* type = [sTask.command argumentAtIndex:2 withDefault:@"replace"];

                // copy root app right before we extract
                if ([[[sTask command] argumentAtIndex:5 withDefault:@(NO)] boolValue]) {
                    NSLog(@"Copying Cordova Root App to %@ as requested", [extractURL path]);
                    if (![self copyCordovaAssets:[extractURL path] copyRootApp:YES]) {
                        NSLog(@"Error copying Cordova Root App");
                    };
                }
                CDVInvokedUrlCommand* command = [CDVInvokedUrlCommand commandFromJson:@[sTask.command.callbackId, @"Zip", @"unzip", [@[[sourceURL absoluteString], [extractURL absoluteString], type] mutableCopy]]];
                [self unzip:command];

            } else {
                NSURL* srcURL = [NSURL fileURLWithPath:[sTask archivePath]];
                NSURL* dstURL = [storageDirectory URLByAppendingPathComponent:[sTask appId]];
                NSError* error = nil;
                success = [fileManager createDirectoryAtURL:[dstURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
                if (success) {
                    NSError* errorMove;
                    NSLog(@"Moving %@ to %@", [srcURL path], [dstURL path]);
                    success = [fileManager moveItemAtURL:srcURL toURL:dstURL error:&errorMove];
                    if (success) {
                        sTask.archivePath = [dstURL path];
                    } else {
                        NSLog(@"Error Moving :-( but this can be non FATAL %@", [errorMove description]);
                    }
                    sTask.extractArchive = NO;
                } else {
                    NSLog(@"Unable to create ID :-[ %@", [error description]);
                }
            }
        }
    } else {
        NSLog(@"Sync Failed - Copy Failed - %@", [errorCopy localizedDescription]);
    }
}

/**
 * Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)  URLSession:(NSURLSession*) session
                task:(NSURLSessionTask*) task
didCompleteWithError:(NSError*) error {

    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:(NSURLSessionDownloadTask*) task];

    if (sTask) {
        CDVPluginResult* pluginResult = nil;

        if (error == nil) {
            if([(NSHTTPURLResponse*)[task response] statusCode] != 200) {
                NSLog(@"Task: %@ completed with HTTP Error Code: %ld", task, [(NSHTTPURLResponse*)[task response] statusCode]);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:CONNECTION_ERR];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if([fileManager fileExistsAtPath:[sTask archivePath]]) {
                    NSLog(@"Deleting archive. It's probably an HTTP Error Page anyways");
                    [fileManager removeItemAtPath:[sTask archivePath] error:NULL];
                }
            } else {
                double progress = (double)task.countOfBytesReceived / (double)task.countOfBytesExpectedToReceive;
                NSLog(@"Task: %@ completed successfully", sTask.archivePath);
                if(sTask.extractArchive) {
                    progress = ((progress / 2) * 100);
                    pluginResult = [self preparePluginResult:(NSInteger) progress status:Downloading];
                    [pluginResult setKeepCallbackAsBool:YES];
                }
                else {
                    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
                    message[@"status"] = @(Complete);
                    message[@"localPath"] = [sTask archivePath];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
                    [[self syncTasks] removeObject:sTask];
                }
            }
        } else {
            NSLog(@"Task: %@ completed with error: %@", task, [error localizedDescription]);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:CONNECTION_ERR];
        }
        if (![[error localizedDescription] isEqual:@"cancelled"]) {
            [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        }
    }
}

/**
 * If an application has received an
 * -application:handleEventsForBackgroundURLSession:completionHandler:
 * message, the session delegate will receive this message to indicate
 * that all messages previously enqueued for this session have been
 * delivered.  At this time it is safe to invoke the previously stored
 * completion handler, or to begin any internal updates that will
 * result in invoking the completion handler.
 */
- (void) URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession*) session {
    NSLog(@"All tasks are finished");
}

- (void) unzip:(CDVInvokedUrlCommand*) command {
    __weak ContentSync* weakSelf = self;
    __block NSString* callbackId = command.callbackId;

    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;

        NSURL* sourceURL = [NSURL URLWithString:[command argumentAtIndex:0]];
        NSURL* destinationURL = [NSURL URLWithString:[command argumentAtIndex:1]];
        NSString* type = [command argumentAtIndex:2 withDefault:@"replace"];
        BOOL replace = [type isEqualToString:@"replace"];

        NSFileManager* fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:[destinationURL path]] && replace) {
            NSLog(@"%@ already exists. Deleting it since type is set to `replace`", [destinationURL path]);
            [fileManager removeItemAtURL:destinationURL error:NULL];
        }

        @try {
            NSError* error;
            if (![SSZipArchive unzipFileAtPath:[sourceURL path] toDestination:[destinationURL path] overwrite:YES password:nil error:&error delegate:weakSelf]) {
                NSLog(@"%@ - %@", @"Error occurred during unzipping", [error localizedDescription]);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:UNZIP_ERR];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                // clean up zip archive
                [fileManager removeItemAtURL:sourceURL error:NULL];

            }
        }
        @catch (NSException* exception) {
            NSLog(@"%@ - %@", @"Error occurred during unzipping", [exception debugDescription]);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:UNZIP_ERR];
        }
        [pluginResult setKeepCallbackAsBool:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        });
    }];
}

- (void) zipArchiveWillUnzipArchiveAtPath:(NSString*) path zipInfo:(unz_global_info) zipInfo {
    self.currentPath = path;
}

- (void) zipArchiveProgressEvent:(NSInteger) loaded total:(NSInteger) total {
    ContentSyncTask* sTask = [self findSyncDataByPath];
    if (sTask) {
        //NSLog(@"Extracting %ld / %ld", (long)loaded, (long)total);
        double progress = ((double) loaded / (double) total);
        progress = (sTask.extractArchive ? ((0.5 + progress / 2) * 100) : progress * 100);
        CDVPluginResult* pluginResult = [self preparePluginResult:(NSInteger) progress status:Extracting];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    }
}

- (void) zipArchiveDidUnzipArchiveAtPath:(NSString*) path zipInfo:(unz_global_info) zipInfo unzippedPath:(NSString*) unzippedPath {
    NSLog(@"unzipped path %@", unzippedPath);
    ContentSyncTask* sTask = [self findSyncDataByPath];
    if (sTask) {
        BOOL copyCordovaAssets = [[[sTask command] argumentAtIndex:4 withDefault:@(NO)] boolValue];
        BOOL copyRootApp = [[[sTask command] argumentAtIndex:5 withDefault:@(NO)] boolValue];
        if (copyRootApp || copyCordovaAssets) {
            NSLog(@"Copying %@ to %@ as requested", copyCordovaAssets ? @"Cordova Assets" : @"Root App", unzippedPath);
            if (![self copyCordovaAssets:unzippedPath copyRootApp:copyRootApp]) {
                NSLog(@"Error copying assets");
            };
        }
        // XXX this is to match the Android implementation
        CDVPluginResult* pluginResult = [self preparePluginResult:100 status:Complete];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        // END

        // Do not BACK UP folder to iCloud
        NSURL* appURL = [NSURL fileURLWithPath:path];
        NSError* error = nil;
        BOOL success = [appURL setResourceValue:@YES
                                         forKey:NSURLIsExcludedFromBackupKey error:&error];
        if (!success) {
            NSLog(@"Error excluding %@ from backup %@", [appURL lastPathComponent], error);
        }

        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        message[@"localPath"] = unzippedPath;
        message[@"cached"] = @"false";
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [pluginResult setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        [[self syncTasks] removeObject:sTask];
    }
}

// TODO GET RID OF THIS
- (BOOL) copyCordovaAssets:(NSString*) unzippedPath copyRootApp:(BOOL) copyRootApp {
    NSError* errorCopy;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSURL* destinationURL = [NSURL fileURLWithPath:unzippedPath];

    if (copyRootApp) {
        // we use cordova.js as a way to find the root www/
        NSString* root = [[[self commandDelegate] pathForResource:@"cordova.js"] stringByDeletingLastPathComponent];

        NSURL* sourceURL = [NSURL fileURLWithPath:root];
        [fileManager removeItemAtURL:destinationURL error:NULL];
        BOOL success = [fileManager copyItemAtURL:sourceURL toURL:destinationURL error:&errorCopy];
        return success;
    }

    NSArray* cordovaAssets = @[@"cordova.js", @"cordova_plugins.js", @"plugins"];
    NSString* suffix = @"/www";

    if ([fileManager fileExistsAtPath:[unzippedPath stringByAppendingString:suffix]]) {
        destinationURL = [destinationURL URLByAppendingPathComponent:suffix];
        NSLog(@"Found %@ folder. Will copy Cordova assets to it.", suffix);
    }

    for (NSString* asset in cordovaAssets) {
        NSURL* assetSourceURL = [NSURL fileURLWithPath:[[self commandDelegate] pathForResource:asset]];
        NSURL* assetDestinationURL = [destinationURL URLByAppendingPathComponent:[assetSourceURL lastPathComponent]];
        [fileManager removeItemAtURL:assetDestinationURL error:NULL];
        BOOL success = [fileManager copyItemAtURL:assetSourceURL toURL:assetDestinationURL error:&errorCopy];

        if (!success) {
            return NO;
        }
    }

    return YES;
}

- (NSURLSession*) backgroundSession:(NSNumber*) timeout {
    NSString* sessionId = [NSString stringWithFormat:@"%@-download-task", [[NSBundle mainBundle] bundleIdentifier]];

    static NSURLSession* session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration* configuration;
#ifdef __MAC_10_10
        #pragma clang diagnostic push
        #pragma ide diagnostic ignored "UnavailableInDeploymentTarget"
        configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionId];
        #pragma clang diagnostic pop
#else
        configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:sessionId];
#endif
        configuration.timeoutIntervalForRequest = [timeout doubleValue];
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    });
    return session;
}

@end

/**
 * NSURLProtocolNoCache
 *
 * URL Protocol handler to prevent caching of local assets.
 */

@implementation NSURLProtocolNoCache


/**
 * Should this request be handled by this protocol handler?
 *
 * We disable caching on requests using the file:// protocol and prefixed with the app's Library directory
 * In the future, we may want to limit this or enable it based on configuration or not.
 *
 * @param theRequest is the inbound NSURLRequest.
 * @return YES to handle this request with the this NSURLProtocol handler.
 */

+ (BOOL) canInitWithRequest:(NSURLRequest*) req {
    NSURL* libraryDirectoryUrl = [ContentSync getStorageDirectory];
    return [req.URL.scheme isEqualToString:@"file"] && [req.URL.path hasPrefix:libraryDirectoryUrl.path];
}

/**
 * Canonical request definition.
 *
 * We keep it simple and map each request directly to itself.
 *
 * @param theRequest is the inbound NSURLRequest.
 * @return the same inbound NSURLRequest object.
 */

+ (NSURLRequest*) canonicalRequestForRequest:(NSURLRequest*) theRequest {
    return theRequest;
}

/**
 * Start loading the request.
 *
 * When loading a request, the request headers are altered to prevent browser caching.
 */

- (void) startLoading {
    NSData* data = [NSData dataWithContentsOfFile:self.request.URL.path];

    // add the no-cache headers to the request while preserving the existing HEADER values.
    NSMutableDictionary* headers = @{
            @"Cache-Control" : @"no-cache",
            @"Pragma" : @"no-cache",
            @"Content-Length" : [NSString stringWithFormat:@"%d", (int) [data length]]
    }.mutableCopy;
    NSObject *acceptHeaders = self.request.allHTTPHeaderFields[@"Accept"];
    if (acceptHeaders) {
        [headers setObject:acceptHeaders forKey:@"Accept"];
    }

    // create a response using the request and our new request headers
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:200
                                                             HTTPVersion:@"1.1"
                                                            headerFields:headers];

    // deliver the response and enable in-memory caching (we may want to completely disable this if issues arise)
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

/**
 * Stop loading the request.
 *
 * When the request is cancelled, we have an opportunity to clean up and/or recover. However, for our purpose
 * the ContentSync class will notify the user that the connection failed.
 */

- (void) stopLoading {
    NSLog(@"NSURLProtocolNoCache request was cancelled.");
}

@end
