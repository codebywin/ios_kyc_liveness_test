#import "KYCAppDelegate.h"
#import "KYCViewController.h"

@implementation KYCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[KYCViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
