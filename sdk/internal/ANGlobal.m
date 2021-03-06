/*   Copyright 2013 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "ANGlobal.h"
#import "ANBasicConfig.h"

#import "ANLogging.h"

#import <sys/utsname.h>
#import <AdSupport/AdSupport.h>

NSString *const kANFirstLaunchKey = @"kANFirstLaunchKey";

NSString *ANUserAgent()
{
    static NSString *userAgent = nil;
	
    if (userAgent == nil)
    {
        UIWebView *webview = [[UIWebView alloc] init];
        userAgent = [[webview stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"] copy];
		webview.delegate = nil;
		[webview stopLoading];
    }
    
    return userAgent;
}

NSString *ANDeviceModel()
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return @(systemInfo.machine);
}

BOOL ANAdvertisingTrackingEnabled()
{
    // Beginning in iOS 6, Apple allows users to turn off advertising tracking in their settings, which we must respect.
    // By default, this value is YES. If a user does turn this off, use the unique identifier *only* for the following:
    // Frequency capping, conversion events, estimating number of unique users, security and fraud detection, and debugging.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
    if (NSClassFromString(@"ASIdentifierManager"))
    {
        return [ASIdentifierManager sharedManager].isAdvertisingTrackingEnabled;
    }
#endif
    
    return YES;
}

BOOL isFirstLaunch()
{
	BOOL isFirstLaunch = ![[NSUserDefaults standardUserDefaults] boolForKey:kANFirstLaunchKey];
	
	if (isFirstLaunch)
    {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kANFirstLaunchKey];
    }
    
    return isFirstLaunch;
}

NSString *ANUDID() {
    static NSString *udidComponent = @"";
    
    if ([udidComponent isEqualToString:@""]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
        if (NSClassFromString(@"ASIdentifierManager")) {
            // iOS 6: Use the ASIdentifierManager provided method of getting the identifier
            NSString *advertisingIdentifier = [[ASIdentifierManager sharedManager]
                                               .advertisingIdentifier UUIDString];
            
            if (advertisingIdentifier) {
                udidComponent = advertisingIdentifier;
            }
            else {
                ANLogWarn(@"No advertisingIdentifier retrieved. Cannot generate udidComponent.");
            }
        }
#endif
	}
	
    return udidComponent;
}

NSString *ANErrorString(NSString *key) {
    return NSLocalizedStringFromTableInBundle(key, AN_ERROR_TABLE, ANResourcesBundle(), @"");
}

NSError *ANError(NSString *key, NSInteger code, ...) {
    NSDictionary *errorInfo = nil;
    va_list args;
    va_start(args, code);
    NSString *localizedDescription = ANErrorString(key);
    if (localizedDescription) {
        localizedDescription = [[NSString alloc] initWithFormat:localizedDescription
                                                      arguments:args];
    } else {
        ANLogWarn(@"Could not find localized error string for key %@", key);
        localizedDescription = @"";
    }
    va_end(args);
    errorInfo = @{NSLocalizedDescriptionKey: localizedDescription};
    return [NSError errorWithDomain:AN_ERROR_DOMAIN
                               code:code
                           userInfo:errorInfo];
}

NSBundle *ANResourcesBundle() {
    static dispatch_once_t resBundleToken;
    static NSBundle *resBundle;
    static ANGlobal *globalInstance;
    dispatch_once(&resBundleToken, ^{
        globalInstance = [[ANGlobal alloc] init];
        NSString *resBundlePath = [[NSBundle bundleForClass:[globalInstance class]] pathForResource:AN_RESOURCE_BUNDLE ofType:@"bundle"];
        resBundle = resBundlePath ? [NSBundle bundleWithPath:resBundlePath] : [NSBundle bundleForClass:[globalInstance class]];
    });
    return resBundle;
}

NSString *ANPathForANResource(NSString *name, NSString *type) {
    NSString *path = [ANResourcesBundle() pathForResource:name ofType:type];
    if (!path) {
        ANLogError(@"Could not find resource %@.%@. Please make sure that %@.bundle or all the resources in sdk/resources are included in your app target's \"Copy Bundle Resources\".", name, type, AN_RESOURCE_BUNDLE);
    }
    return path;
}

NSString *convertToNSString(id value) {
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    ANLogWarn(@"Failed to convert to NSString");
    return nil;
}

CGRect adjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(CGRect rect) {
    // If portrait, no adjustment is necessary.
    if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) {
        return rect;
    }
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    // iOS 8
    if (!CGPointEqualToPoint(screenBounds.origin, CGPointZero) || screenBounds.size.width > screenBounds.size.height) {
        return rect;
    }
    
    // iOS 7 and below
    CGFloat flippedOriginX = screenBounds.size.height - (rect.origin.y + rect.size.height);
    CGFloat flippedOriginY = screenBounds.size.width - (rect.origin.x + rect.size.width);
    
    CGRect adjustedRect;
    switch ([UIApplication sharedApplication].statusBarOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            adjustedRect = CGRectMake(flippedOriginX, rect.origin.x, rect.size.height, rect.size.width);
            break;
        case UIInterfaceOrientationLandscapeRight:
            adjustedRect = CGRectMake(rect.origin.y, flippedOriginY, rect.size.height, rect.size.width);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            adjustedRect = CGRectMake(flippedOriginY, flippedOriginX, rect.size.width, rect.size.height);
            break;
        default:
            adjustedRect = rect;
            break;
    }
    
    return adjustedRect;
}

NSString *ANMRAIDBundlePath() {
    NSString *mraidPath = ANPathForANResource(@"ANMRAID", @"bundle");
    if (!mraidPath) {
        ANLogError(@"Could not find ANMRAID.bundle. Please make sure that %@.bundle or the ANMRAID.bundle resource in sdk/resources is included in your app target's \"Copy Bundle Resources\".", AN_RESOURCE_BUNDLE);
        return nil;
    }
    return mraidPath;
}

BOOL hasHttpPrefix(NSString *url) {
    return ([url hasPrefix:@"http"] || [url hasPrefix:@"https"]);
}

static NSMutableSet *invalidNetworks;

NSMutableSet *ANInvalidNetworks() {
    if (!invalidNetworks) {
        invalidNetworks = [NSMutableSet new];
    }
    return invalidNetworks;
}

void ANAddInvalidNetwork(NSString *network) {
    if (!invalidNetworks) {
        invalidNetworks = [NSMutableSet new];
    }
    [invalidNetworks addObject:network];
}

static BOOL notificationsEnabled = NO;

void ANSetNotificationsEnabled(BOOL enabled) {
    notificationsEnabled = enabled;
}

void ANPostNotifications(NSString *name, id object, NSDictionary *userInfo) {
    if (notificationsEnabled) {
        [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                            object:object
                                                          userInfo:userInfo];
    }
}

CGRect ANPortraitScreenBounds() {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if ([UIApplication sharedApplication].statusBarOrientation != UIInterfaceOrientationPortrait) {
        if (!CGPointEqualToPoint(screenBounds.origin, CGPointZero) || screenBounds.size.width > screenBounds.size.height) {
            // need to orient screen bounds
            switch ([UIApplication sharedApplication].statusBarOrientation) {
                case UIInterfaceOrientationLandscapeLeft:
                    return CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);
                    break;
                case UIInterfaceOrientationLandscapeRight:
                    return CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);
                    break;
                case UIInterfaceOrientationPortraitUpsideDown:
                    return CGRectMake(0, 0, screenBounds.size.width, screenBounds.size.height);
                    break;
                default:
                    break;
            }
        }
    }
    return screenBounds;
}

NSURLRequest *ANBasicRequestWithURL(NSURL *URL) {
    NSMutableURLRequest *request = ANBasicMutableRequest();
    request.URL = URL;
    return [request copy];
}

NSMutableURLRequest *ANBasicMutableRequest() {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:nil
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:kAppNexusRequestTimeoutInterval];
    [request setValue:ANUserAgent() forHTTPHeaderField:@"User-Agent"];
    return request;
}

NSNumber *ANiTunesIDForURL(NSURL *URL) {
    if ([URL.host isEqualToString:@"itunes.apple.com"]) {
        NSRegularExpression *idPattern = [[NSRegularExpression alloc] initWithPattern:@"id(\\d+)"
                                                                              options:0
                                                                                error:nil];
        NSRange idRange = [idPattern rangeOfFirstMatchInString:URL.absoluteString
                                                       options:0
                                                         range:NSMakeRange(0, URL.absoluteString.length)];
        if (idRange.length != 0) {
            NSString *idString = [[URL.absoluteString substringWithRange:idRange] substringFromIndex:2];
            return @([idString longLongValue]);
        }
    }
    return nil;
}

BOOL ANCanPresentFromViewController(UIViewController *viewController) {
    return viewController.view.window != nil ? YES : NO;
}

@implementation ANGlobal

@end
