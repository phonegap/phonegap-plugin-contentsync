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
#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

#ifdef USE_COCOAPODS
#import <SSZipArchive/SSZipArchive.h>
#else
#import "SSZipArchive.h"
#endif

@implementation ContentSyncTask

- (ContentSyncTask *)init {
    self = (ContentSyncTask*)[super init];
    if(self) {
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

@interface ContentSync () <SSZipArchiveDelegate>
@end

@implementation ContentSync

- (void)pluginInitialize {
    [NSURLProtocol registerClass:[NSURLProtocolNoCache class]];
}

- (CDVPluginResult*) preparePluginResult:(NSInteger)progress status:(NSInteger)status {
    CDVPluginResult *pluginResult = nil;

    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
    [message setObject:[NSNumber numberWithInteger:progress] forKey:@"progress"];
    [message setObject:[NSNumber numberWithInteger:status] forKey:@"status"];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];

    return pluginResult;
}

#if TARGET_OS_IOS
/**
 * Returns the _applicationStorageDirectory_ similar to the one of the file plugin
 */
+ (NSURL*) getStorageDirectory {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSArray *URLs = [fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    NSURL *libraryDirectoryUrl = [URLs objectAtIndex:0];
    return [libraryDirectoryUrl URLByAppendingPathComponent:@"NoCloud"];
}

#else // TARGET_OS_MAC

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
    NSURL *dirPath = [[supportDir URLByAppendingPathComponent:bundleID] URLByAppendingPathComponent:@"files"];

    if (![fm fileExistsAtPath:dirPath.path]) {
        if (![fm createDirectoryAtURL:dirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"unable to create support directory: %@", error);
            return nil;
        }
    }
    return dirPath;
}
#endif // TAGET_OS_IOS

+ (BOOL) hasAppBeenUpdated {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* previousVersion = [defaults objectForKey:@"PREVIOUS_VERSION"];

    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString* currentVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];

    NSLog(@"previous version %@", previousVersion);
    NSLog(@"current version %@", currentVersion);

    // set previous version to current version
    [defaults setObject:currentVersion forKey:@"PREVIOUS_VERSION"];
    [defaults synchronize];
    
    BOOL appHasBeenUpdated = ([currentVersion compare:previousVersion options:NSNumericSearch] == NSOrderedDescending);

    // This condition seems to occur on the 2nd run of the app, when the PREVIOUS_VERSION entry has not yet been set.
    // In this case, appHasBeenUpdated will incorrectly be set to YES, even though the app has not actually been updated.
    if (previousVersion == nil && currentVersion != nil) {
        NSLog(@"previous version has not yet been set. skipping comparison");
        appHasBeenUpdated = false;
    } else if (appHasBeenUpdated == true) {
        NSLog(@"current version is newer than previous version");
    }

    return appHasBeenUpdated;
}

- (void)sync:(CDVInvokedUrlCommand*)command {
    __block NSString* src = [command argumentAtIndex:0 withDefault:nil];
    __block NSString* type = [command argumentAtIndex:2];
    __block BOOL local = [type isEqualToString:@"local"];

    __block NSFileManager *fileManager = [NSFileManager defaultManager];
    __block NSString* appId = [command argumentAtIndex:1];
    __block NSURL* storageDirectory = [ContentSync getStorageDirectory];
    __block NSURL *appPath = [storageDirectory URLByAppendingPathComponent:appId];
    NSLog(@"appPath %@", appPath);

    if(local == YES) {
        NSLog(@"Requesting local copy of %@", appId);
        if([fileManager fileExistsAtPath:[appPath path]]) {
            if (![ContentSync hasAppBeenUpdated]) {
                NSLog(@"Found local copy %@", [appPath path]);
                CDVPluginResult *pluginResult = nil;

                NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
                [message setObject:[appPath path] forKey:@"localPath"];
                [message setObject:@"true" forKey:@"cached"];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];

                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
        }
    }

    BOOL copyRootApp = [[command argumentAtIndex:5 withDefault:@(NO)] boolValue];
    BOOL copyCordovaAssetsValue = [[command argumentAtIndex:4 withDefault:@(NO)] boolValue];

    if(copyRootApp == YES || copyCordovaAssetsValue == YES) {
        __block NSError* error = nil;

        NSLog(@"Creating app directory %@", [appPath path]);
        [fileManager createDirectoryAtPath:[appPath path] withIntermediateDirectories:YES attributes:nil error:&error];

        __block NSError* errorSetting = nil;
        __block BOOL success = [appPath setResourceValue: [NSNumber numberWithBool: YES]
                                          forKey: NSURLIsExcludedFromBackupKey error: &errorSetting];

        if(success == NO) {
            NSLog(@"WARNING: %@ might be backed up to iCloud!", [appPath path]);
        }

        if(error != nil) {
            CDVPluginResult *pluginResult = nil;
            NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
            [message setObject:[NSNumber numberWithInteger:LOCAL_ERR] forKey:@"type"];
            [message setObject:[NSNumber numberWithInteger:-1] forKey:@"responseCode"];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
            NSLog(@"%@", [error localizedDescription]);
        } else {
            [self.commandDelegate runInBackground:^{
                CDVPluginResult *pluginResult = nil;
                [self copyCordovaAssets:[appPath path] copyRootApp:copyRootApp];
                if(src == nil) {
                    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
                    [message setObject:[appPath path] forKey:@"localPath"];
                    [message setObject:@"true" forKey:@"cached"];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                    return;
                }
            }];
        }
    }


    __weak ContentSync* weakSelf = self;
    if (local != YES && src != nil) {
        [self.commandDelegate runInBackground:^{
            [weakSelf startDownload:command extractArchive:YES];
        }];
    }
}

- (void) download:(CDVInvokedUrlCommand*)command {
    __weak ContentSync* weakSelf = self;

    [self.commandDelegate runInBackground:^{
        [weakSelf startDownload:command extractArchive:NO];
    }];
}

- (BOOL) isZipArchive:(NSString*)filePath {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSData *data = [fh readDataOfLength:4];
    if ([data length] == 4) {
        const char *bytes = [data bytes];
        if (bytes[0] == 'P' && bytes[1] == 'K' && bytes[2] == 3 && bytes[3] == 4) {
            return YES;
        }
    }
    return NO;
}

- (void)startDownload:(CDVInvokedUrlCommand*)command extractArchive:(BOOL)extractArchive {

    CDVPluginResult* pluginResult = nil;
    NSString* src = [command argumentAtIndex:0 withDefault:nil];
    NSString* appId = [command argumentAtIndex:1];
    NSNumber* timeout = [command argumentAtIndex:6 withDefault:[NSNumber numberWithDouble:15]];
    BOOL validateSrc = [[command argumentAtIndex:9 withDefault:@(YES)] boolValue];

    self.session = [self backgroundSession:timeout];
    NSURL *srcURL = [NSURL URLWithString:src];

    // Setting headers (do changes also in download url, or better extract setting the following lines to a function)
    NSDictionary *headers = [command argumentAtIndex:3 withDefault:nil andClass:[NSDictionary class]];

    // checking if URL is valid
    BOOL srcIsValid = YES;

    if (validateSrc == YES) {
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:srcURL];
        [urlRequest setHTTPMethod:@"HEAD"];

        [self setHeaders:urlRequest :headers];

        // request just to check if url is correct and server is available
        NSHTTPURLResponse *response = nil;
        NSError *error = nil;
        [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];

        if (error || response.statusCode >= 400) {
            srcIsValid = false;
        }
    }

    if(srcURL && srcURL.scheme && srcURL.host && srcIsValid == YES) {

        BOOL trustHost = (BOOL) [command argumentAtIndex:7 withDefault:@(NO)];

        if(!self.trustedHosts) {
            self.trustedHosts = [NSMutableArray arrayWithCapacity:1];
        }

        if(trustHost == YES) {
            NSLog(@"WARNING: Trusting host %@", [srcURL host]);
            [self.trustedHosts addObject:[srcURL host]];
        }

        NSLog(@"startDownload from %@", src);
        NSURL *downloadURL = [NSURL URLWithString:src];

        if (appId == nil) {
            appId = [srcURL lastPathComponent];
        }

        // downloadURL is nil if malformed URL
        if(downloadURL == nil) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:INVALID_URL_ERR];

#if !TARGET_OS_IOS // this is currently not added to ios. see issue-96
        } else if ([self findSyncDataByAppId:appId]) {
            NSLog(@"Download task already started for %@", appId);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:IN_PROGRESS_ERR];
#endif
        } else {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL];
            request.timeoutInterval = 15.0;

            [self setHeaders:request :headers];

            NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithRequest:request];

            ContentSyncTask* sData = [[ContentSyncTask alloc] init];

            sData.appId = appId;
            sData.downloadTask = downloadTask;
            sData.command = command;
            sData.progress = 0;
            sData.extractArchive = extractArchive;

            [self addSyncTask:sData];

            [downloadTask resume];

            pluginResult = [self preparePluginResult:sData.progress status:Downloading];
            [pluginResult setKeepCallbackAsBool:YES];
        }

    } else {
        NSLog(@"Invalid src URL %@", src);
        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:[NSNumber numberWithInteger:INVALID_URL_ERR] forKey:@"type"];
        [message setObject:[NSNumber numberWithInteger:-1] forKey:@"responseCode"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
    }

    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

- (void)setHeaders:(NSMutableURLRequest*)request :(NSDictionary*)headers {
    // Setting headers (do changes also in check if url is valid, or better extract setting the following lines to a function)
    if(headers != nil) {
        for (NSString* header in [headers allKeys]) {
            NSLog(@"Setting header %@ %@", header, [headers objectForKey:header]);
            [request addValue:[headers objectForKey:header] forHTTPHeaderField:header];
        }
    }
}

- (void)cancel:(CDVInvokedUrlCommand *)command {
    NSString* appId = [command argumentAtIndex:0 withDefault:nil];
    NSLog(@"Cancelling download %@", appId);
    if(appId) {
        ContentSyncTask* sTask = [self findSyncDataByAppId:appId];
        if(sTask) {
            CDVPluginResult* pluginResult = nil;
            [[sTask downloadTask] cancel];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }
}

- (void) addSyncTask:(ContentSyncTask*) task {
    @synchronized (self) {
        if (!self.syncTasks) {
            self.syncTasks = [NSMutableArray array];
        }
        [self.syncTasks addObject:task];
    }
};

- (void) removeSyncTask:(ContentSyncTask*) task {
    @synchronized (self) {
        [self.syncTasks removeObject:task];
    }
}

- (ContentSyncTask*) findSyncDataByDownloadTask:(NSURLSessionDownloadTask*) downloadTask {
    @synchronized (self) {
        for (ContentSyncTask* sTask in self.syncTasks) {
            if (sTask.downloadTask == downloadTask) {
                return sTask;
            }
        }
        return nil;
    }
}

- (ContentSyncTask*) findSyncDataByPath {
    @synchronized (self) {
        for (ContentSyncTask* sTask in self.syncTasks) {
            if ([sTask.archivePath isEqualToString:[self currentPath]]) {
                return sTask;
            }
        }
        return nil;
    }
}

- (ContentSyncTask*) findSyncDataByAppId:(NSString*) appId {
    @synchronized (self) {
        for (ContentSyncTask* sTask in self.syncTasks) {
            if ([sTask.appId isEqualToString:appId]) {
                return sTask;
            }
        }
        return nil;
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler{
    if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSLog(@"Received challenge for host %@", challenge.protectionSpace.host);
        if([self.trustedHosts containsObject:challenge.protectionSpace.host]) {
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
        } else {
            completionHandler(NSURLSessionAuthChallengeUseCredential,nil);
            //            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
    }
}

- (void)URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {

    CDVPluginResult* pluginResult = nil;

    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:(NSURLSessionDownloadTask*)downloadTask];

    if(sTask) {
        double progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
        //NSLog(@"DownloadTask: %@ progress: %lf callbackId: %@", downloadTask, progress, sTask.command.callbackId);
        progress = (sTask.extractArchive == YES ? ((progress / 2) * 100) : progress * 100);
        sTask.progress = progress;
        pluginResult = [self preparePluginResult:sTask.progress status:Downloading];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    } else {
        NSLog(@"Could not find download task");
    }
}

- (void) URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask*)downloadTask didFinishDownloadingToURL:(NSURL *)downloadURL {


    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *URLs = [fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    NSURL *libraryDirectory = [URLs objectAtIndex:0];

    NSURL *originalURL = [[downloadTask originalRequest] URL];
    NSURL *sourceURL = [libraryDirectory URLByAppendingPathComponent:[originalURL lastPathComponent]];
    NSError *errorCopy;

    [fileManager removeItemAtURL:sourceURL error:NULL];
    BOOL success = [fileManager copyItemAtURL:downloadURL toURL:sourceURL error:&errorCopy];

    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:downloadTask];

    if(success) {
        if(sTask) {
            sTask.archivePath = [sourceURL path];

            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString* type = [sTask.command argumentAtIndex:2 withDefault:@"replace"];
            BOOL replace = [type isEqualToString:@"replace"];
            NSURL *dstURL = [libraryDirectory URLByAppendingPathComponent:[sTask appId]];
            if([fileManager fileExistsAtPath:[dstURL path]] && replace == YES) {
                NSLog(@"%@ already exists. Deleting it since type is set to `replace`", [dstURL path]);
                [fileManager removeItemAtURL:dstURL error:NULL];
            }

            if(sTask.extractArchive == YES && [self isZipArchive:[sourceURL path]]) {
                // FIXME there is probably a better way to do this
                NSURL *storageDirectory = [ContentSync getStorageDirectory];
                NSURL *extractURL = [storageDirectory URLByAppendingPathComponent:[sTask appId]];
                NSString* type = [sTask.command argumentAtIndex:2 withDefault:@"replace"];

                CDVInvokedUrlCommand* command = [CDVInvokedUrlCommand commandFromJson:[NSArray arrayWithObjects:sTask.command.callbackId, @"Zip", @"unzip", [NSMutableArray arrayWithObjects:[sourceURL absoluteString], [extractURL absoluteString], type, nil], nil]];
                [self unzip:command];
            } else {
                NSURL *srcURL = [NSURL fileURLWithPath:[sTask archivePath]];
                NSError* error = nil;
                NSError *errorCopy;
                BOOL success;

                success = [fileManager createDirectoryAtURL:[dstURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];

                if(success) {
                    NSLog(@"Moving %@ to %@", [srcURL path], [dstURL path]);

                    success = [fileManager moveItemAtURL:srcURL toURL:dstURL error:&errorCopy];
                    if(!success) {
                        NSLog(@"Error copying. File might already exist %@", [errorCopy description]);
                    }
                    sTask.archivePath = [dstURL path];
                    sTask.extractArchive = NO;
                } else {
                    NSLog(@"Unable to create ID :-[ %@", [error description]);
                }
            }
        }
    } else {
        NSLog(@"Sync Failed - Copy Failed - %@", [errorCopy localizedDescription]);

        CDVPluginResult* pluginResult = nil;

        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:[NSNumber numberWithInteger:CONNECTION_ERR] forKey:@"type"];
        [message setObject:[NSNumber numberWithInteger:-1] forKey:@"responseCode"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    }
}

- (void) URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task didCompleteWithError:(NSError *)error {

    ContentSyncTask* sTask = [self findSyncDataByDownloadTask:(NSURLSessionDownloadTask*)task];

    if(sTask) {
        CDVPluginResult* pluginResult = nil;

        if(error == nil) {
            if([(NSHTTPURLResponse*)[task response] statusCode] != 200) {
                NSLog(@"Task: %@ completed with HTTP Error Code: %ld", task, (long)[(NSHTTPURLResponse*)[task response] statusCode]);

                NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
                [message setObject:[NSNumber numberWithInteger:CONNECTION_ERR] forKey:@"type"];
                [message setObject:[NSNumber numberWithInteger:[(NSHTTPURLResponse*)[task response] statusCode]] forKey:@"responseCode"];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

                NSFileManager *fileManager = [NSFileManager defaultManager];
                if([fileManager fileExistsAtPath:[sTask archivePath]]) {
                    NSLog(@"Deleting archive. It's probably an HTTP Error Page anyways");
                    [fileManager removeItemAtPath:[sTask archivePath] error:NULL];
                }
                [self removeSyncTask:sTask];
            } else {
                double progress = (double)task.countOfBytesReceived / (double)task.countOfBytesExpectedToReceive;
                NSLog(@"Task: %@ completed successfully", sTask.archivePath);
                if(sTask.extractArchive) {
                    progress = ((progress / 2) * 100);
                    pluginResult = [self preparePluginResult:progress status:Downloading];
                    [pluginResult setKeepCallbackAsBool:YES];
                }
                else {
                    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
                    [message setObject:[NSNumber numberWithInteger:Complete] forKey:@"status"];
                    [message setObject:[sTask archivePath] forKey:@"localPath"];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
                    [self removeSyncTask:sTask];
                }
            }
        } else {
            NSLog(@"Task: %@ completed with error: %@", task, [error localizedDescription]);

            NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
            [message setObject:[NSNumber numberWithInteger:CONNECTION_ERR] forKey:@"type"];
            [message setObject:[NSNumber numberWithInteger:[(NSHTTPURLResponse*)[task response] statusCode]] forKey:@"responseCode"];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

            [self removeSyncTask:sTask];
        }
        if(![[error localizedDescription]  isEqual: @"cancelled"]) {
            [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        }
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"All tasks are finished");
}

- (void)unzip:(CDVInvokedUrlCommand*)command {
    __weak ContentSync* weakSelf = self;
    __block NSString* callbackId = command.callbackId;

    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;

        NSURL* sourceURL = [NSURL URLWithString:[command argumentAtIndex:0]];
        NSURL* destinationURL = [NSURL URLWithString:[command argumentAtIndex:1]];

        @try {
            NSError *error;
            if(![SSZipArchive unzipFileAtPath:[sourceURL path] toDestination:[destinationURL path] overwrite:YES password:nil error:&error delegate:weakSelf]) {
                NSLog(@"%@ - %@", @"Error occurred during unzipping", [error localizedDescription]);

                NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
                [message setObject:[NSNumber numberWithInteger:UNZIP_ERR] forKey:@"type"];
                [message setObject:[NSNumber numberWithInteger:-1] forKey:@"responseCode"];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                // clean up zip archive
                NSFileManager *fileManager = [NSFileManager defaultManager];
                [fileManager removeItemAtURL:sourceURL error:NULL];

            }
        }
        @catch (NSException *exception) {
            NSLog(@"%@ - %@", @"Error occurred during unzipping", [exception debugDescription]);
            NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
            [message setObject:[NSNumber numberWithInteger:UNZIP_ERR] forKey:@"type"];
            [message setObject:[NSNumber numberWithInteger:-1] forKey:@"responseCode"];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
        }
        [pluginResult setKeepCallbackAsBool:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        });
    }];
}


- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo {
    self.currentPath = path;
}

- (void)zipArchiveProgressEvent:(unsigned long long)loaded total:(unsigned long long)total {
    ContentSyncTask* sTask = [self findSyncDataByPath];
    if(sTask) {
        //NSLog(@"Extracting %ld / %ld", (long)loaded, (long)total);
        double progress = ((double)loaded / (double)total);
        progress = (sTask.extractArchive == YES ? ((0.5 + progress / 2) * 100) : progress * 100);
        CDVPluginResult* pluginResult = [self preparePluginResult:progress status:Extracting];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
    }
}

- (void) zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath {
    NSLog(@"unzipped path %@", unzippedPath);
    ContentSyncTask* sTask = [self findSyncDataByPath];
    if(sTask) {

        BOOL copyCordovaAssets = [[sTask.command argumentAtIndex:4 withDefault:@(NO)] boolValue];

        if(copyCordovaAssets == YES) {
            [self copyCordovaAssets:unzippedPath];
        }
        // XXX this is to match the Android implementation
        CDVPluginResult* pluginResult = [self preparePluginResult:100 status:Complete];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        // END

        // Do not BACK UP folder to iCloud
        [self addSkipBackupAttributeToItemAtPath:path];
        [self addSkipBackupAttributeToItemAtPath:unzippedPath];

        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:unzippedPath forKey:@"localPath"];
        [message setObject:@"false" forKey:@"cached"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [pluginResult setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:sTask.command.callbackId];
        [self removeSyncTask:sTask];
    }
}

- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *)path {
    NSURL* appURL = [NSURL fileURLWithPath: path];
    NSError *error = nil;
    BOOL success = [appURL setResourceValue: [NSNumber numberWithBool: YES]
                                     forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [appURL lastPathComponent], error);
    }
    return success;
}

- (void)mergeFolders:(NSString *)srcDir intoPath:(NSString *)dstDir error:(NSError**)err {

    NSLog(@"- mergeFolders: %@\n intoPath: %@", srcDir, dstDir);

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *srcDirEnum = [fm enumeratorAtPath:srcDir];
    NSString *subPath;
    while ((subPath = [srcDirEnum nextObject])) {
        NSLog(@" subPath: %@", subPath);
        NSString *srcFullPath =  [srcDir stringByAppendingPathComponent:subPath];
        NSString *potentialDstPath = [dstDir stringByAppendingPathComponent:subPath];

        // Need to also check if file exists because if it doesn't, value of `isDirectory` is undefined.
        BOOL isDirectory = ([[NSFileManager defaultManager] fileExistsAtPath:srcFullPath isDirectory:&isDirectory] && isDirectory);

        // Create directory, or delete existing file and move file to destination
        if (isDirectory) {
            NSLog(@"   create directory");
            [fm createDirectoryAtPath:potentialDstPath withIntermediateDirectories:YES attributes:nil error:err];
            if (err && *err) {
                NSLog(@"ERROR: %@", *err);
                return;
            }
        }
        else {
            if ([fm fileExistsAtPath:potentialDstPath]) {
                NSLog(@"   removeItemAtPath");
                [fm removeItemAtPath:potentialDstPath error:err];
                if (err && *err) {
                    NSLog(@"ERROR: %@", *err);
                    return;
                }
            }

            NSLog(@"   copyItemAtPath");
            [fm copyItemAtPath:srcFullPath toPath:potentialDstPath error:err];
            if (err && *err) {
                NSLog(@"ERROR: %@", *err);
                return;
            }
        }
    }
}

- (BOOL) copyCordovaAssets:(NSString*)unzippedPath {
    return [self copyCordovaAssets:unzippedPath copyRootApp:false];
}

- (BOOL) copyCordovaAssets:(NSString*)unzippedPath copyRootApp:(BOOL)copyRootApp {
    NSLog(@"copyCordovaAssets");
    NSError *errorCopy;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL* destinationURL = [NSURL fileURLWithPath:unzippedPath];

    if(copyRootApp == YES) {
        NSLog(@"Copying Root App");
        NSString* suffix = @"/www";
        NSString* destDir = unzippedPath;

        if([fileManager fileExistsAtPath:[unzippedPath stringByAppendingString:suffix]]) {
            destDir = [unzippedPath stringByAppendingString:suffix];
            NSLog(@"Found %@ folder. Will copy root application to it.", suffix);
        }
        // we use cordova.js as a way to find the root www/
        NSString* root = [[[self commandDelegate] pathForResource:@"cordova.js"] stringByDeletingLastPathComponent];

        NSError *mergeError = nil;
        [self mergeFolders:root intoPath:destDir error:&mergeError];
        if(mergeError != nil) {
            NSLog(@"An error occurred: %@", [mergeError localizedDescription]);
            return NO;
        }

        return YES;
    }
    NSLog(@"Copying Cordova Assets");
    NSArray* cordovaAssets = [NSArray arrayWithObjects:@"cordova.js",@"cordova_plugins.js",@"plugins", nil];
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

#ifdef __CORDOVA_4_0_0
#if TARGET_OS_IPHONE
- (void)loadUrl:(CDVInvokedUrlCommand*) command {
    NSString* url = [command argumentAtIndex:0 withDefault:nil];
    if(url != nil) {
        NSLog(@"Loading URL %@", url);
        NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        [self.webViewEngine loadRequest:request];
    } else {
        NSLog(@"URL IS NIL");
    }
}
#endif
#endif

- (NSURLSession*) backgroundSession:(NSNumber*) timeout {
    NSString *sessionId = [NSString stringWithFormat:@"%@-download-task", [[NSBundle mainBundle] bundleIdentifier]];

    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration;

#if TARGET_OS_IOS
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >=8.0f)
        {
            configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionId];
        }
        else
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:sessionId];
#pragma clang diagnostic pop
        }
#else
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_0
#pragma clang diagnostic push
#pragma ide diagnostic ignored "UnavailableInDeploymentTarget"
        configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionId];
#pragma clang diagnostic pop
#else
        configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:sessionId];
#endif
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
+ (BOOL)canInitWithRequest:(NSURLRequest*)theRequest {
    NSURL* libraryDirectoryUrl = [ContentSync getStorageDirectory];
    return [theRequest.URL.scheme isEqualToString:@"file"] && [theRequest.URL.path hasPrefix:[libraryDirectoryUrl path]];
}

/**
 * Canonical request definition.
 *
 * We keep it simple and map each request directly to itself.
 *
 * @param theRequest is the inbound NSURLRequest.
 * @return the same inbound NSURLRequest object.
 */

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)theRequest {
    return theRequest;
}

/**
 * Start loading the request.
 *
 * When loading a request, the request headers are altered to prevent browser caching.
 */

- (void)startLoading {
    NSData *data = [NSData dataWithContentsOfFile:self.request.URL.path];

    // Whether as a bug or intentionally, it seems that as of iOS 10 the response's MIME Type is
    // defaulting to 'application/octet-stream' for most files. For now we can set it manually.
    // MIME lookup taken from:
    // http://stackoverflow.com/questions/1363813/how-can-you-read-a-files-mime-type-in-objective-c/21858677#21858677
    NSString *fileExtension = self.request.URL.pathExtension;
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
    NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);

    // add the no-cache and MIME HEADERs to the request while preserving the existing HEADER values.
    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:self.request.allHTTPHeaderFields];
    headers[@"Cache-Control"] = @"no-cache";
    headers[@"Pragma"] = @"no-cache";
    headers[@"Content-Length"] = [NSString stringWithFormat:@"%d", (int)[data length]];
    headers[@"Content-Type"] = contentType;

    // create a response using the request and our new HEADERs
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
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

- (void)stopLoading {
    NSLog(@"NSURLProtocolNoCache request was cancelled.");
}

@end
