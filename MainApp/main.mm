#import <UIKit/UIKit.h>
#import <UnityFramework/UnityFramework.h>

// Forward declaration — Swift BootLoadingScreen helper
extern void showEarlyLoadingScreen(void) __attribute__((weak_import));

UnityFramework* UnityFrameworkLoad()
{
    NSString* bundlePath = nil;
    bundlePath = [[NSBundle mainBundle] bundlePath];
    bundlePath = [bundlePath stringByAppendingString: @"/Frameworks/UnityFramework.framework"];

    NSBundle* bundle = [NSBundle bundleWithPath: bundlePath];
    if ([bundle isLoaded] == false) [bundle load];

    UnityFramework* ufw = [bundle.principalClass getInstance];
    if (![ufw appController])
    {
        // unity is not initialized
        [ufw setExecuteHeader: &_mh_execute_header];
    }
    return ufw;
}

// Create a loading window BEFORE Unity blocks the main thread
static UIWindow* _earlyLoadingWindow = nil;

void showEarlyLoadingWindow() {
    // Create a window at the highest level
    _earlyLoadingWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _earlyLoadingWindow.windowLevel = UIWindowLevelNormal + 100;
    _earlyLoadingWindow.backgroundColor = [UIColor colorWithRed:0.039 green:0.039 blue:0.102 alpha:1.0];

    // Simple loading UI — matches P. HEXAGON branding
    UIViewController* vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor colorWithRed:0.039 green:0.039 blue:0.102 alpha:1.0];

    // Hexagon symbol
    UILabel* hexLabel = [[UILabel alloc] init];
    hexLabel.text = @"⬡";
    hexLabel.font = [UIFont systemFontOfSize:72];
    hexLabel.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.667 alpha:1.0];
    hexLabel.textAlignment = NSTextAlignmentCenter;
    hexLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:hexLabel];

    // Title
    UILabel* titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"P. HEXAGON";
    titleLabel.font = [UIFont boldSystemFontOfSize:32];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:titleLabel];

    // Subtitle
    UILabel* subLabel = [[UILabel alloc] init];
    subLabel.text = @"GPS Territory Capture Game";
    subLabel.font = [UIFont systemFontOfSize:15];
    subLabel.textColor = [UIColor grayColor];
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:subLabel];

    // Spinner (ANIMATED — will keep spinning even during Unity init!)
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor colorWithRed:0.0 green:1.0 blue:0.667 alpha:1.0];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    [vc.view addSubview:spinner];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [hexLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [hexLabel.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor constant:-80],

        [titleLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:hexLabel.bottomAnchor constant:8],

        [subLabel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],

        [spinner.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:subLabel.bottomAnchor constant:40],
    ]];

    _earlyLoadingWindow.rootViewController = vc;
    [_earlyLoadingWindow makeKeyAndVisible];
    
    // Force render before Unity blocks the thread
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    
    NSLog(@"✅ Early loading window shown BEFORE Unity init");
}

// Public function to dismiss the early loading window (called from Swift)
void dismissEarlyLoadingWindow() {
    if (_earlyLoadingWindow) {
        [UIView animateWithDuration:0.5 animations:^{
            _earlyLoadingWindow.alpha = 0;
        } completion:^(BOOL finished) {
            _earlyLoadingWindow.hidden = YES;
            _earlyLoadingWindow = nil;
            NSLog(@"✅ Early loading window dismissed");
        }];
    }
}

int main(int argc, char* argv[])
{
    @autoreleasepool
    {
        // Show branded loading screen BEFORE Unity blocks the main thread
        showEarlyLoadingWindow();
        
        id ufw = UnityFrameworkLoad();
        [ufw runUIApplicationMainWithArgc: argc argv: argv];
        return 0;
    }
}
