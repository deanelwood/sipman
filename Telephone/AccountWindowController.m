//
//  AccountWindowController.m
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

#import "AccountWindowController.h"

#import "AccountViewController.h"
#import "CallController.h"

#import "Telephone-Swift.h"

@interface AccountWindowController ()

@property(nonatomic, readonly) NSString *accountDescription;
@property(nonatomic, readonly) NSString *SIPAddress;
@property(nonatomic, readonly) AccountViewController *accountViewController;
@property(nonatomic, readonly, weak) id<AccountWindowControllerDelegate> delegate;

@property(nonatomic, weak) IBOutlet NSImageView *accountStateImageView;
@property(nonatomic, weak) IBOutlet NSPopUpButton *accountStatePopUp;
@property(nonatomic, weak) IBOutlet NSMenuItem *availableStateItem;
@property(nonatomic, weak) IBOutlet NSMenuItem *unavailableStateItem;
@property(nonatomic, weak) IBOutlet NSMenuItem *offlineStateItem;

@end

@implementation AccountWindowController

- (NSString *)windowTitle {
    NSString *username = [self usernameFromAddress:self.SIPAddress];
    if (username.length == 0) {
        username = [self usernameFromAddress:self.accountDescription];
    }
    if (username.length == 0) {
        username = self.accountDescription;
    }
    return [NSString stringWithFormat:@"SIPman - %@", username];
}

- (NSString *)usernameFromAddress:(NSString *)address {
    NSString *username = [address stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([username hasPrefix:@"sip:"]) {
        username = [username substringFromIndex:4];
    }

    NSRange displayNameStart = [username rangeOfString:@"<"];
    NSRange displayNameEnd = [username rangeOfString:@">"];
    if (displayNameStart.location != NSNotFound &&
        displayNameEnd.location != NSNotFound &&
        displayNameEnd.location > displayNameStart.location) {
        NSRange addressRange = NSMakeRange(displayNameStart.location + 1,
                                           displayNameEnd.location - displayNameStart.location - 1);
        username = [username substringWithRange:addressRange];
    }

    NSRange domainSeparator = [username rangeOfString:@"@"];
    if (domainSeparator.location == NSNotFound) {
        return username;
    }
    return [username substringToIndex:domainSeparator.location];
}

- (BOOL)allowsCallDestinationInput {
    return self.accountViewController.allowsCallDestinationInput;
}

- (instancetype)initWithAccountDescription:(NSString *)accountDescription
                                SIPAddress:(NSString *)SIPAddress
                     accountViewController:(AccountViewController *)accountViewController
                                  delegate:(id<AccountWindowControllerDelegate>)delegate {

    NSParameterAssert(accountDescription);
    NSParameterAssert(SIPAddress);
    NSParameterAssert(accountViewController);
    NSParameterAssert(delegate);
    if ((self = [super initWithWindowNibName:@"Account"])) {
        _accountDescription = [accountDescription copy];
        _SIPAddress = [SIPAddress copy];
        _accountViewController = accountViewController;
        _delegate = delegate;
    }
    return self;
}

- (void)awakeFromNib {
    self.shouldCascadeWindows = NO;
}

- (void)windowDidLoad {
    self.window.title = self.windowTitle;
    self.window.frameAutosaveName = self.SIPAddress;
    self.window.excludedFromWindowsMenu = YES;
    self.window.toolbar = nil;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    self.window.styleMask |= NSWindowStyleMaskFullSizeContentView;
    self.window.movableByWindowBackground = YES;

    [self.window.contentView addSubview:self.accountViewController.view];
    self.accountViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = @{@"view": self.accountViewController.view};
    [self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:views]];
    [self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:views]];

    [self showOfflineStateAnimated:NO];
}

#pragma mark -

- (void)showAvailableState {
    self.accountStatePopUp.title = NSLocalizedString(@"Available", @"Account registration Available menu item.");
    self.accountStateImageView.image = [NSImage imageNamed:@"available-state"];

    self.availableStateItem.state = NSControlStateValueOn;
    self.unavailableStateItem.state = NSControlStateValueOff;

    [self.accountViewController showActiveState];
}

- (void)showUnavailableState {
    self.accountStatePopUp.title = NSLocalizedString(@"Unavailable", @"Account registration Unavailable menu item.");
    self.accountStateImageView.image = [NSImage imageNamed:@"unavailable-state"];

    self.availableStateItem.state = NSControlStateValueOff;
    self.unavailableStateItem.state = NSControlStateValueOn;

    [self.accountViewController showUnavailableState];
}

- (void)showOfflineStateAnimated:(BOOL)animated {
    self.accountStatePopUp.title = NSLocalizedString(@"Offline", @"Account registration Offline menu item.");
    self.accountStateImageView.image = [NSImage imageNamed:@"offline-state"];

    self.availableStateItem.state = NSControlStateValueOff;
    self.unavailableStateItem.state = NSControlStateValueOff;

    [self.accountViewController showInactiveStateAnimated:animated];
}

- (void)showOfflineState {
    [self showOfflineStateAnimated:YES];
}

- (void)showConnectingState {
    [[self accountStatePopUp] setTitle:
     NSLocalizedString(@"Connecting...", @"Account registration Connecting... menu item.")];
    [self.accountViewController showConnectingState];
}

- (void)makeCallToDestination:(NSString *)destination {
    [self.accountViewController makeCallToDestination:destination];
}

- (void)updateSoftphoneCallWithController:(CallController *)callController {
    [self.accountViewController updateSoftphoneCallWithIdentifier:callController.identifier
                                                      remoteParty:[self remotePartyForCallController:callController]
                                                           status:[self statusForCallController:callController]
                                                         duration:[self durationForCallController:callController]
                                                          isMuted:callController.call.isMicrophoneMuted
                                                         isOnHold:[self isCallControllerOnHold:callController]
                                                    statsSnapshot:[callController.call callStatsSnapshot]];
}

- (void)removeSoftphoneCallWithController:(CallController *)callController {
    [self.accountViewController removeSoftphoneCallWithIdentifier:callController.identifier];
}

- (NSString *)remotePartyForCallController:(CallController *)callController {
    if (callController.displayedName.length > 0) {
        return callController.displayedName;
    }
    if (callController.title.length > 0) {
        return callController.title;
    }
    return @"Unknown caller";
}

- (NSString *)statusForCallController:(CallController *)callController {
    if ([self isDurationStatus:callController.status]) {
        return NSLocalizedString(@"connected", @"Connected call status text.");
    }
    return callController.status ?: @"";
}

- (NSString *)durationForCallController:(CallController *)callController {
    if (callController.callStartTime <= 0 || !callController.isCallActive) {
        return @"";
    }

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSInteger seconds = (NSInteger)(now - callController.callStartTime);
    if (seconds < 0) {
        seconds = 0;
    }

    if (seconds < 3600) {
        return [NSString stringWithFormat:@"%02ld:%02ld", (seconds / 60) % 60, seconds % 60];
    }
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (seconds / 3600) % 24, (seconds / 60) % 60, seconds % 60];
}

- (BOOL)isDurationStatus:(NSString *)status {
    NSCharacterSet *characters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789:"];
    return status.length > 0 && [status rangeOfCharacterFromSet:[characters invertedSet]].location == NSNotFound;
}

- (BOOL)isCallControllerOnHold:(CallController *)callController {
    return callController.isCallOnHold || callController.call.isOnLocalHold || callController.call.isOnRemoteHold;
}

- (IBAction)changeAccountState:(NSPopUpButton *)sender {
    if ([sender.selectedItem isEqual:self.offlineStateItem]) {
        [self.delegate accountWindowController:self didChangeAccountState:AccountWindowControllerAccountStateOffline];
    } else if ([sender.selectedItem isEqual:self.availableStateItem]) {
        [self.delegate accountWindowController:self didChangeAccountState:AccountWindowControllerAccountStateAvailable];
    } else if ([sender.selectedItem isEqual:self.unavailableStateItem]) {
        [self.delegate accountWindowController:self didChangeAccountState:AccountWindowControllerAccountStateUnavailable];
    }
}

- (void)showAlert:(NSAlert *)alert {
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)beginSheet:(NSWindow *)sheet {
    [self.window beginSheet:sheet completionHandler:nil];
}

- (void)showWindowWithoutMakingKey {
    [self.window orderFront:self];
}

- (void)hideWindow {
    [self.window orderOut:self];
}

- (BOOL)isWindowKey {
    return self.window.isKeyWindow;
}

- (void)orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)otherWindow {
    [self.window orderWindow:place relativeTo:otherWindow];
}

- (NSInteger)windowNumber {
    return self.window.windowNumber;
}

#pragma mark - NSWindowDelegate

- (BOOL)windowShouldClose:(id)sender {
    [self.window orderOut:self];
    return NO;
}

@end
