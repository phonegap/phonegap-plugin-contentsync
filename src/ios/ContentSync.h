#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface CDVContentSync : CDVPlugin {
    @private CDVInvokedUrlCommand* _command;
}

- (void) sync:(CDVInvokedUrlCommand*)command;

@end
