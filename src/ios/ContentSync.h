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
#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVAvailability.h>

enum ProgressState {
    Stopped = 0,
    Downloading,
    Extracting,
    Complete
};
typedef NSUInteger ProgressState;

enum ErrorCodes {
    INVALID_URL_ERR = 1,
    CONNECTION_ERR,
    UNZIP_ERR,
    LOCAL_ERR,
#if !TARGET_OS_IOS // this is currently not added to ios. see issue-96
    IN_PROGRESS_ERR,
#endif
};
typedef NSUInteger ErrorCodes;

@interface ContentSyncTask: NSObject

@property (nonatomic) CDVInvokedUrlCommand* command;
@property (nonatomic) NSURLSessionDownloadTask* downloadTask;
@property (nonatomic) NSString* appId;
@property (nonatomic) NSString* archivePath;
@property (nonatomic) NSInteger progress;
@property (nonatomic) BOOL extractArchive;

@end

@interface ContentSync : CDVPlugin <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic) NSString* currentPath;
@property (nonatomic) NSMutableArray *syncTasks;
@property (nonatomic) NSURLSession* session;
@property (nonatomic) NSMutableArray* trustedHosts;

- (void) sync:(CDVInvokedUrlCommand*)command;
- (void) cancel:(CDVInvokedUrlCommand*)command;
- (void) download:(CDVInvokedUrlCommand*)command;
- (void) unzip:(CDVInvokedUrlCommand*)command;

@end

/**
 * NSURLProtocolNoCache
 *
 * Custom URL Protocol handler to prevent caching of local assets.
 */

@interface NSURLProtocolNoCache : NSURLProtocol
@end
