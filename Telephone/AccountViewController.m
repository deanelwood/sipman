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

#import "Telephone-Swift.h"

static NSArray<NSLayoutConstraint *> *FullSizeConstraintsForView(NSView *view);

@interface AccountViewController () <SoftphoneCallTarget>

@property(nonatomic, readonly) ActiveAccountViewController *activeAccountViewController;
@property(nonatomic, readonly) CallHistoryViewController *callHistoryViewController;
@property(nonatomic, readonly) AsyncCallHistoryViewEventTargetFactory *callHistoryViewEventTargetFactory;
@property(nonatomic, readonly) id<Account> account;

@property(nonatomic) CallHistoryViewEventTarget *callHistoryViewEventTarget;
@property(nonatomic) SoftphoneCallHistoryStore *softphoneCallHistoryStore;
@property(nonatomic) SoftphoneMessageStore *softphoneMessageStore;
@property(nonatomic) SoftphoneDiagnosticsStore *softphoneDiagnosticsStore;

@property(nonatomic, weak) IBOutlet NSView *activeAccountView;
@property(nonatomic, weak) IBOutlet NSView *callHistoryView;
@property(nonatomic, weak) IBOutlet NSLayoutConstraint *bottomViewHeightConstraint;

@property(nonatomic, weak) IBOutlet NSLayoutConstraint *activeAccountViewHeightConstraint;
@property(nonatomic, weak) IBOutlet NSLayoutConstraint *horizontalLineHeightConstraint;
@property(nonatomic) CGFloat originalActiveAccountViewHeight;
@property(nonatomic) CGFloat originalHorizontalLineHeight;
@property(nonatomic) NSView *softphoneAppShellView;

- (void)showSoftphoneAppShell;

@end

@implementation AccountViewController

- (BOOL)allowsCallDestinationInput {
    return self.activeAccountViewController.allowsCallDestinationInput;
}

- (instancetype)initWithActiveAccountViewController:(ActiveAccountViewController *)activeAccountViewController
                          callHistoryViewController:(CallHistoryViewController *)callHistoryViewController
                  callHistoryViewEventTargetFactory:(AsyncCallHistoryViewEventTargetFactory *)callHistoryViewEventTargetFactory
                                            account:(id<Account>)account {
    NSParameterAssert(activeAccountViewController);
    NSParameterAssert(callHistoryViewController);
    NSParameterAssert(callHistoryViewEventTargetFactory);
    NSParameterAssert(account);
    if ((self = [super initWithNibName:@"AccountView" bundle:nil])) {
        _activeAccountViewController = activeAccountViewController;
        _callHistoryViewController = callHistoryViewController;
        _callHistoryViewEventTargetFactory = callHistoryViewEventTargetFactory;
        _account = account;
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
    self.softphoneDiagnosticsStore = [[SoftphoneDiagnosticsStore alloc] initWithAccountUUID:self.account.uuid
                                                                                     domain:self.account.domain
                                                                                 sipAddress:self.account.domain];

    [self.callHistoryViewEventTargetFactory makeWithAccount:self.account
                                                       view:self.softphoneCallHistoryStore
                                                 completion:^(CallHistoryViewEventTarget * _Nonnull target) {
                                                     self.callHistoryViewEventTarget = target;
                                                     [self.callHistoryViewEventTarget shouldReloadData];
                                                 }];

    [self showSoftphoneAppShell];
}

#pragma mark -

- (void)showActiveState {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        self.activeAccountViewHeightConstraint.animator.constant = self.originalActiveAccountViewHeight;
        self.horizontalLineHeightConstraint.animator.constant = self.originalHorizontalLineHeight;
    } completionHandler:^{
        [self.softphoneDiagnosticsStore markRegistered];
        [self.activeAccountViewController allowCallDestinationInput];
    }];
}

- (void)showInactiveStateAnimated:(BOOL)animated {
    [self.softphoneDiagnosticsStore markOffline];
    [self.activeAccountViewController disallowCallDestinationInput];
    if (animated) {
        self.activeAccountViewHeightConstraint.animator.constant = 0;
        self.horizontalLineHeightConstraint.animator.constant = 0;
    } else {
        self.activeAccountViewHeightConstraint.constant = 0;
        self.horizontalLineHeightConstraint.constant = 0;
    }
}

- (void)makeCallToDestination:(NSString *)destination {
    self.activeAccountViewController.callDestinationField.tokenStyle = NSTokenStyleRounded;
    self.activeAccountViewController.callDestinationField.stringValue = destination;
    [self.activeAccountViewController makeCall:self];
}

- (void)showSoftphoneAppShell {
    self.softphoneAppShellView = [SoftphoneAppShellViewFactory makeViewWithCallTarget:self
                                                                   accountDisplayName:self.account.domain
                                                                           sipAddress:self.account.domain
                                                                   callHistoryStore:self.softphoneCallHistoryStore
                                                                       messageStore:self.softphoneMessageStore
                                                                   diagnosticsStore:self.softphoneDiagnosticsStore];
    [self.view addSubview:self.softphoneAppShellView];
    [self.view addConstraints:FullSizeConstraintsForView(self.softphoneAppShellView)];
}

- (void)softphoneMakeCallTo:(NSString *)destination {
    [self makeCallToDestination:destination];
}

- (void)softphonePickCallHistoryRecordWithIdentifier:(NSString *)identifier {
    [self.callHistoryViewEventTarget didPickRecordWithIdentifier:identifier];
}

@end

static NSArray<NSLayoutConstraint *> *FullSizeConstraintsForView(NSView *view) {
    NSMutableArray<NSLayoutConstraint *> *result = [NSMutableArray array];
    NSDictionary *views = @{@"view": view};
    [result addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:views]];
    [result addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:views]];
    return result;
}
