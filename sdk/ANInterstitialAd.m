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

#import "ANInterstitialAd.h"
#import "ANGlobal.h"
#import "ANInterstitialAdViewController.h"
#import "ANBrowserViewController.h"
#import "ANAdFetcher.h"
#import "ANLogging.h"
#import "ANAdResponse.h"

#define AN_INTERSTITIAL_AD_TIMEOUT 60.0

NSString *const kANInterstitialAdViewKey = @"kANInterstitialAdViewKey";
NSString *const kANInterstitialAdViewDateLoadedKey = @"kANInterstitialAdViewDateLoadedKey";

@interface ANInterstitialAd () <ANAdFetcherDelegate, ANBrowserViewControllerDelegate, ANInterstitialAdViewControllerDelegate>

@property (nonatomic, readwrite, strong) ANInterstitialAdViewController *controller;
@property (nonatomic, readwrite, strong) NSMutableArray *precachedAdViews;
@property (nonatomic, readwrite, strong) NSMutableSet *allowedAdSizes;
@property (nonatomic, readwrite, strong) ANBrowserViewController *browserViewController;

@end

@implementation ANInterstitialAd
@synthesize placementId = __placementId;
@synthesize adSize = __adSize;
@synthesize clickShouldOpenInBrowser = __clickShouldOpenInBrowser;
@synthesize adFetcher = __adFetcher;
@synthesize delegate = __delegate;
@synthesize shouldServePublicServiceAnnouncements = __shouldServicePublicServiceAnnouncements;

- (id)init
{
	self = [super init];
	
	if (self != nil)
	{
		self.adFetcher = [[ANAdFetcher alloc] init];
		self.adFetcher.delegate = self;
		self.controller = [[ANInterstitialAdViewController alloc] init];
		self.controller.delegate = self;
		self.precachedAdViews = [NSMutableArray array];
		self.adSize = CGSizeZero;
		self.shouldServePublicServiceAnnouncements = YES;
	}
	
	return self;
}

- (id)initWithPlacementId:(NSString *)placementId
{
	self = [self init];
	
	if (self != nil)
	{
		self.placementId = placementId;
	}
	
	return self;
}

- (void)loadAd
{
	// Refresh our list of allowed ad sizes
    [self refreshAllowedAdSizes];
	
    // Pick an ad size out of our list of allowed ad sizes to send with the request
    NSValue *randomAllowedSize = [self.allowedAdSizes anyObject];
    self.adSize = [randomAllowedSize CGSizeValue];
    
    [self.adFetcher requestAd];
}

- (void)displayAdFromViewController:(UIViewController *)controller
{
	self.controller.contentView = nil;
    
    while ([self.precachedAdViews count] > 0 && self.controller.contentView == nil)
    {
        // Pull the first ad off
        NSDictionary *adDict = [self.precachedAdViews objectAtIndex:0];
        
        // Check to see if the date this was loaded is no more than 60 seconds ago
        NSDate *dateLoaded = [adDict objectForKey:kANInterstitialAdViewDateLoadedKey];
        
        if (([dateLoaded timeIntervalSinceNow] * -1) < AN_INTERSTITIAL_AD_TIMEOUT)
        {
            // If ad is still valid, set it as the content view
            UIView *adView = [adDict objectForKey:kANInterstitialAdViewKey];
            self.controller.contentView = adView;
        }
        
        // This ad is now stale, so remove it from our cached ads.
        [self.precachedAdViews removeObjectAtIndex:0];
    }
    
    if (self.controller.contentView != nil)
    {
		if ([self.delegate respondsToSelector:@selector(adWillPresent:)])
		{
			[self.delegate adWillPresent:self];
		}
		
		[controller presentViewController:self.controller animated:YES completion:NULL];
    }
    else
    {
        ANLogError(@"Display ad called, but no valid ad to show. Please load another interstitial ad.");
        [self.delegate adNoAdToShow:self];
    }
}

- (void)refreshAllowedAdSizes
{
    self.allowedAdSizes = [NSMutableSet set];
    
    NSArray *possibleSizesArray = [NSArray arrayWithObjects:
								   [NSValue valueWithCGSize:kANInterstitialAdSize1024x1024],
                                   [NSValue valueWithCGSize:kANInterstitialAdSize900x500],
                                   [NSValue valueWithCGSize:kANInterstitialAdSize320x480],
                                   [NSValue valueWithCGSize:kANInterstitialAdSize300x250], nil];
    for (NSValue *sizeValue in possibleSizesArray)
    {
        if (CGSizeLargerThanSize(self.frame.size, [sizeValue CGSizeValue]))
        {
            [self.allowedAdSizes addObject:sizeValue];
        }
    }
}

- (CGRect)frame
{
    // By definition, interstitials can only ever have the entire screen's bounds as its frame
    return [[UIScreen mainScreen] bounds];
}

- (NSString *)maximumSizeParameter
{
    return [NSString stringWithFormat:@"&size=%dx%d", (NSInteger)self.frame.size.width, (NSInteger)self.frame.size.height];
}

- (NSString *)promoSizesParameter
{
    NSString *promoSizesParameter = @"&promo_sizes=";
    NSMutableArray *sizesStringsArray = [NSMutableArray arrayWithCapacity:[self.allowedAdSizes count]];
    
    for (NSValue *sizeValue in self.allowedAdSizes)
    {
        CGSize size = [sizeValue CGSizeValue];
        NSString *param = [NSString stringWithFormat:@"%dx%d", (NSInteger)size.width, (NSInteger)size.height];
        
        [sizesStringsArray addObject:param];
    }
    
    promoSizesParameter = [promoSizesParameter stringByAppendingString:[sizesStringsArray componentsJoinedByString:@","]];
    
    return promoSizesParameter;
}

- (NSString *)psaParameter
{
	NSString *psaParameter = @"";
	
	if (!self.shouldServePublicServiceAnnouncements)
	{
		psaParameter = @"&psa=false";
	}
	
	return psaParameter;
}

- (NSString *)adType
{
	return @"interstitial";
}

#pragma mark ANAdFetcherDelegate

- (NSArray *)extraParametersForAdFetcher:(ANAdFetcher *)fetcher
{
    return [NSArray arrayWithObjects:
            [self maximumSizeParameter],
            [self promoSizesParameter],
			[self psaParameter], nil];
}

- (void)adFetcher:(ANAdFetcher *)fetcher didFinishRequestWithResponse:(ANAdResponse *)response
{
    if ([response isSuccessful])
    {
        NSDictionary *adViewWithDateLoaded = [NSDictionary dictionaryWithObjectsAndKeys:
                                              response.adView, kANInterstitialAdViewKey,
                                              [NSDate date], kANInterstitialAdViewDateLoadedKey,
                                              nil];
        [self.precachedAdViews addObject:adViewWithDateLoaded];
        ANLogDebug(@"Stored ad %@ in precached ad views", adViewWithDateLoaded);
        
        [self.delegate adDidReceiveAd:self];
    }
    else
    {
        [self.delegate ad:self requestFailedWithError:response.error];
    }
}

- (void)adFetcher:(ANAdFetcher *)fetcher adShouldOpenInBrowserWithURL:(NSURL *)URL
{
	// Stop the countdown and enable close button immediately
	[self.controller stopCountdownTimer];
	
	if (self.clickShouldOpenInBrowser)
	{
		if ([[UIApplication sharedApplication] canOpenURL:URL])
		{
			[[UIApplication sharedApplication] openURL:URL];
		}
	}
	else
	{
		// Interstitials require special handling of launching the in-app browser since they live on top of everything else
		self.browserViewController = [[ANBrowserViewController alloc] initWithURL:URL];
		self.browserViewController.delegate = self;
		
		[self.controller presentViewController:self.browserViewController animated:YES completion:NULL];
	}
}

- (NSTimeInterval)autorefreshIntervalForAdFetcher:(ANAdFetcher *)fetcher
{
    return 0.0;
}

- (NSString *)placementIdForAdFetcher:(ANAdFetcher *)fetcher
{
    return self.placementId;
}

- (CGSize)requestedSizeForAdFetcher:(ANAdFetcher *)fetcher
{
    return self.adSize;
}

- (NSString *)placementTypeForAdFetcher:(ANAdFetcher *)fetcher
{
    return self.adType;
}

- (void)adFetcher:(ANAdFetcher *)fetcher adShouldResizeToSize:(CGSize)size
{
	
}

- (void)adFetcher:(ANAdFetcher *)fetcher adShouldShowCloseButtonWithTarget:(id)target action:(SEL)action
{

}

- (void)adShouldRemoveCloseButtonWithAdFetcher:(ANAdFetcher *)fetcher
{

}

#pragma mark ANBrowserViewControllerDelegate

- (void)browserViewControllerShouldDismiss:(ANBrowserViewController *)controller
{
	[self.controller dismissViewControllerAnimated:YES completion:^{
		self.browserViewController = nil;
	}];
}

#pragma mark ANInterstitialAdViewControllerDelegate

- (void)interstitialAdViewControllerShouldDismiss:(ANInterstitialAdViewController *)controller
{
	if ([self.delegate respondsToSelector:@selector(adWillClose:)])
	{
		[self.delegate adWillClose:self];
	}
	
	[self.controller.presentingViewController dismissViewControllerAnimated:YES completion:^{
		if ([self.delegate respondsToSelector:@selector(adDidClose:)])
		{
			[self.delegate adDidClose:self];
		}
	}];
}

- (NSTimeInterval)interstitialAdViewControllerTimeToDismiss
{
	if (self.autoDismissTimeInterval > 0.0)
	{
		return self.autoDismissTimeInterval;
	}

	return kAppNexusDefaultInterstitialTimeoutInterval;
}

@end