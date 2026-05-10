//
//  AKSIPCall.m
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

#import "AKSIPCall.h"

#import "AKNSString+PJSUA.h"
#import "AKSIPAccount.h"
#import "AKSIPURI.h"
#import "AKSIPUserAgent.h"
#import "PJSUACallInfo.h"

#import <pjmedia/transport_ice.h>

#import "Telephone-Swift.h"

#define THIS_FILE "AKSIPCall.m"
#define AKInvalidMediaIndex ((unsigned)-1)


@interface AKSIPCall () {
    URI *_remote;
    BOOL _incoming;
    BOOL _missed;
}

@property(nonatomic, getter=isMicrophoneMuted) BOOL microphoneMuted;

@end

static void AddTextRow(NSMutableArray<CallStatsRow *> *rows, NSString *metric, NSString *live);
static void AddIntegerRow(NSMutableArray<CallStatsRow *> *rows, NSString *metric, NSUInteger value);
static void AddDoubleMillisecondsRow(NSMutableArray<CallStatsRow *> *rows, NSString *metric, double value);
static NSString *PJString(pj_str_t value);
static NSString *AddressString(const pj_sockaddr *address);
static NSString *ICECandidateTypeName(pj_ice_cand_type type);
static NSString *ICEComponentPairString(pjmedia_ice_transport_info *info, unsigned componentIndex);
static NSString *ICEPathType(pjmedia_ice_transport_info *info, unsigned componentIndex);
static BOOL ICEComponentUsesRelay(pjmedia_ice_transport_info *info, unsigned componentIndex);
static unsigned FirstAudioMediaIndex(const pjsua_call_info *callInfo);

@implementation AKSIPCall

- (void)setDelegate:(id<AKSIPCallDelegate>)aDelegate {
    if (_delegate == aDelegate) {
        return;
    }
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    if (_delegate != nil) {
        [notificationCenter removeObserver:_delegate name:nil object:self];
    }
    
    if (aDelegate != nil) {
        // Subscribe to notifications
        if ([aDelegate respondsToSelector:@selector(SIPCallCalling:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallCalling:)
                                       name:AKSIPCallCallingNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallIncoming:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallIncoming:)
                                       name:AKSIPCallIncomingNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallEarly:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallEarly:)
                                       name:AKSIPCallEarlyNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallConnecting:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallConnecting:)
                                       name:AKSIPCallConnectingNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallDidConfirm:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallDidConfirm:)
                                       name:AKSIPCallDidConfirmNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallDidDisconnect:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallDidDisconnect:)
                                       name:AKSIPCallDidDisconnectNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallMediaDidBecomeActive:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallMediaDidBecomeActive:)
                                       name:AKSIPCallMediaDidBecomeActiveNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallDidLocalHold:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallDidLocalHold:)
                                       name:AKSIPCallDidLocalHoldNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallDidRemoteHold:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallDidRemoteHold:)
                                       name:AKSIPCallDidRemoteHoldNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPCallTransferStatusDidChange:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPCallTransferStatusDidChange:)
                                       name:AKSIPCallTransferStatusDidChangeNotification
                                     object:self];
        }
    }
    
    _delegate = aDelegate;
}

- (URI *)remote {
    return _remote;
}

- (BOOL)isIncoming {
    return _incoming;
}

- (BOOL)isMissed {
    return _missed;
}

- (void)setMissed:(BOOL)flag {
    _missed = flag;
}

- (BOOL)isActive {
    if ([self identifier] == kAKSIPUserAgentInvalidIdentifier) {
        return NO;
    }
    
    return (pjsua_call_is_active((pjsua_call_id)[self identifier])) ? YES : NO;
}

- (BOOL)isOnLocalHold {
    if ([self identifier] == kAKSIPUserAgentInvalidIdentifier) {
        return NO;
    }
    
    pjsua_call_info callInfo;
    pjsua_call_get_info((pjsua_call_id)[self identifier], &callInfo);
    
    return (callInfo.media[0].status == PJSUA_CALL_MEDIA_LOCAL_HOLD) ? YES : NO;
}

- (BOOL)isOnRemoteHold {
    if ([self identifier] == kAKSIPUserAgentInvalidIdentifier) {
        return NO;
    }
    
    pjsua_call_info callInfo;
    pjsua_call_get_info((pjsua_call_id)[self identifier], &callInfo);
    
    return (callInfo.media[0].status == PJSUA_CALL_MEDIA_REMOTE_HOLD) ? YES : NO;
}

- (CallStatsSnapshot *)callStatsSnapshot {
    NSMutableArray<CallStatsRow *> *rows = [NSMutableArray array];
    CallStatsSample *sample = nil;

    if ([self identifier] == kAKSIPUserAgentInvalidIdentifier) {
        AddTextRow(rows, @"Stats", @"unavailable");
        return [[CallStatsSnapshot alloc] initWithSampledAt:[NSDate date]
                                                       rows:rows
                                                    quality:CallStatsQualityWaiting];
    }

    pjsua_call_info callInfo;
    pj_status_t callInfoStatus = pjsua_call_get_info((pjsua_call_id)[self identifier], &callInfo);
    if (callInfoStatus != PJ_SUCCESS) {
        AddTextRow(rows, @"Stats", [NSString stringWithFormat:@"unavailable status=%d", callInfoStatus]);
        return [[CallStatsSnapshot alloc] initWithSampledAt:[NSDate date]
                                                       rows:rows
                                                    quality:CallStatsQualityWaiting];
    }

    unsigned mediaIndex = FirstAudioMediaIndex(&callInfo);
    if (mediaIndex == AKInvalidMediaIndex) {
        AddTextRow(rows, @"Stats", @"no active audio media");
        return [[CallStatsSnapshot alloc] initWithSampledAt:[NSDate date]
                                                       rows:rows
                                                    quality:CallStatsQualityWaiting];
    }

    pjsua_stream_info streamInfo;
    pj_status_t streamInfoStatus = pjsua_call_get_stream_info((pjsua_call_id)[self identifier], mediaIndex, &streamInfo);
    if (streamInfoStatus == PJ_SUCCESS) {
        AddTextRow(
            rows,
            @"Codec",
            [NSString stringWithFormat:@"%@ / %u Hz",
             PJString(streamInfo.info.aud.fmt.encoding_name),
             streamInfo.info.aud.fmt.clock_rate]
        );
        AddTextRow(rows, @"Remote RTP", AddressString(&streamInfo.info.aud.rem_addr));
        AddTextRow(rows, @"Remote RTCP", AddressString(&streamInfo.info.aud.rem_rtcp));
        AddTextRow(rows, @"Selected RTP destination", AddressString(&streamInfo.info.aud.rem_addr));
    } else {
        AddTextRow(rows, @"Stream info", [NSString stringWithFormat:@"unavailable status=%d", streamInfoStatus]);
    }

    pjmedia_transport_info transportInfo;
    pjmedia_transport_info_init(&transportInfo);
    pj_status_t transportInfoStatus = pjsua_call_get_med_transport_info(
        (pjsua_call_id)[self identifier],
        mediaIndex,
        &transportInfo
    );
    if (transportInfoStatus == PJ_SUCCESS) {
        AddTextRow(rows, @"Local RTP", AddressString(&transportInfo.sock_info.rtp_addr_name));
        AddTextRow(rows, @"Local RTCP", AddressString(&transportInfo.sock_info.rtcp_addr_name));
        AddTextRow(rows, @"Source RTP", AddressString(&transportInfo.src_rtp_name));
        AddTextRow(rows, @"Source RTCP", AddressString(&transportInfo.src_rtcp_name));

        pjmedia_ice_transport_info *iceInfo = (pjmedia_ice_transport_info *)pjmedia_transport_info_get_spc_info(
            &transportInfo,
            PJMEDIA_TRANSPORT_TYPE_ICE
        );
        if (iceInfo != NULL) {
            AddTextRow(rows, @"ICE active", iceInfo->active ? @"true" : @"false");
            AddTextRow(rows, @"ICE state", [NSString stringWithUTF8String:pj_ice_strans_state_name(iceInfo->sess_state)]);
            AddTextRow(rows, @"ICE role", [NSString stringWithUTF8String:pj_ice_sess_role_name(iceInfo->role)]);
            if (iceInfo->comp_cnt > 0) {
                AddTextRow(rows, @"ICE RTP pair", ICEComponentPairString(iceInfo, 0));
                AddTextRow(rows, @"ICE RTP path type", ICEPathType(iceInfo, 0));
            }
            if (iceInfo->comp_cnt > 1) {
                AddTextRow(rows, @"ICE RTCP pair", ICEComponentPairString(iceInfo, 1));
                AddTextRow(rows, @"ICE RTCP path type", ICEPathType(iceInfo, 1));
            }
            AddTextRow(rows, @"TURN used", ICEComponentUsesRelay(iceInfo, 0) || ICEComponentUsesRelay(iceInfo, 1) ? @"true" : @"false");
        } else {
            AddTextRow(rows, @"ICE active", @"false");
            AddTextRow(rows, @"TURN used", @"false");
        }
    } else {
        AddTextRow(rows, @"ICE info", [NSString stringWithFormat:@"unavailable status=%d", transportInfoStatus]);
    }

    pjsua_stream_stat streamStat;
    pj_status_t streamStatStatus = pjsua_call_get_stream_stat((pjsua_call_id)[self identifier], mediaIndex, &streamStat);
    if (streamStatStatus == PJ_SUCCESS) {
        double rxJitter = streamStat.rtcp.rx.jitter.last / 1000.0;
        double txJitter = streamStat.rtcp.tx.jitter.last / 1000.0;
        double rtt = streamStat.rtcp.rtt.last / 1000.0;
        double jbufAverage = streamStat.jbuf.avg_delay;

        AddIntegerRow(rows, @"RX packets", streamStat.rtcp.rx.pkt);
        AddIntegerRow(rows, @"RX bytes", streamStat.rtcp.rx.bytes);
        AddIntegerRow(rows, @"RX loss", streamStat.rtcp.rx.loss);
        AddDoubleMillisecondsRow(rows, @"RX jitter", rxJitter);
        AddIntegerRow(rows, @"TX packets", streamStat.rtcp.tx.pkt);
        AddIntegerRow(rows, @"TX bytes", streamStat.rtcp.tx.bytes);
        AddIntegerRow(rows, @"TX loss", streamStat.rtcp.tx.loss);
        AddDoubleMillisecondsRow(rows, @"TX jitter", txJitter);
        AddDoubleMillisecondsRow(rows, @"RTT", rtt);
        AddDoubleMillisecondsRow(rows, @"JBuf avg", jbufAverage);
        AddIntegerRow(rows, @"JBuf lost", streamStat.jbuf.lost);
        AddIntegerRow(rows, @"JBuf discard", streamStat.jbuf.discard);
        AddIntegerRow(rows, @"JBuf empty", streamStat.jbuf.empty);

        sample = [[CallStatsSample alloc] initWithRttMilliseconds:rtt
                        averageJitterBufferDelayMilliseconds:jbufAverage
                                       receiveJitterMilliseconds:rxJitter
                                               jitterBufferLost:streamStat.jbuf.lost
                                            jitterBufferDiscard:streamStat.jbuf.discard
                                              jitterBufferEmpty:streamStat.jbuf.empty];
    } else {
        AddTextRow(rows, @"Stream stats", [NSString stringWithFormat:@"unavailable status=%d", streamStatStatus]);
    }

    return [[CallStatsSnapshot alloc] initWithSampledAt:[NSDate date]
                                                   rows:rows
                                                quality:[CallStatsQualityEvaluator immediateQualityFor:sample]
                                                 sample:sample];
}


#pragma mark -

- (instancetype)initWithSIPAccount:(AKSIPAccount *)account info:(PJSUACallInfo *)info {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _account = account;
    _identifier = info.identifier;

    _date = [NSDate date];

    _incoming = info.isIncoming;
    _missed = _incoming;
    _state = info.state;
    _stateText = info.stateText;
    _lastStatus = info.lastStatus;
    _lastStatusText = info.lastStatusText;
    _localURI = info.localURI;
    _remoteURI = info.remoteURI;
    _remote = [[URI alloc] initWithURI:_remoteURI];

    return self;
}

- (void)dealloc {
    [self setDelegate:nil];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ <=> %@", [self localURI], [self remoteURI]];
}

- (void)answer {
    pj_status_t status = pjsua_call_answer((pjsua_call_id)[self identifier], PJSIP_SC_OK, NULL, NULL);
    if (status == PJ_SUCCESS) {
        self.missed = NO;
    } else {
        NSLog(@"Error answering call %@", self);
    }
}

- (void)hangUp {
    if (([self identifier] == kAKSIPUserAgentInvalidIdentifier) || ([self state] == kAKSIPCallDisconnectedState)) {
        return;
    }
    
    pj_status_t status = pjsua_call_hangup((pjsua_call_id)[self identifier], 0, NULL, NULL);
    if (status == PJ_SUCCESS) {
        self.missed = NO;
    } else {
        NSLog(@"Error hanging up call %@", self);
    }
}

- (void)attendedTransferToCall:(AKSIPCall *)destinationCall {
    [self setTransferStatus:kAKSIPUserAgentInvalidIdentifier];
    [self setTransferStatusText:@""];
    pj_status_t status = pjsua_call_xfer_replaces((pjsua_call_id)[self identifier],
                                                  (pjsua_call_id)[destinationCall identifier],
                                                  PJSUA_XFER_NO_REQUIRE_REPLACES,
                                                  NULL);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error transfering call %@", self);
    }
}

- (void)sendRingingNotification {
    pj_status_t status = pjsua_call_answer((pjsua_call_id)[self identifier], PJSIP_SC_RINGING, NULL, NULL);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error sending ringing notification in call %@", self);
    }
}

- (void)replyWithTemporarilyUnavailable {
    pj_status_t status = pjsua_call_answer((pjsua_call_id)[self identifier], PJSIP_SC_TEMPORARILY_UNAVAILABLE, NULL, NULL);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error replying with 480 Temporarily Unavailable");
    }
}

- (void)replyWithBusyHere {
    pj_status_t status = pjsua_call_answer((pjsua_call_id)[self identifier], PJSIP_SC_BUSY_HERE, NULL, NULL);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error replying with 486 Busy Here");
    }
}

- (void)sendDTMFDigits:(NSString *)digits {
    pj_status_t status;
    pj_str_t pjDigits = [digits pjString];
    
    // Try to send RFC2833 DTMF first.
    status = pjsua_call_dial_dtmf((pjsua_call_id)[self identifier], &pjDigits);
    
    if (status != PJ_SUCCESS) {  // Okay, that didn't work. Send INFO DTMF.
        const pj_str_t kSIPINFO = pj_str("INFO");
        
        for (NSUInteger i = 0; i < [digits length]; ++i) {
            pjsua_msg_data messageData;
            pjsua_msg_data_init(&messageData);
            messageData.content_type = pj_str("application/dtmf-relay");
            
            NSString *messageBody = [NSString stringWithFormat:@"Signal=%C\r\nDuration=300",
                                     [digits characterAtIndex:i]];
            messageData.msg_body = [messageBody pjString];
            
            status = pjsua_call_send_request((pjsua_call_id)[self identifier], &kSIPINFO, &messageData);
            if (status != PJ_SUCCESS) {
                NSLog(@"Error sending DTMF");
            }
        }
    }
}

- (void)muteMicrophone {
    if ([self isMicrophoneMuted] || [self state] != kAKSIPCallConfirmedState) {
        return;
    }
    
    pjsua_call_info callInfo;
    pjsua_call_get_info((pjsua_call_id)[self identifier], &callInfo);
    
    pj_status_t status = pjsua_conf_disconnect(0, callInfo.media[0].stream.aud.conf_slot);
    if (status == PJ_SUCCESS) {
        [self setMicrophoneMuted:YES];
    } else {
        NSLog(@"Error muting microphone in call %@", self);
    }
}

- (void)unmuteMicrophone {
    if (![self isMicrophoneMuted] || [self state] != kAKSIPCallConfirmedState) {
        return;
    }
    
    pjsua_call_info callInfo;
    pjsua_call_get_info((pjsua_call_id)[self identifier], &callInfo);
    
    pj_status_t status = pjsua_conf_connect(0, callInfo.media[0].stream.aud.conf_slot);
    if (status == PJ_SUCCESS) {
        [self setMicrophoneMuted:NO];
    } else {
        NSLog(@"Error unmuting microphone in call %@", self);
    }
}

- (void)toggleMicrophoneMute {
    if ([self isMicrophoneMuted]) {
        [self unmuteMicrophone];
    } else {
        [self muteMicrophone];
    }
}

- (void)hold {
    if ([self state] == kAKSIPCallConfirmedState && ![self isOnRemoteHold]) {
        pjsua_call_set_hold((pjsua_call_id)[self identifier], NULL);
    }
}

- (void)unhold {
    if ([self state] == kAKSIPCallConfirmedState) {
        pjsua_call_reinvite((pjsua_call_id)[self identifier], PJ_TRUE, NULL);
    }
}

- (void)toggleHold {
    if ([self isOnLocalHold]) {
        [self unhold];
    } else {
        [self hold];
    }
}

@end

static void AddTextRow(NSMutableArray<CallStatsRow *> *rows, NSString *metric, NSString *live) {
    [rows addObject:[[CallStatsRow alloc] initWithMetric:metric live:live numericLiveValue:nil]];
}

static void AddIntegerRow(NSMutableArray<CallStatsRow *> *rows, NSString *metric, NSUInteger value) {
    [rows addObject:[[CallStatsRow alloc] initWithMetric:metric
                                                    live:[NSString stringWithFormat:@"%lu", value]
                                        numericLiveValue:@(value)]];
}

static void AddDoubleMillisecondsRow(NSMutableArray<CallStatsRow *> *rows, NSString *metric, double value) {
    [rows addObject:[[CallStatsRow alloc] initWithMetric:metric
                                                    live:[NSString stringWithFormat:@"%.1f ms", value]
                                        numericLiveValue:@(value)]];
}

static NSString *PJString(pj_str_t value) {
    return [NSString stringWithPJString:value];
}

static NSString *AddressString(const pj_sockaddr *address) {
    if (!pj_sockaddr_has_addr((const pj_sockaddr_t *)address)) {
        return @"unavailable";
    }

    char buffer[PJ_INET6_ADDRSTRLEN + 16];
    pj_sockaddr_print((const pj_sockaddr_t *)address, buffer, sizeof(buffer), 3);
    return [NSString stringWithUTF8String:buffer] ?: @"unavailable";
}

static NSString *ICECandidateTypeName(pj_ice_cand_type type) {
    return [NSString stringWithUTF8String:pj_ice_get_cand_type_name(type)] ?: @"unknown";
}

static NSString *ICEComponentPairString(pjmedia_ice_transport_info *info, unsigned componentIndex) {
    if (componentIndex >= info->comp_cnt) {
        return @"unavailable";
    }

    return [NSString stringWithFormat:@"local %@ %@ -> remote %@ %@",
            ICECandidateTypeName(info->comp[componentIndex].lcand_type),
            AddressString(&info->comp[componentIndex].lcand_addr),
            ICECandidateTypeName(info->comp[componentIndex].rcand_type),
            AddressString(&info->comp[componentIndex].rcand_addr)];
}

static NSString *ICEPathType(pjmedia_ice_transport_info *info, unsigned componentIndex) {
    if (componentIndex >= info->comp_cnt) {
        return @"unavailable";
    }

    pj_ice_cand_type local = info->comp[componentIndex].lcand_type;
    pj_ice_cand_type remote = info->comp[componentIndex].rcand_type;
    if (local == PJ_ICE_CAND_TYPE_RELAYED || remote == PJ_ICE_CAND_TYPE_RELAYED) {
        return @"relay";
    }
    if (local == PJ_ICE_CAND_TYPE_SRFLX ||
        remote == PJ_ICE_CAND_TYPE_SRFLX ||
        local == PJ_ICE_CAND_TYPE_PRFLX ||
        remote == PJ_ICE_CAND_TYPE_PRFLX) {
        return @"direct NAT";
    }
    return @"direct host";
}

static BOOL ICEComponentUsesRelay(pjmedia_ice_transport_info *info, unsigned componentIndex) {
    return componentIndex < info->comp_cnt &&
        (info->comp[componentIndex].lcand_type == PJ_ICE_CAND_TYPE_RELAYED ||
         info->comp[componentIndex].rcand_type == PJ_ICE_CAND_TYPE_RELAYED);
}

static unsigned FirstAudioMediaIndex(const pjsua_call_info *callInfo) {
    for (unsigned i = 0; i < callInfo->media_cnt; i++) {
        if (callInfo->media[i].type == PJMEDIA_TYPE_AUDIO) {
            return i;
        }
    }
    return AKInvalidMediaIndex;
}
