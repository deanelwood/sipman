//
//  AccountViewController.h
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

@import Cocoa;

@class ActiveAccountViewController, CallHistoryViewController;
@class AsyncCallHistoryViewEventTargetFactory;
@class CallStatsSnapshot;
@protocol Account;

NS_ASSUME_NONNULL_BEGIN

@protocol SoftphoneCallControlling <NSObject>

- (void)hangUpCallWithIdentifier:(NSString *)identifier;
- (void)toggleMicrophoneMuteForCallWithIdentifier:(NSString *)identifier;
- (void)sendDTMFDigits:(NSString *)digits forCallWithIdentifier:(NSString *)identifier;

@end

@interface AccountViewController : NSViewController

@property(nonatomic, readonly) BOOL allowsCallDestinationInput;

- (instancetype)initWithActiveAccountViewController:(ActiveAccountViewController *)activeAccountViewController
                  callHistoryViewController:(CallHistoryViewController *)callHistoryViewController
          callHistoryViewEventTargetFactory:(AsyncCallHistoryViewEventTargetFactory *)callHistoryViewEventTargetFactory
                                    account:(id<Account>)account
                          callControlTarget:(id<SoftphoneCallControlling>)callControlTarget;

- (void)showActiveState;
- (void)showInactiveStateAnimated:(BOOL)animated;

- (void)makeCallToDestination:(NSString *)destination;
- (void)updateSoftphoneCallWithIdentifier:(NSString *)identifier
                              remoteParty:(NSString *)remoteParty
                                   status:(NSString *)status
                                 duration:(NSString *)duration
                                  isMuted:(BOOL)isMuted
                                 isOnHold:(BOOL)isOnHold
                            statsSnapshot:(nullable CallStatsSnapshot *)statsSnapshot;
- (void)removeSoftphoneCallWithIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
