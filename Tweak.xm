#import <UIKit/UIKit.h>

@interface ProtectedApp : NSObject

@property (nonatomic, strong) UIWindow *lockWindow;
@property (nonatomic, strong) NSMutableString *enteredCode;
@property (nonatomic, assign) NSInteger failedAttempts;
@property (nonatomic, strong) NSDate *lockoutEndTime;
@property (nonatomic, strong) NSDate *lastBackgroundTime;
@property (nonatomic, assign) BOOL isLockScreenPresented;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

+ (instancetype)sharedInstance;
- (void)presentLockScreenIfNeeded;
- (void)setupLockWindow;
- (void)handleTripleTap;
- (void)showLockScreen;
- (void)numberButtonTapped:(UIButton *)sender;
- (void)checkPasscode;
- (void)resetPasscode;
- (BOOL)isLockedOut;
- (void)applyLockout;
- (void)showLockoutMessage;
- (void)initializePasscodeFileIfNeeded;
- (NSString *)readPasscodeFromDefaults;
- (void)savePasscodeToDefaults:(NSString *)passcode;
- (void)loadLockoutState;
- (void)saveLockoutState;
- (BOOL)isCurrentPasscodeValid:(NSString *)currentPasscode;
- (BOOL)areNewPasscodesValid:(NSString *)newPasscode confirmPasscode:(NSString *)confirmPasscode;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;
- (void)handleWillResignActive;
- (void)handleWillEnterForeground;

@end

@implementation ProtectedApp

+ (instancetype)sharedInstance {
    static ProtectedApp *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(handleWillResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(handleWillResignActive)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(handleWillResignActive)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(handleWillEnterForeground)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(handleWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
                                                   
        [sharedInstance initializePasscodeFileIfNeeded];
        [sharedInstance loadLockoutState];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        sharedInstance.timeoutInterval = [defaults doubleForKey:@"timeoutInterval"];
        if (sharedInstance.timeoutInterval <= 0) {
            sharedInstance.timeoutInterval = 15.0;
        }
    });
    return sharedInstance;
}


- (void)handleWillResignActive {
    if (!self.lockWindow) self.lastBackgroundTime = [NSDate date];
    [self setupLockWindow];
}

- (void)handleWillEnterForeground {
    if (self.lastBackgroundTime) {
        NSTimeInterval timeInBackground = [[NSDate date] timeIntervalSinceDate:self.lastBackgroundTime];
        if (timeInBackground > self.timeoutInterval) {
            [self presentLockScreenIfNeeded];
        } else {
            if (self.lockWindow) {
                self.lockWindow.hidden = YES;
                self.lockWindow = nil;
                self.isLockScreenPresented = NO;
            }
        }
    }
}


- (void)presentLockScreenIfNeeded {
    if (self.isLockScreenPresented) return;

    if (!self.lockWindow || self.lockWindow.hidden) {
        [self setupLockWindow];
    }
    
    if ([self isLockedOut]) {
        [self showLockoutMessage];
        return;
    }
    
    [self showLockScreen];
    self.isLockScreenPresented = YES;
}


- (void)setupLockWindow {
    if (!self.lockWindow) {
        self.lockWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.lockWindow.backgroundColor = [UIColor clearColor];
        self.lockWindow.windowLevel = UIWindowLevelAlert + 99;

        UIViewController *lockViewController = [[UIViewController alloc] init];

        UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurEffectView.frame = lockViewController.view.bounds;
        blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [lockViewController.view addSubview:blurEffectView];

        self.lockWindow.rootViewController = lockViewController;
        [self.lockWindow makeKeyAndVisible];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTripleTap)];
        tap.numberOfTapsRequired = 2;
        tap.numberOfTouchesRequired = 3;
        [self.lockWindow addGestureRecognizer:tap];
    }
}

- (void)handleTripleTap {
    if ([self isLockedOut]) {
        [self showLockoutMessage];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Options"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *changePasscodeAction = [UIAlertAction actionWithTitle:@"Change Passcode" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showChangePasscodeAlert];
    }];

    UIAlertAction *changeTimeoutAction = [UIAlertAction actionWithTitle:@"Change Timeout Interval" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showChangeTimeoutAlert];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:changePasscodeAction];
    [alert addAction:changeTimeoutAction];
    [alert addAction:cancelAction];

    [self.lockWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showChangePasscodeAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Change Passcode"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Enter current passcode";
        textField.secureTextEntry = YES;
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Enter new passcode";
        textField.secureTextEntry = YES;
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Confirm new passcode";
        textField.secureTextEntry = YES;
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *changeAction = [UIAlertAction actionWithTitle:@"Change" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *currentPasscodeField = alert.textFields[0];
        UITextField *newPasscodeField = alert.textFields[1];
        UITextField *confirmPasscodeField = alert.textFields[2];

        NSString *currentPasscode = currentPasscodeField.text;
        NSString *newPasscode = newPasscodeField.text;
        NSString *confirmPasscode = confirmPasscodeField.text;

        if ([self isCurrentPasscodeValid:currentPasscode] && [self areNewPasscodesValid:newPasscode confirmPasscode:confirmPasscode]) {
            self.failedAttempts = 0;
            [self saveLockoutState];
            [self savePasscodeToDefaults:newPasscode];
            [self showAlertWithTitle:@"Success" message:@"Passcode has been changed."];
        } else {
            self.failedAttempts++;
            if (self.failedAttempts >= 5) {
                [self applyLockout];
                [self showLockoutMessage];
            } else {
                [self showAlertWithTitle:@"Error" message:@"Invalid passcode or mismatch. Passcode must be 4 digits."];
            }
        }
    }];

    [alert addAction:cancelAction];
    [alert addAction:changeAction];

    [self.lockWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showChangeTimeoutAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Change Timeout Interval"
                                                                   message:@"Enter the new timeout interval in seconds:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Timeout interval in seconds";
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *changeAction = [UIAlertAction actionWithTitle:@"Change" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *timeoutField = alert.textFields.firstObject;
        NSTimeInterval newTimeoutInterval = [timeoutField.text doubleValue];
        
        if (newTimeoutInterval > 0) {
            self.timeoutInterval = newTimeoutInterval;
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setDouble:newTimeoutInterval forKey:@"timeoutInterval"];
            [defaults synchronize];
            [self showAlertWithTitle:@"Success" message:@"Timeout interval has been changed."];
        } else {
            [self showAlertWithTitle:@"Error" message:@"Invalid timeout interval."];
        }
    }];

    [alert addAction:cancelAction];
    [alert addAction:changeAction];

    [self.lockWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (BOOL)isCurrentPasscodeValid:(NSString *)currentPasscode {
    NSString *savedPasscode = [self readPasscodeFromDefaults];
    return [currentPasscode isEqualToString:savedPasscode];
}

- (BOOL)areNewPasscodesValid:(NSString *)newPasscode confirmPasscode:(NSString *)confirmPasscode {
    NSCharacterSet *nonDigitCharacterSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    BOOL isNumeric = ([newPasscode rangeOfCharacterFromSet:nonDigitCharacterSet].location == NSNotFound);
    return isNumeric && newPasscode.length == 4 && [newPasscode isEqualToString:confirmPasscode];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self.lockWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showLockScreen {
    self.enteredCode = [NSMutableString string];

    UIViewController *lockViewController = self.lockWindow.rootViewController;

    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;

    CGFloat buttonWidth = screenWidth / 5;
    CGFloat buttonHeight = buttonWidth;

    CGFloat totalWidth = buttonWidth * 3 + 40;
    CGFloat totalHeight = buttonHeight * 4 + 60;

    CGFloat centerX = screenWidth / 2;
    CGFloat startY = (screenHeight - totalHeight - 150) / 2;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 220, 50)];
    label.center = CGPointMake(centerX, startY);
    label.text = @"Enter Passcode";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    [lockViewController.view addSubview:label];

    UIView *codeInputView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
    codeInputView.center = CGPointMake(centerX, CGRectGetMaxY(label.frame) + 40);
    codeInputView.tag = 100;
    [lockViewController.view addSubview:codeInputView];

    CGFloat dotSize = 20;
    CGFloat space = (codeInputView.bounds.size.width - 4 * dotSize) / 3;

    for (int i = 0; i < 4; i++) {
        UIView *dotView = [[UIView alloc] initWithFrame:CGRectMake(i * (dotSize + space), 0, dotSize, dotSize)];
        dotView.layer.cornerRadius = dotSize / 2;
        dotView.layer.borderColor = [[UIColor whiteColor] CGColor];
        dotView.layer.borderWidth = 1.0;
        dotView.backgroundColor = [UIColor clearColor];
        dotView.layer.masksToBounds = YES;
        dotView.tag = i + 1;
        [codeInputView addSubview:dotView];
    }

    startY = CGRectGetMaxY(codeInputView.frame) + 40;

    NSArray *buttonTitles = @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"];

    for (int i = 0; i < 9; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(centerX - totalWidth / 2 + (i % 3) * (buttonWidth + 20),
                                  startY + (i / 3) * (buttonHeight + 20),
                                  buttonWidth, buttonHeight);
        [button setTitle:buttonTitles[i] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:buttonHeight / 2];
        button.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
        button.layer.cornerRadius = buttonWidth / 2;
        button.layer.masksToBounds = YES;
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(numberButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = [buttonTitles[i] intValue];
        [lockViewController.view addSubview:button];
    }

    UIButton *zeroButton = [UIButton buttonWithType:UIButtonTypeSystem];
    zeroButton.frame = CGRectMake(centerX - buttonWidth / 2,
                                  startY + 3 * (buttonHeight + 20),
                                  buttonWidth, buttonHeight);
    [zeroButton setTitle:@"0" forState:UIControlStateNormal];
    zeroButton.titleLabel.font = [UIFont systemFontOfSize:buttonHeight / 2];
    zeroButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    zeroButton.layer.cornerRadius = buttonWidth / 2;
    zeroButton.layer.masksToBounds = YES;
    [zeroButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [zeroButton addTarget:self action:@selector(numberButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    zeroButton.tag = 0;
    [lockViewController.view addSubview:zeroButton];
}

- (void)numberButtonTapped:(UIButton *)sender {
    if (self.enteredCode.length < 4) {
        [self.enteredCode appendString:[NSString stringWithFormat:@"%ld", (long)sender.tag]];

        UIView *codeInputView = [self.lockWindow.rootViewController.view viewWithTag:100];
        UIView *dotView = [codeInputView viewWithTag:self.enteredCode.length];
        dotView.backgroundColor = [UIColor whiteColor];

        if (self.enteredCode.length == 4) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self checkPasscode];
            });
        }
    }
}

- (void)checkPasscode {
    NSString *correctPasscode = [self readPasscodeFromDefaults];
    if ([self.enteredCode isEqualToString:correctPasscode]) {
        self.failedAttempts = 0;
        [self saveLockoutState];
        [self.lockWindow resignKeyWindow];
        self.lockWindow.hidden = YES;
        self.lockWindow = nil;
        self.isLockScreenPresented = NO;
    } else {
        self.failedAttempts++;
        if (self.failedAttempts >= 5) {
            [self applyLockout];
        } else {
            [self resetPasscode];
        }
    }
}


- (void)resetPasscode {
    [self.enteredCode setString:@""];
    
    UIView *codeInputView = [self.lockWindow.rootViewController.view viewWithTag:100];
    for (int i = 1; i <= 4; i++) {
        UIView *dotView = [codeInputView viewWithTag:i];
        dotView.backgroundColor = [UIColor clearColor];
        dotView.layer.borderColor = [[UIColor whiteColor] CGColor];
        dotView.layer.borderWidth = 1.0;
    }
}

- (BOOL)isLockedOut {
    if (!self.lockoutEndTime) return NO;
    return [[NSDate date] compare:self.lockoutEndTime] == NSOrderedAscending;
}

- (void)applyLockout {
    NSInteger lockoutMinutes = pow(2, self.failedAttempts - 5);
    self.lockoutEndTime = [[NSDate date] dateByAddingTimeInterval:lockoutMinutes * 60 + 1];
    [self saveLockoutState];
    [self showLockoutMessage];
}

- (void)showLockoutMessage {
    NSTimeInterval timeRemaining = [self.lockoutEndTime timeIntervalSinceNow];
    
    NSInteger seconds = (NSInteger)timeRemaining % 60;
    NSInteger minutes = ((NSInteger)timeRemaining / 60) % 60;
    NSInteger hours = ((NSInteger)timeRemaining / 3600) % 24;
    NSInteger days = ((NSInteger)timeRemaining / (3600 * 24)) % 30;
    NSInteger months = ((NSInteger)timeRemaining / (3600 * 24 * 30)) % 12;
    NSInteger years = (NSInteger)timeRemaining / (3600 * 24 * 365);
    
    NSMutableArray *timeComponents = [NSMutableArray array];
    
    if (years > 0) {
        [timeComponents addObject:[NSString stringWithFormat:@"%ld years", (long)years]];
    }
    if (months > 0) {
        [timeComponents addObject:[NSString stringWithFormat:@"%ld months", (long)months]];
    }
    if (days > 0) {
        [timeComponents addObject:[NSString stringWithFormat:@"%ld days", (long)days]];
    }
    if (hours > 0) {
        [timeComponents addObject:[NSString stringWithFormat:@"%ld hours", (long)hours]];
    }
    if (minutes > 0) {
        [timeComponents addObject:[NSString stringWithFormat:@"%ld minutes", (long)minutes]];
    }
    if (seconds > 0) {
        [timeComponents addObject:[NSString stringWithFormat:@"%ld seconds", (long)seconds]];
    }

    NSString *message = [NSString stringWithFormat:@"Try again in %@", [timeComponents componentsJoinedByString:@", "]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Locked Out"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self.lockWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}



- (void)initializePasscodeFileIfNeeded {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *storedData = [defaults objectForKey:@"com.tien0246.ProtectedApp"];
    
    if (!storedData || !storedData[@"passcode"]) {
        [self savePasscodeToDefaults:@"0000"];
    }
}

- (NSString *)readPasscodeFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *storedData = [defaults objectForKey:@"com.tien0246.ProtectedApp"];
    return storedData[@"passcode"];
}

- (void)savePasscodeToDefaults:(NSString *)passcode {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *storedData = [[defaults objectForKey:@"com.tien0246.ProtectedApp"] mutableCopy] ?: [NSMutableDictionary dictionary];
    storedData[@"passcode"] = passcode;
    [defaults setObject:storedData forKey:@"com.tien0246.ProtectedApp"];
    [defaults synchronize];
}

- (void)loadLockoutState {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *storedData = [defaults objectForKey:@"com.tien0246.ProtectedApp"];
    
    if (storedData) {
        self.failedAttempts = [storedData[@"failedAttempts"] integerValue];
        self.lockoutEndTime = storedData[@"lockoutEndTime"];
    } else {
        self.failedAttempts = 0;
        self.lockoutEndTime = nil;
    }
}

- (void)saveLockoutState {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *storedData = [[defaults objectForKey:@"com.tien0246.ProtectedApp"] mutableCopy] ?: [NSMutableDictionary dictionary];
    
    storedData[@"failedAttempts"] = @(self.failedAttempts);
    storedData[@"lockoutEndTime"] = self.lockoutEndTime;
    
    [defaults setObject:storedData forKey:@"com.tien0246.ProtectedApp"];
    [defaults synchronize];
}

@end








%hook UIWindow
BOOL isShowLockScreen = NO;
- (void)makeKeyAndVisible {
    if (!isShowLockScreen) {
        [[ProtectedApp sharedInstance] presentLockScreenIfNeeded];
        isShowLockScreen = YES;
    }
    return %orig;
}

%end