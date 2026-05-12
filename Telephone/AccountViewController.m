//
//  AccountViewController.m
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2022 64 Characters
//
//  Telephone is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Telephone is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

#import "AccountViewController.h"

#import "ActiveAccountViewController.h"
#import "AKSIPAccount.h"
#import "AKSIPUserAgent.h"
#import "PreferencesControllerNotifications.h"

#import "Telephone-Swift.h"

static NSArray<NSLayoutConstraint *> *FullSizeConstraintsForView(NSView *view);
static NSString *SoftphoneServerAddressString(NSString *host, NSInteger port);

@interface AccountViewController () <SoftphoneCallTarget>

@property(nonatomic, readonly) ActiveAccountViewController *activeAccountViewController;
@property(nonatomic, readonly) CallHistoryViewController *callHistoryViewController;
@property(nonatomic, readonly) AsyncCallHistoryViewEventTargetFactory *callHistoryViewEventTargetFactory;
@property(nonatomic, readonly) id<Account> account;
@property(nonatomic, readonly, weak) id<SoftphoneCallControlling> callControlTarget;

@property(nonatomic) CallHistoryViewEventTarget *callHistoryViewEventTarget;
@property(nonatomic) SoftphoneCallHistoryStore *softphoneCallHistoryStore;
@property(nonatomic) SoftphoneMessageStore *softphoneMessageStore;
@property(nonatomic) SoftphoneDiagnosticsStore *softphoneDiagnosticsStore;
@property(nonatomic) SoftphoneActiveCallStore *softphoneActiveCallStore;

@property(nonatomic, weak) IBOutlet NSView *activeAccountView;
@property(nonatomic, weak) IBOutlet NSView *callHistoryView;
@property(nonatomic, weak) IBOutlet NSLayoutConstraint *bottomViewHeightConstraint;

@property(nonatomic, weak) IBOutlet NSLayoutConstraint *activeAccountViewHeightConstraint;
@property(nonatomic, weak) IBOutlet NSLayoutConstraint *horizontalLineHeightConstraint;
@property(nonatomic) CGFloat originalActiveAccountViewHeight;
@property(nonatomic) CGFloat originalHorizontalLineHeight;
@property(nonatomic) NSView *softphoneAppShellView;
@property(nonatomic) BOOL softphoneAllowsCallDestinationInput;

- (void)showSoftphoneAppShell;
- (void)hideLegacyAccountViews;
- (AKSIPAccount *)softphoneSIPAccount;

@end

@implementation AccountViewController

- (BOOL)allowsCallDestinationInput {
    return self.softphoneAllowsCallDestinationInput;
}

- (instancetype)initWithActiveAccountViewController:(ActiveAccountViewController *)activeAccountViewController
                  callHistoryViewController:(CallHistoryViewController *)callHistoryViewController
          callHistoryViewEventTargetFactory:(AsyncCallHistoryViewEventTargetFactory *)callHistoryViewEventTargetFactory
                                    account:(id<Account>)account
                          callControlTarget:(id<SoftphoneCallControlling>)callControlTarget {
    NSParameterAssert(activeAccountViewController);
    NSParameterAssert(callHistoryViewController);
    NSParameterAssert(callHistoryViewEventTargetFactory);
    NSParameterAssert(account);
    NSParameterAssert(callControlTarget);
    if ((self = [super initWithNibName:@"AccountView" bundle:nil])) {
        _activeAccountViewController = activeAccountViewController;
        _callHistoryViewController = callHistoryViewController;
        _callHistoryViewEventTargetFactory = callHistoryViewEventTargetFactory;
        _account = account;
        _callControlTarget = callControlTarget;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.originalActiveAccountViewHeight = self.activeAccountViewHeightConstraint.constant;
    self.originalHorizontalLineHeight = self.horizontalLineHeightConstraint.constant;

    [self.activeAccountView addSubview:self.activeAccountViewController.view];
    [self.activeAccountView addConstraints:FullSizeConstraintsForView(self.activeAccountViewController.view)];

    [self.callHistoryView addSubview:self.callHistoryViewController.view];
    [self.callHistoryView addConstraints:FullSizeConstraintsForView(self.callHistoryViewController.view)];

    [self.activeAccountViewController updateNextKeyView:self.callHistoryViewController.keyView];
    [self.callHistoryViewController updateNextKeyView:self.activeAccountViewController.keyView];

    self.bottomViewHeightConstraint.constant = 0;

    self.softphoneCallHistoryStore = [[SoftphoneCallHistoryStore alloc] init];
    self.softphoneMessageStore = [[SoftphoneMessageStore alloc] initWithAccountUUID:self.account.uuid
                                                                     accountAddress:self.account.domain];
    AKSIPAccount *SIPAccount = [self softphoneSIPAccount];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.softphoneDiagnosticsStore = [[SoftphoneDiagnosticsStore alloc] initWithAccountUUID:self.account.uuid
                                                                                     domain:self.account.domain
                                                                                 sipAddress:(SIPAccount.SIPAddress ?: self.account.domain)
                                                                                   username:(SIPAccount.username ?: @"")
                                                                             passwordStatus:(SIPAccount.username.length > 0 ? @"Stored in Keychain" : @"Not configured")
                                                                          stunServerAddress:SoftphoneServerAddressString([defaults stringForKey:UserDefaultsKeys.stunServerHost],
                                                                                                                         [defaults integerForKey:UserDefaultsKeys.stunServerPort])
                                                                          turnServerAddress:SoftphoneServerAddressString([defaults stringForKey:UserDefaultsKeys.turnServerHost],
                                                                                                                         [defaults integerForKey:UserDefaultsKeys.turnServerPort])
                                                                                     usesICE:[defaults boolForKey:UserDefaultsKeys.useICE]];
    self.softphoneActiveCallStore = [[SoftphoneActiveCallStore alloc] init];

    [self.callHistoryViewEventTargetFactory makeWithAccount:self.account
                                                       view:self.softphoneCallHistoryStore
                                                 completion:^(CallHistoryViewEventTarget * _Nonnull target) {
                                                     self.callHistoryViewEventTarget = target;
                                                     [self.callHistoryViewEventTarget shouldReloadData];
                                                 }];

    [self showSoftphoneAppShell];
    [self hideLegacyAccountViews];
}

#pragma mark -

- (void)showActiveState {
    self.softphoneAllowsCallDestinationInput = YES;
    [self.softphoneDiagnosticsStore markRegistered];
    [self hideLegacyAccountViews];
}

- (void)showInactiveStateAnimated:(BOOL)animated {
    self.softphoneAllowsCallDestinationInput = NO;
    [self.softphoneDiagnosticsStore markOffline];
    [self hideLegacyAccountViews];
}

- (void)makeCallToDestination:(NSString *)destination {
    self.activeAccountViewController.callDestinationField.tokenStyle = NSTokenStyleRounded;
    self.activeAccountViewController.callDestinationField.stringValue = destination;
    [self.activeAccountViewController makeCall:self];
}

- (void)showSoftphoneAppShell {
    self.softphoneAppShellView = [SoftphoneAppShellViewFactory makeViewWithCallTarget:self
                                                                   accountDisplayName:self.account.username
                                                                           sipAddress:([self softphoneSIPAccount].SIPAddress ?: self.account.domain)
                                                                   callHistoryStore:self.softphoneCallHistoryStore
                                                                       messageStore:self.softphoneMessageStore
                                                                   diagnosticsStore:self.softphoneDiagnosticsStore
                                                                    activeCallStore:self.softphoneActiveCallStore];
    [self.view addSubview:self.softphoneAppShellView];
    [self.view addConstraints:FullSizeConstraintsForView(self.softphoneAppShellView)];
}

- (void)hideLegacyAccountViews {
    [self.activeAccountViewController disallowCallDestinationInput];
    if ([self.view.window.firstResponder isEqual:self.activeAccountViewController.callDestinationField]) {
        [self.view.window makeFirstResponder:nil];
    }
    self.activeAccountView.hidden = YES;
    self.callHistoryView.hidden = YES;
    self.activeAccountViewHeightConstraint.constant = 0;
    self.horizontalLineHeightConstraint.constant = 0;
    self.bottomViewHeightConstraint.constant = 0;
}

- (AKSIPAccount *)softphoneSIPAccount {
    return [(id)self.account isKindOfClass:[AKSIPAccount class]] ? (AKSIPAccount *)self.account : nil;
}

- (void)updateSoftphoneCallWithIdentifier:(NSString *)identifier
                              remoteParty:(NSString *)remoteParty
                                   status:(NSString *)status
                                 duration:(NSString *)duration
                                  isMuted:(BOOL)isMuted
                                 isOnHold:(BOOL)isOnHold
                            statsSnapshot:(CallStatsSnapshot *)statsSnapshot {
    (void)self.view;
    [self.softphoneActiveCallStore upsertCallWithIdentifier:identifier
                                                remoteParty:remoteParty
                                                     status:status
                                                   duration:duration
                                                    isMuted:isMuted
                                                   isOnHold:isOnHold
                                              statsSnapshot:statsSnapshot];
    [self.softphoneDiagnosticsStore updateActiveCallWithIdentifier:identifier
                                                       remoteParty:remoteParty
                                                            status:status
                                                          duration:duration
                                                     statsSnapshot:statsSnapshot];
}

- (void)removeSoftphoneCallWithIdentifier:(NSString *)identifier {
    (void)self.view;
    [self.softphoneActiveCallStore removeCallWithIdentifier:identifier];
    [self.softphoneDiagnosticsStore removeActiveCallWithIdentifier:identifier];
}

- (void)softphoneMakeCallTo:(NSString *)destination {
    [self makeCallToDestination:destination];
}

- (void)softphonePickCallHistoryRecordWithIdentifier:(NSString *)identifier {
    [self.callHistoryViewEventTarget didPickRecordWithIdentifier:identifier];
}

- (void)softphoneHangUpCallWithIdentifier:(NSString *)identifier {
    [self.callControlTarget hangUpCallWithIdentifier:identifier];
    [self.softphoneActiveCallStore removeCallWithIdentifier:identifier];
    [self.softphoneDiagnosticsStore removeActiveCallWithIdentifier:identifier];
}

- (void)softphoneToggleMuteForCallWithIdentifier:(NSString *)identifier {
    [self.callControlTarget toggleMicrophoneMuteForCallWithIdentifier:identifier];
}

- (void)softphoneToggleHoldForCallWithIdentifier:(NSString *)identifier {
    [self.callControlTarget toggleHoldForCallWithIdentifier:identifier];
}

- (void)softphoneSendDTMFDigit:(NSString *)digit forCallWithIdentifier:(NSString *)identifier {
    [self.callControlTarget sendDTMFDigits:digit forCallWithIdentifier:identifier];
}

- (void)softphoneSendSIPOptionsPingTo:(NSString *)destination
                            transport:(NSString *)transport
                            completion:(void (^)(NSDictionary<NSString *,id> * _Nonnull))completion {
    AKSIPAccount *account = [(id)self.account isKindOfClass:[AKSIPAccount class]] ? (AKSIPAccount *)self.account : nil;
    [[AKSIPUserAgent sharedUserAgent] sendSIPOptionsPingTo:destination
                                                  transport:transport
                                                    account:account
                                                 completion:completion];
}

- (void)softphoneSaveNetworkSettings:(NSDictionary<NSString *,id> *)settings {
    NSString *STUNServerHost = [settings[UserDefaultsKeys.stunServerHost] isKindOfClass:[NSString class]] ? settings[UserDefaultsKeys.stunServerHost] : @"";
    NSInteger STUNServerPort = [settings[UserDefaultsKeys.stunServerPort] integerValue];
    NSString *TURNServerHost = [settings[UserDefaultsKeys.turnServerHost] isKindOfClass:[NSString class]] ? settings[UserDefaultsKeys.turnServerHost] : @"";
    NSInteger TURNServerPort = [settings[UserDefaultsKeys.turnServerPort] integerValue];
    BOOL useICE = [settings[UserDefaultsKeys.useICE] boolValue];

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:STUNServerHost forKey:UserDefaultsKeys.stunServerHost];
    [defaults setInteger:STUNServerPort forKey:UserDefaultsKeys.stunServerPort];
    [defaults setObject:TURNServerHost forKey:UserDefaultsKeys.turnServerHost];
    [defaults setInteger:TURNServerPort forKey:UserDefaultsKeys.turnServerPort];
    [defaults setBool:useICE forKey:UserDefaultsKeys.useICE];

    [self.softphoneDiagnosticsStore updateNetworkSettingsWithStunServerAddress:SoftphoneServerAddressString(STUNServerHost, STUNServerPort)
                                                             turnServerAddress:SoftphoneServerAddressString(TURNServerHost, TURNServerPort)
                                                                        usesICE:useICE];

    [[NSNotificationCenter defaultCenter] postNotificationName:AKPreferencesControllerDidChangeNetworkSettingsNotification
                                                        object:self];
}

@end

static NSArray<NSLayoutConstraint *> *FullSizeConstraintsForView(NSView *view) {
    NSMutableArray<NSLayoutConstraint *> *result = [NSMutableArray array];
    NSDictionary *views = @{@"view": view};
    [result addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:views]];
    [result addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:views]];
    return result;
}

static NSString *SoftphoneServerAddressString(NSString *host, NSInteger port) {
    NSString *trimmedHost = [host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedHost.length == 0) {
        return @"";
    }
    if (port > 0 && port <= 65535) {
        return [[ServiceAddress alloc] initWithHost:trimmedHost port:@(port).stringValue].stringValue;
    }
    return [[ServiceAddress alloc] initWithHost:trimmedHost].stringValue;
}
