//
//  AKSIPUserAgent.m
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

#import "AKSIPUserAgent.h"

@import UseCases;

#import "AKNSString+PJSUA.h"
#import "AKSIPAccount.h"
#import "AKSIPCall.h"
#import "AKSIPURIParser.h"
#import "PJSUACallbacks.h"

#import "Telephone-Swift.h"

#import <pthread.h>
#import <stdio.h>

#define THIS_FILE "AKSIPUserAgent.m"

enum {
  kAKRingbackFrequency1  = 440,
  kAKRingbackFrequency2  = 480,
  kAKRingbackOnDuration  = 2000,
  kAKRingbackOffDuration = 4000,
  kAKRingbackCount       = 1,
  kAKRingbackInterval    = 4000
};

const NSInteger kAKSIPUserAgentInvalidIdentifier = PJSUA_INVALID_ID;

// Maximum number of name servers to take into account.
static const NSInteger kAKSIPUserAgentNameServersMax = 4;

// User agent defaults.
static const NSInteger kAKSIPUserAgentDefaultOutboundProxyPort = 5060;
static const NSInteger kAKSIPUserAgentDefaultSTUNServerPort = 3478;
static const NSInteger kAKSIPUserAgentDefaultTURNServerPort = 3478;
static const NSInteger kAKSIPUserAgentDefaultLogLevel = 5;
static const NSInteger kAKSIPUserAgentDefaultConsoleLogLevel = 0;
static const BOOL kAKSIPUserAgentDefaultDetectsVoiceActivity = YES;
static const BOOL kAKSIPUserAgentDefaultUsesICE = NO;
static const BOOL kAKSIPUserAgentDefaultUsesQoS = YES;
static const NSInteger kAKSIPUserAgentDefaultTransportPort = 0;
static const BOOL kAKSIPUserAgentDefaultUsesG711Only = NO;
static const BOOL kAKSIPUserAgentDefaultLocksCodec = YES;

static NSString * const SoftphoneSIPLogLineNotification = @"SoftphoneSIPLogLineNotification";
static NSString * const SoftphoneSIPLogLevelKey = @"level";
static NSString * const SoftphoneSIPLogMessageKey = @"message";
static NSString * const SoftphoneSIPPingStatusResponse = @"Response";
static NSString * const SoftphoneSIPPingStatusTimeout = @"Timeout";
static NSString * const SoftphoneSIPPingStatusFailed = @"Failed";

static pthread_mutex_t SoftphonePJSIPLogFileMutex = PTHREAD_MUTEX_INITIALIZER;
static FILE *SoftphonePJSIPLogFile = NULL;
static unsigned SoftphonePJSIPConsoleLogLevel = 0;

@interface AKSIPOptionsPingToken : NSObject

@property(nonatomic, copy) NSString *target;
@property(nonatomic, copy) NSString *transport;
@property(nonatomic) NSDate *startedAt;
@property(nonatomic, copy) AKSIPOptionsPingCompletion completion;
@property(nonatomic) BOOL completed;
@property(nonatomic, weak) AKSIPUserAgent *userAgent;
@property(nonatomic, weak) AKSIPAccount *account;

@end

@implementation AKSIPOptionsPingToken
@end

// PJSIP allows only one application log callback, so this callback tees the
// stack output to every place SIPMan needs it: the existing file, console, and
// SwiftUI diagnostics pane.
static void SoftphoneClosePJSIPLogFile(void) {
    pthread_mutex_lock(&SoftphonePJSIPLogFileMutex);
    if (SoftphonePJSIPLogFile != NULL) {
        fclose(SoftphonePJSIPLogFile);
        SoftphonePJSIPLogFile = NULL;
    }
    pthread_mutex_unlock(&SoftphonePJSIPLogFileMutex);
}

static void SoftphoneOpenPJSIPLogFile(NSString *path) {
    SoftphoneClosePJSIPLogFile();

    NSString *expandedPath = [path stringByExpandingTildeInPath];
    if ([expandedPath length] == 0) {
        return;
    }

    NSString *directory = [expandedPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    pthread_mutex_lock(&SoftphonePJSIPLogFileMutex);
    SoftphonePJSIPLogFile = fopen([expandedPath fileSystemRepresentation], "w");
    pthread_mutex_unlock(&SoftphonePJSIPLogFileMutex);
}

static void SoftphoneWritePJSIPLogFile(const char *data, int len) {
    pthread_mutex_lock(&SoftphonePJSIPLogFileMutex);
    if (SoftphonePJSIPLogFile != NULL) {
        fwrite(data, sizeof(char), (size_t)len, SoftphonePJSIPLogFile);
        fflush(SoftphonePJSIPLogFile);
    }
    pthread_mutex_unlock(&SoftphonePJSIPLogFileMutex);
}

static void SoftphonePJSIPLogCallback(int level, const char *data, int len) {
    if (data == NULL || len <= 0) {
        return;
    }

    SoftphoneWritePJSIPLogFile(data, len);
    if ((unsigned)level <= SoftphonePJSIPConsoleLogLevel) {
        pj_log_write(level, data, len);
    }

    @autoreleasepool {
        NSString *message = [[NSString alloc] initWithBytes:data
                                                     length:(NSUInteger)len
                                                   encoding:NSUTF8StringEncoding];
        if ([message length] == 0) {
            message = [[NSString alloc] initWithBytes:data
                                               length:(NSUInteger)len
                                             encoding:NSISOLatin1StringEncoding];
        }

        NSString *trimmedMessage = [message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        if ([trimmedMessage length] == 0) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SoftphoneSIPLogLineNotification
                                                                object:nil
                                                              userInfo:@{
                SoftphoneSIPLogLevelKey: @(level),
                SoftphoneSIPLogMessageKey: trimmedMessage
            }];
        });
    }
}


@interface AKSIPUserAgent ()

// Read-write redeclaration.
@property(nonatomic) AKSIPUserAgentState state;

@property(nonatomic) pj_pool_t *pool;

@property(nonatomic, readonly) NSMutableArray *accounts;
@property(nonatomic, readonly) NSMutableSet<AKSIPOptionsPingToken *> *sipOptionsPingTokens;

// Ringback slot.
@property(nonatomic, assign) pjsua_conf_port_id ringbackSlot;

// Ringback port.
@property(nonatomic, assign) pjmedia_port *ringbackPort;

// Ringback count.
@property(nonatomic, assign) NSInteger ringbackCount;

// Transport identifiers.
@property(nonatomic) pjsua_transport_id UDP4TransportIdentifier;
@property(nonatomic) pjsua_transport_id UDP6TransportIdentifier;
@property(nonatomic) pjsua_transport_id TCP4TransportIdentifier;
@property(nonatomic) pjsua_transport_id TCP6TransportIdentifier;
@property(nonatomic) pjsua_transport_id TLS4TransportIdentifier;
@property(nonatomic) pjsua_transport_id TLS6TransportIdentifier;

@property(nonatomic, readonly) NSThread *thread;

/// Updates codecs according to usesG711Only property value.
- (void)updateCodecs;

/// Returns default priority for codec with specified identifier.
- (NSUInteger)priorityForCodec:(NSString *)identifier;

@end

static NSString *SoftphonePJSIPErrorString(pj_status_t status) {
    char buffer[PJ_ERR_MSG_SIZE];
    pj_strerror(status, buffer, sizeof(buffer));
    return [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding] ?: [NSString stringWithFormat:@"PJSIP status %d", status];
}

static NSDictionary *SoftphoneSIPPingResult(AKSIPOptionsPingToken *token,
                                            NSString *status,
                                            NSString *summary,
                                            NSString *detail,
                                            NSString *rawResponse) {
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:token.startedAt] * 1000.0;
    return @{
        @"target": token.target ?: @"",
        @"transport": token.transport ?: @"",
        @"status": status ?: @"",
        @"summary": summary ?: @"",
        @"detail": detail ?: @"",
        @"rawResponse": rawResponse ?: @"",
        @"elapsedMilliseconds": @(elapsed)
    };
}

static NSString *SoftphoneSIPOptionsTarget(NSString *destination, NSString *transport) {
    NSString *trimmed = [destination stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lowercaseTarget = [trimmed lowercaseString];
    NSString *target = ([lowercaseTarget hasPrefix:@"sip:"] || [lowercaseTarget hasPrefix:@"sips:"]) ? trimmed : [@"sip:" stringByAppendingString:trimmed];
    NSString *lowercaseTransport = [[transport lowercaseString] isEqualToString:@"tcp"] || [[transport lowercaseString] isEqualToString:@"tls"] ? [transport lowercaseString] : @"udp";

    if (![lowercaseTransport isEqualToString:@"udp"] && [[target lowercaseString] rangeOfString:@";transport="].location == NSNotFound) {
        target = [target stringByAppendingFormat:@";transport=%@", lowercaseTransport];
    }
    return target;
}

static NSString *SoftphoneSIPOptionsFrom(AKSIPAccount *account) {
    if ([account.SIPAddress length] > 0) {
        return [@"sip:" stringByAppendingString:account.SIPAddress];
    }

    return @"sip:sipman@localhost";
}

static NSString *SoftphoneSIPOptionsRawResponse(pjsip_event *event) {
    if (event == NULL ||
        event->type != PJSIP_EVENT_TSX_STATE ||
        event->body.tsx_state.type != PJSIP_EVENT_RX_MSG ||
        event->body.tsx_state.src.rdata == NULL) {
        return @"";
    }

    pjsip_rx_data *rdata = event->body.tsx_state.src.rdata;
    if (rdata->pkt_info.len <= 0) {
        return @"";
    }

    return [[NSString alloc] initWithBytes:rdata->pkt_info.packet
                                    length:(NSUInteger)rdata->pkt_info.len
                                  encoding:NSUTF8StringEncoding] ?: @"";
}

static void SoftphoneSIPOptionsPingCallback(void *rawToken, pjsip_event *event) {
    AKSIPOptionsPingToken *token = (__bridge AKSIPOptionsPingToken *)rawToken;
    pjsip_transaction *tsx = NULL;
    if (event != NULL && event->type == PJSIP_EVENT_TSX_STATE) {
        tsx = event->body.tsx_state.tsx;
    }

    NSString *summary = @"SIP OPTIONS transaction completed.";
    NSString *detail = @"";
    NSString *status = SoftphoneSIPPingStatusResponse;
    if (tsx != NULL && tsx->status_code > 0) {
        NSString *reason = [NSString stringWithPJString:tsx->status_text];
        summary = reason.length > 0 ? [NSString stringWithFormat:@"%d %@", tsx->status_code, reason] : [NSString stringWithFormat:@"%d", tsx->status_code];
    }

    if (event != NULL && event->type == PJSIP_EVENT_TSX_STATE) {
        if (event->body.tsx_state.type == PJSIP_EVENT_TRANSPORT_ERROR) {
            status = SoftphoneSIPPingStatusFailed;
            detail = SoftphonePJSIPErrorString(event->body.tsx_state.src.status);
        } else {
            detail = [NSString stringWithFormat:@"PJSIP event: %s", pjsip_event_str(event->body.tsx_state.type)];
        }
    }

    NSDictionary *result = SoftphoneSIPPingResult(token, status, summary, detail, SoftphoneSIPOptionsRawResponse(event));
    dispatch_async(dispatch_get_main_queue(), ^{
        if (token.completed) {
            [token.userAgent.sipOptionsPingTokens removeObject:token];
            return;
        }
        token.completed = YES;
        if (token.completion) {
            token.completion(result);
        }
        [token.userAgent.sipOptionsPingTokens removeObject:token];
    });
}


@implementation AKSIPUserAgent

- (void)setDelegate:(id <AKSIPUserAgentDelegate>)aDelegate {
    if (_delegate == aDelegate) {
        return;
    }
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    if (_delegate != nil) {
        [notificationCenter removeObserver:_delegate name:nil object:self];
    }
    
    if (aDelegate != nil) {
        if ([aDelegate respondsToSelector:@selector(SIPUserAgentDidFinishStarting:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPUserAgentDidFinishStarting:)
                                       name:AKSIPUserAgentDidFinishStartingNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPUserAgentDidFinishStopping:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPUserAgentDidFinishStopping:)
                                       name:AKSIPUserAgentDidFinishStoppingNotification
                                     object:self];
        }
        if ([aDelegate respondsToSelector:@selector(SIPUserAgentDidDetectNAT:)]) {
            [notificationCenter addObserver:aDelegate
                                   selector:@selector(SIPUserAgentDidDetectNAT:)
                                       name:AKSIPUserAgentDidDetectNATNotification
                                     object:self];
        }
    }
    
    _delegate = aDelegate;
}

- (BOOL)isStarted {
    return self.state == AKSIPUserAgentStateStarted;
}

- (NSInteger)activeCallsCount {
    NSInteger count = 0;
    for (AKSIPAccount *account in self.accounts) {
        count += [account activeCallsCount];
    }
    return count;
}

- (BOOL)hasUnansweredIncomingCalls {
    for (AKSIPAccount *account in self.accounts) {
        if (account.hasUnansweredIncomingCalls) {
            return YES;
        }
    }
    return NO;
}

- (AKSIPUserAgentCallData *)callData {
    return _callData;
}

- (void)setNameServers:(NSArray *)newNameServers {
    if (_nameServers != newNameServers) {
        
        if ([newNameServers count] > kAKSIPUserAgentNameServersMax) {
            _nameServers = [newNameServers subarrayWithRange:NSMakeRange(0, kAKSIPUserAgentNameServersMax)];
        } else {
            _nameServers = [newNameServers copy];
        }
    }
}

- (void)setOutboundProxyPort:(NSUInteger)port {
    if (port > 0 && port <= 65535) {
        _outboundProxyPort = port;
    } else {
        _outboundProxyPort = kAKSIPUserAgentDefaultOutboundProxyPort;
    }
}

- (void)setSTUNServerPort:(NSUInteger)port {
    if (port > 0 && port <= 65535) {
        _STUNServerPort = port;
    } else {
        _STUNServerPort = kAKSIPUserAgentDefaultSTUNServerPort;
    }
}

- (void)setTURNServerPort:(NSUInteger)port {
    if (port > 0 && port <= 65535) {
        _TURNServerPort = port;
    } else {
        _TURNServerPort = kAKSIPUserAgentDefaultTURNServerPort;
    }
}

- (void)setLogFileName:(NSString *)pathToFile {
    if (_logFileName != pathToFile) {
        if ([pathToFile length] > 0) {
            _logFileName = [pathToFile copy];
        } else {
            _logFileName = nil;
        }
    }
}

- (void)setTransportPort:(NSUInteger)port {
    if (port >= 0 && port <= 65535) {
        _transportPort = port;
    } else {
        _transportPort = kAKSIPUserAgentDefaultTransportPort;
    }
}

- (void)setUsesG711Only:(BOOL)usesG711Only {
    if (_usesG711Only != usesG711Only) {
        _usesG711Only = usesG711Only;
        [self updateCodecs];
    }
}


#pragma mark AKSIPUserAgent singleton instance

+ (AKSIPUserAgent *)sharedUserAgent {
    static AKSIPUserAgent *__sharedUserAgent = nil;
    static dispatch_once_t __onceToken;
    dispatch_once(&__onceToken, ^{
        __sharedUserAgent = [[AKSIPUserAgent alloc] init];
    });
    
    return __sharedUserAgent;
}


#pragma mark -

- (instancetype)initWithDelegate:(id<AKSIPUserAgentDelegate>)aDelegate {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    
    [self setDelegate:aDelegate];
    _accounts = [[NSMutableArray alloc] init];
    _sipOptionsPingTokens = [[NSMutableSet alloc] init];
    [self setDetectedNATType:kAKNATTypeUnknown];

    [self setOutboundProxyPort:kAKSIPUserAgentDefaultOutboundProxyPort];
    [self setSTUNServerPort:kAKSIPUserAgentDefaultSTUNServerPort];
    [self setTURNServerPort:kAKSIPUserAgentDefaultTURNServerPort];
    [self setLogLevel:kAKSIPUserAgentDefaultLogLevel];
    [self setConsoleLogLevel:kAKSIPUserAgentDefaultConsoleLogLevel];
    [self setDetectsVoiceActivity:kAKSIPUserAgentDefaultDetectsVoiceActivity];
    [self setUsesICE:kAKSIPUserAgentDefaultUsesICE];
    [self setUsesQoS:kAKSIPUserAgentDefaultUsesQoS];
    [self setTransportPort:kAKSIPUserAgentDefaultTransportPort];
    [self setUsesG711Only:kAKSIPUserAgentDefaultUsesG711Only];
    [self setLocksCodec:kAKSIPUserAgentDefaultLocksCodec];
    
    [self setRingbackSlot:PJSUA_INVALID_ID];
    [self setUDP4TransportIdentifier:PJSUA_INVALID_ID];
    [self setUDP6TransportIdentifier:PJSUA_INVALID_ID];
    [self setTCP4TransportIdentifier:PJSUA_INVALID_ID];
    [self setTCP6TransportIdentifier:PJSUA_INVALID_ID];
    [self setTLS4TransportIdentifier:PJSUA_INVALID_ID];
    [self setTLS6TransportIdentifier:PJSUA_INVALID_ID];

    _parser = [[AKSIPURIParser alloc] initWithUserAgent:self];

    _thread = [[WaitingThread alloc] init];
    _thread.qualityOfService = NSQualityOfServiceUserInitiated;
    [_thread start];

    return self;
}

- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (void)start {
    if (self.state != AKSIPUserAgentStateStopped) {
        return;
    }
    if (pj_init() != PJ_SUCCESS) {
        NSLog(@"Error initializing PJSIP");
        return;
    }
    self.state = AKSIPUserAgentStateStarting;
    void (^completion)(BOOL) = ^(BOOL didStart) {
        self.state = didStart ? AKSIPUserAgentStateStarted : AKSIPUserAgentStateStopped;
        [[NSNotificationCenter defaultCenter] postNotificationName:AKSIPUserAgentDidFinishStartingNotification object:self];
    };
    [self performSelector:@selector(thread_startWithCompletion:) onThread:self.thread withObject:completion waitUntilDone:NO];
}

- (void)thread_startWithCompletion:(void (^ _Nonnull)(BOOL didStart))completion {
    @autoreleasepool {
        [self thread_startInAutoreleasePoolWithCompletion:completion];
    }
}

- (void)thread_startInAutoreleasePoolWithCompletion:(void (^ _Nonnull)(BOOL didStart))completion {
    pj_status_t status;

    if (!pj_thread_is_registered()) {
        pj_thread_t *thread;
        status = pj_thread_register("AKSIPUserAgent-pjsip-control", _descriptor, &thread);
        if (status != PJ_SUCCESS) {
            NSLog(@"Error registering thread at PJSUA");
            [self thread_callOnMain:completion withFlag:NO];
            return;
        }
    }

    status = pjsua_create();
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating PJSUA");
        [self thread_callOnMain:completion withFlag:NO];
        return;
    }

    self.pool = pjsua_pool_create("AKSIPUserAgent", 4000, 1000);
    if (!self.pool) {
        NSLog(@"Could not create memory pool");
        [self thread_stop];
        [self thread_callOnMain:completion withFlag:NO];
        return;
    }

    pjsua_config userAgentConfig;
    pjsua_logging_config loggingConfig;
    pjsua_media_config mediaConfig;
    pjsua_transport_config transportConfig;

    pjsua_config_default(&userAgentConfig);
    pjsua_logging_config_default(&loggingConfig);
    pjsua_media_config_default(&mediaConfig);
    pjsua_transport_config_default(&transportConfig);

    userAgentConfig.max_calls = (unsigned)self.maxCalls;
    userAgentConfig.use_timer = PJSUA_SIP_TIMER_INACTIVE;

    if ([[self nameServers] count] > 0) {
        userAgentConfig.nameserver_count = (unsigned)[[self nameServers] count];
        for (NSUInteger i = 0; i < [[self nameServers] count]; ++i) {
            userAgentConfig.nameserver[i] = [[self nameServers][i] pjString];
        }
    }

    if ([[self outboundProxyHost] length] > 0) {
        userAgentConfig.outbound_proxy_cnt = 1;
        
        if ([self outboundProxyPort] == kAKSIPUserAgentDefaultOutboundProxyPort) {
            userAgentConfig.outbound_proxy[0] = [URI URIWithHost:self.outboundProxyHost
                                                       transport:TransportUDP].stringValue.pjString;
        } else {
            userAgentConfig.outbound_proxy[0] = [URI URIWithHost:self.outboundProxyHost
                                                            port:@(self.outboundProxyPort).stringValue
                                                       transport:TransportUDP].stringValue.pjString;
        }
    }

    if ([[self STUNServerHost] length] > 0) {
        userAgentConfig.stun_srv_cnt = 1;

        if ([self STUNServerPort] == kAKSIPUserAgentDefaultSTUNServerPort) {
            userAgentConfig.stun_srv[0] = [[ServiceAddress alloc] initWithHost:self.STUNServerHost].stringValue.pjString;
        } else {
            userAgentConfig.stun_srv[0] = [[ServiceAddress alloc] initWithHost:self.STUNServerHost
                                                                          port:@(self.STUNServerPort).stringValue].stringValue.pjString;
        }
    }
    userAgentConfig.stun_try_ipv6 = PJ_TRUE;

    userAgentConfig.user_agent = [[self userAgentString] pjString];

    SoftphoneOpenPJSIPLogFile([self logFileName]);

    // PJSIP emits full incoming/outgoing SIP messages at verbose level 5.
    // Keep the callback at that level so the in-app live SIP log is useful,
    // while leaving console output controlled separately below.
    loggingConfig.level = (unsigned)MAX([self logLevel], 5);
    loggingConfig.console_level = (unsigned)[self consoleLogLevel];
    loggingConfig.cb = &SoftphonePJSIPLogCallback;
    SoftphonePJSIPConsoleLogLevel = loggingConfig.console_level;
    mediaConfig.no_vad = ![self detectsVoiceActivity];
    mediaConfig.enable_ice = [self usesICE];
    if ([[self TURNServerHost] length] > 0) {
        mediaConfig.enable_ice = PJ_TRUE;
        mediaConfig.enable_turn = PJ_TRUE;
        mediaConfig.turn_conn_type = PJ_TURN_TP_UDP;
        if ([self TURNServerPort] == kAKSIPUserAgentDefaultTURNServerPort) {
            mediaConfig.turn_server = [[ServiceAddress alloc] initWithHost:self.TURNServerHost].stringValue.pjString;
        } else {
            mediaConfig.turn_server = [[ServiceAddress alloc] initWithHost:self.TURNServerHost
                                                                       port:@(self.TURNServerPort).stringValue].stringValue.pjString;
        }
    }
    mediaConfig.snd_auto_close_time = 1;
    mediaConfig.ec_options = PJMEDIA_ECHO_USE_SW_ECHO;

    if (self.usesQoS) {
        transportConfig.qos_params.flags = PJ_QOS_PARAM_HAS_DSCP;
        transportConfig.qos_params.dscp_val = 24;
    }

    transportConfig.port = (unsigned)[self transportPort];

    userAgentConfig.cb.on_incoming_call = &PJSUAOnIncomingCall;
    userAgentConfig.cb.on_call_state = &PJSUAOnCallState;
    userAgentConfig.cb.on_call_media_state = &PJSUAOnCallMediaState;
    userAgentConfig.cb.on_call_transfer_status = &PJSUAOnCallTransferStatus;
    userAgentConfig.cb.on_call_replaced = &PJSUAOnCallReplaced;
    userAgentConfig.cb.on_reg_state = &PJSUAOnAccountRegistrationState;
    userAgentConfig.cb.on_nat_detect = &PJSUAOnNATDetect;
    userAgentConfig.cb.on_acc_find_for_incoming = &PJSUAOnAccountFindForIncoming;

    // Initialize PJSUA.
    status = pjsua_init(&userAgentConfig, &loggingConfig, &mediaConfig);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error initializing PJSUA");
        [self thread_stop];
        [self thread_callOnMain:completion withFlag:NO];
        return;
    }

    // Create ringback tones.
    unsigned i, samplesPerFrame;
    pjmedia_tone_desc tone[kAKRingbackCount];
    pj_str_t name;

    samplesPerFrame = mediaConfig.audio_frame_ptime * mediaConfig.clock_rate * mediaConfig.channel_count / 1000;

    name = pj_str("ringback");
    pjmedia_port *aRingbackPort;
    status = pjmedia_tonegen_create2(self.pool,
                                     &name,
                                     mediaConfig.clock_rate,
                                     mediaConfig.channel_count,
                                     samplesPerFrame,
                                     16,
                                     PJMEDIA_TONEGEN_LOOP,
                                     &aRingbackPort);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating ringback tones");
        [self thread_stop];
        [self thread_callOnMain:completion withFlag:NO];
        return;
    }

    [self setRingbackPort:aRingbackPort];

    pj_bzero(&tone, sizeof(tone));
    for (i = 0; i < kAKRingbackCount; ++i) {
        tone[i].freq1 = kAKRingbackFrequency1;
        tone[i].freq2 = kAKRingbackFrequency2;
        tone[i].on_msec = kAKRingbackOnDuration;
        tone[i].off_msec = kAKRingbackOffDuration;
    }
    tone[kAKRingbackCount - 1].off_msec = kAKRingbackInterval;

    pjmedia_tonegen_play([self ringbackPort], kAKRingbackCount, tone, PJMEDIA_TONEGEN_LOOP);

    pjsua_conf_port_id aRingbackSlot;
    status = pjsua_conf_add_port(self.pool, [self ringbackPort], &aRingbackSlot);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error adding media port for ringback tones");
        [self thread_stop];
        [self thread_callOnMain:completion withFlag:NO];
        return;
    }

    [self setRingbackSlot:aRingbackSlot];

    // Add UDP4 transport.
    pjsua_transport_id UDP4TransportIdentifier = PJSUA_INVALID_ID;
    status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &transportConfig, &UDP4TransportIdentifier);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating UDP4 transport");
        [self thread_stop];
        [self thread_callOnMain:completion withFlag:NO];
        return;
    }
    self.UDP4TransportIdentifier = UDP4TransportIdentifier;

    // Get UDP4 transport port chosen by PJSUA.
    if ([self transportPort] == 0) {
        pjsua_transport_info transportInfo;
        status = pjsua_transport_get_info(UDP4TransportIdentifier, &transportInfo);
        if (status != PJ_SUCCESS) {
            NSLog(@"Error getting UDP4 transport info");
        }
        
        [self setTransportPort:transportInfo.local_name.port];
        
        // Set chosen port back to transportConfig to add TCP transport below.
        transportConfig.port = (unsigned)[self transportPort];
    }

    // Add UDP6 transport.
    pjsua_transport_id UDP6TransportIdentifier = PJSUA_INVALID_ID;
    status = pjsua_transport_create(PJSIP_TRANSPORT_UDP6, &transportConfig, &UDP6TransportIdentifier);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating UDP6 transport");
    }
    self.UDP6TransportIdentifier = UDP6TransportIdentifier;

    // Add TCP4 transport.
    pjsua_transport_id TCP4TransportIdentifier = PJSUA_INVALID_ID;
    status = pjsua_transport_create(PJSIP_TRANSPORT_TCP, &transportConfig, &TCP4TransportIdentifier);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating TCP4 transport");
    }
    self.TCP4TransportIdentifier = TCP4TransportIdentifier;

    // Add TCP6 transport.
    pjsua_transport_id TCP6TransportIdentifier = PJSUA_INVALID_ID;
    status = pjsua_transport_create(PJSIP_TRANSPORT_TCP6, &transportConfig, &TCP6TransportIdentifier);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating TCP6 transport");
    }
    self.TCP6TransportIdentifier = TCP6TransportIdentifier;

    // Add TLS transport.
    transportConfig.tls_setting.verify_server = PJ_TRUE;
    transportConfig.tls_setting.verify_client = PJ_TRUE;
    NSURL *cert = [NSBundle.mainBundle URLForResource:@"PublicCAs" withExtension:@"pem"];
    transportConfig.tls_setting.ca_list_file = cert.path.pjString;
    transportConfig.port++;
    pjsua_transport_id TLS4TransportIdentifier = PJSUA_INVALID_ID;
    status = pjsua_transport_create(PJSIP_TRANSPORT_TLS, &transportConfig, &TLS4TransportIdentifier);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating TLS4 transport");
    }
    self.TLS4TransportIdentifier = TLS4TransportIdentifier;

    // Add TLS6 transport.
    pjsua_transport_id TLS6TransportIdentifier = PJSUA_INVALID_ID;
    status = pjsua_transport_create(PJSIP_TRANSPORT_TLS6, &transportConfig, &TLS6TransportIdentifier);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error creating TLS6 transport");
    }
    self.TLS6TransportIdentifier = TLS6TransportIdentifier;

    // Update codecs.
    [self updateCodecs];

    // Start PJSUA.
    status = pjsua_start();
    if (status != PJ_SUCCESS) {
        NSLog(@"Error starting PJSUA");
        [self thread_stop];
        [self thread_callOnMain:completion withFlag:NO];
        return;
    }

    [self thread_callOnMain:completion withFlag:YES];
}

- (void)thread_callOnMain:(void (^ _Nonnull)(BOOL))block withFlag:(BOOL)flag {
    dispatch_async(dispatch_get_main_queue(), ^{ block(flag); });
}

- (void)stop {
    if (self.state != AKSIPUserAgentStateStarted) {
         return;
    }
    self.state = AKSIPUserAgentStateStopping;
    [self performSelector:@selector(thread_stopWithCompletion:) onThread:self.thread withObject:^{[self finishStopping];} waitUntilDone:NO];
}

- (void)stopAndWait {
    if (self.state != AKSIPUserAgentStateStarted) {
         return;
    }
    self.state = AKSIPUserAgentStateStopping;
    [self performSelector:@selector(thread_stop) onThread:self.thread withObject:nil waitUntilDone:YES];
    [self finishStopping];
}

- (void)thread_stopWithCompletion:(void (^ _Nonnull)(void))completion {
    [self thread_stop];
    dispatch_async(dispatch_get_main_queue(), completion);
}

- (void)thread_stop {
    @autoreleasepool {
        [self thread_stopInAutoreleasePool];
    }
}

- (void)thread_stopInAutoreleasePool {
    if (self.ringbackPort && self.ringbackSlot != PJSUA_INVALID_ID) {
        pjsua_conf_remove_port(self.ringbackSlot);
        self.ringbackSlot = PJSUA_INVALID_ID;
        pjmedia_port_destroy(self.ringbackPort);
        self.ringbackPort = NULL;
    }
    self.UDP4TransportIdentifier = PJSUA_INVALID_ID;
    self.UDP6TransportIdentifier = PJSUA_INVALID_ID;
    self.TCP4TransportIdentifier = PJSUA_INVALID_ID;
    self.TCP6TransportIdentifier = PJSUA_INVALID_ID;
    self.TLS4TransportIdentifier = PJSUA_INVALID_ID;
    self.TLS6TransportIdentifier = PJSUA_INVALID_ID;
    if (self.pool) {
        pj_pool_release(self.pool);
        self.pool = NULL;
    }
    if (pjsua_destroy() != PJ_SUCCESS) {
        NSLog(@"Error stopping SIP user agent");
    }
    SoftphoneClosePJSIPLogFile();
}

- (void)finishStopping {
    pj_shutdown();
    [self.accounts removeAllObjects];
    self.state = AKSIPUserAgentStateStopped;
    [[NSNotificationCenter defaultCenter] postNotificationName:AKSIPUserAgentDidFinishStoppingNotification object:self];
}

- (BOOL)addAccount:(AKSIPAccount *)anAccount withPassword:(NSString *)aPassword {
    if ([[self delegate] respondsToSelector:@selector(SIPUserAgentShouldAddAccount:)]) {
        if (![[self delegate] SIPUserAgentShouldAddAccount:anAccount]) {
            return NO;
        }
    }
    
    pjsua_acc_config accountConfig;
    pjsua_acc_config_default(&accountConfig);
    
    accountConfig.id = anAccount.uri.stringValue.pjString;

    accountConfig.reg_uri = [[URI alloc] initWithAddress:anAccount.registrar
                                               transport:anAccount.transport].stringValue.pjString;
    accountConfig.cred_count = 1;
    if ([[anAccount realm] length] > 0) {
        accountConfig.cred_info[0].realm = [[anAccount realm] pjString];
    } else {
        accountConfig.cred_info[0].realm = pj_str("*");
    }
    accountConfig.cred_info[0].scheme = pj_str("digest");
    accountConfig.cred_info[0].username = [[anAccount username] pjString];
    accountConfig.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    accountConfig.cred_info[0].data = [aPassword pjString];
    
    accountConfig.rtp_cfg.port = 4000;

    if (self.usesQoS) {
        accountConfig.rtp_cfg.qos_params.flags = PJ_QOS_PARAM_HAS_DSCP;
        accountConfig.rtp_cfg.qos_params.dscp_val = 46;
    }
    
    if ([[anAccount proxyHost] length] > 0) {
        accountConfig.proxy_cnt = 1;
        
        if ([anAccount proxyPort] == kAKSIPAccountDefaultSIPProxyPort) {
            accountConfig.proxy[0] = [URI URIWithHost:anAccount.proxyHost
                                            transport:anAccount.transport].stringValue.pjString;
        } else {
            accountConfig.proxy[0] = [URI URIWithHost:anAccount.proxyHost
                                                 port:@(anAccount.proxyPort).stringValue
                                            transport:anAccount.transport].stringValue.pjString;
        }
    }
    
    accountConfig.reg_timeout = (unsigned)[anAccount reregistrationTime];
    
    switch (anAccount.transport) {
        case TransportUDP:
            accountConfig.transport_id = anAccount.usesIPv6 ? self.UDP6TransportIdentifier : self.UDP4TransportIdentifier;
            break;
        case TransportTCP:
            accountConfig.transport_id = anAccount.usesIPv6 ? self.TCP6TransportIdentifier : self.TCP4TransportIdentifier;
            break;
        case TransportTLS:
            accountConfig.transport_id = anAccount.usesIPv6 ? self.TLS6TransportIdentifier : self.TLS4TransportIdentifier;
            break;
        default:
            break;
    }

    accountConfig.use_srtp = anAccount.transport == TransportTLS ? PJMEDIA_SRTP_MANDATORY : PJMEDIA_SRTP_DISABLED;

    accountConfig.ipv6_media_use = anAccount.usesIPv6 ? PJSUA_IPV6_ENABLED : PJSUA_IPV6_DISABLED;

    accountConfig.allow_contact_rewrite = anAccount.updatesContactHeader ? PJ_TRUE : PJ_FALSE;
    accountConfig.allow_via_rewrite = anAccount.updatesViaHeader ? PJ_TRUE : PJ_FALSE;
    accountConfig.allow_sdp_nat_rewrite = anAccount.updatesSDP ? PJ_TRUE : PJ_FALSE;

    accountConfig.lock_codec = self.locksCodec ? PJ_TRUE : PJ_FALSE;
    
    pjsua_acc_id accountIdentifier;
    pj_status_t status = pjsua_acc_add(&accountConfig, PJ_FALSE, &accountIdentifier);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error adding account %@ with status %d", anAccount, status);
        return NO;
    }
    
    [anAccount updateIdentifier:accountIdentifier];
    [anAccount setThread:self.thread];
    
    [[self accounts] addObject:anAccount];
    
    [anAccount setOnline:YES];

    return YES;
}

- (BOOL)removeAccount:(AKSIPAccount *)anAccount {
    if (![self isStarted] ||
        [anAccount identifier] == kAKSIPUserAgentInvalidIdentifier) {
        return NO;
    }

    [anAccount.delegate SIPAccountWillRemove:anAccount];
    
    [anAccount removeAllCalls];
    
    pj_status_t status = pjsua_acc_del((pjsua_acc_id)[anAccount identifier]);
    if (status != PJ_SUCCESS) {
        return NO;
    }
    
    [[self accounts] removeObject:anAccount];
    [anAccount updateIdentifier:kAKSIPUserAgentInvalidIdentifier];
    
    return YES;
}

- (AKSIPAccount *)accountWithIdentifier:(NSInteger)identifier {
    for (AKSIPAccount *account in self.accounts) {
        if (account.identifier == identifier) {
            return account;
        }
    }
    
    return nil;
}

- (AKSIPCall *)callWithIdentifier:(NSInteger)identifier {
    for (AKSIPAccount *account in self.accounts) {
        AKSIPCall *call = [account callWithIdentifier:identifier];
        if (call) {
            return call;
        }
    }
    
    return nil;
}

- (void)hangUpAllCalls {
    pjsua_call_hangup_all();
}

- (void)startRingbackForCall:(AKSIPCall *)call {
    if (self.callData[call.identifier].ringbackOn) {
        return;
    }
    
    self.callData[call.identifier].ringbackOn = PJ_TRUE;
    
    self.ringbackCount = self.ringbackCount + 1;
    if (self.ringbackCount == 1 && self.ringbackSlot != PJSUA_INVALID_ID) {
        pjsua_conf_connect(self.ringbackSlot, 0);
    }
}

- (void)stopRingbackForCall:(AKSIPCall *)call {
    if (self.callData[call.identifier].ringbackOn) {
        self.callData[call.identifier].ringbackOn = PJ_FALSE;
        
        pj_assert(self.ringbackCount > 0);
        
        self.ringbackCount = self.ringbackCount - 1;
        if (self.ringbackCount == 0 && self.ringbackSlot != PJSUA_INVALID_ID) {
            pjsua_conf_disconnect(self.ringbackSlot, 0);
            pjmedia_tonegen_rewind(self.ringbackPort);
        }
    }
}

- (BOOL)setSoundInputDevice:(NSInteger)input soundOutputDevice:(NSInteger)output {
    if (![self isStarted]) {
        return NO;
    }

    pj_status_t status = pjsua_set_snd_dev([self inputDeviceIDWithID:input], [self outputDeviceIDWithID:output]);
    
    return (status == PJ_SUCCESS) ? YES : NO;
}

- (int)inputDeviceIDWithID:(NSInteger)deviceID {
    return deviceID >= 0 ? (int)deviceID : PJMEDIA_AUD_DEFAULT_CAPTURE_DEV;
}

- (int)outputDeviceIDWithID:(NSInteger)deviceID {
    return deviceID >= 0 ? (int)deviceID : PJMEDIA_AUD_DEFAULT_PLAYBACK_DEV;
}

- (BOOL)stopSound {
    if (![self isStarted]) {
        return NO;
    }
    
    pj_status_t status = pjsua_set_null_snd_dev();
    
    return (status == PJ_SUCCESS) ? YES : NO;
}

// This method will leave application silent. |setSoundInputDevice:soundOutputDevice:| must be called after calling this
// method to set sound IO. Usually application controller is responsible of sending
// |setSoundInputDevice:soundOutputDevice:| to set sound IO after this method is called.
- (void)updateAudioDevices {
    if (![self isStarted]) {
        return;
    }
    
    // Stop sound device and disconnect it from the conference.
    pjsua_set_null_snd_dev();
    
    // Reinit sound device.
    pjmedia_snd_deinit();
    pjmedia_snd_init(pjsua_get_pool_factory());
}

- (void)updateCodecs {
    if (self.state == AKSIPUserAgentStateStopped || self.state == AKSIPUserAgentStateStopping) {
        return;
    }
    enum { kCodecInfoSize = 64 };
    pjsua_codec_info codecInfo[kCodecInfoSize];
    unsigned codecCount = kCodecInfoSize;
    pj_status_t status = pjsua_enum_codecs(codecInfo, &codecCount);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error getting list of codecs");
    } else {
        static NSString * const kPCMU = @"PCMU/8000/1";
        static NSString * const kPCMA = @"PCMA/8000/1";
        for (NSUInteger i = 0; i < codecCount; i++) {
            NSString *codecIdentifier = [NSString stringWithPJString:codecInfo[i].codec_id];
            pj_uint8_t defaultPriority = (pj_uint8_t)[self priorityForCodec:codecIdentifier];
            if (self.usesG711Only) {
                pj_uint8_t priority = 0;
                if ([codecIdentifier isEqualToString:kPCMU] || [codecIdentifier isEqualToString:kPCMA]) {
                    priority = defaultPriority;
                }
                status = pjsua_codec_set_priority(&codecInfo[i].codec_id, priority);
                if (status != PJ_SUCCESS) {
                    NSLog(@"Error setting codec priority to zero");
                }
            } else {
                status = pjsua_codec_set_priority(&codecInfo[i].codec_id, defaultPriority);
                if (status != PJ_SUCCESS) {
                    NSLog(@"Error setting codec priority to the default value");
                }
            }
        }
    }
}

- (NSUInteger)priorityForCodec:(NSString *)identifier {
    static NSDictionary *priorities = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        priorities = @{
                       @"opus/48000/2":  @(130),
                       @"G722/16000/1":  @(129),
                       @"PCMA/8000/1":   @(128),
                       @"PCMU/8000/1":   @(127),
                       @"speex/32000/1": @(0),
                       @"speex/16000/1": @(0),
                       @"speex/8000/1":  @(0),
                       @"iLBC/8000/1":   @(0),
                       @"GSM/8000/1":    @(0)
                       };
    });
    
    return [priorities[identifier] unsignedIntegerValue];
}

- (void)sendSIPOptionsPingTo:(NSString *)destination
                   transport:(NSString *)transport
                      account:(AKSIPAccount *)account
                   completion:(AKSIPOptionsPingCompletion)completion {
    if (!completion) {
        return;
    }

    AKSIPOptionsPingToken *token = [[AKSIPOptionsPingToken alloc] init];
    token.target = SoftphoneSIPOptionsTarget(destination, transport);
    token.transport = [[transport lowercaseString] length] > 0 ? [transport lowercaseString] : @"udp";
    token.startedAt = [NSDate date];
    token.completion = completion;
    token.userAgent = self;
    token.account = account;

    [self.sipOptionsPingTokens addObject:token];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (token.completed) {
            return;
        }
        token.completed = YES;
        token.completion(SoftphoneSIPPingResult(
            token,
            SoftphoneSIPPingStatusTimeout,
            @"No final SIP response received within 5 seconds.",
            @"The OPTIONS transaction is still owned by PJSIP and may complete later in the SIP log.",
            @""
        ));
    });

    // PJSIP still owns the transaction after SIPMan's UI timeout, so keep the
    // token alive long enough for a late transport callback to arrive safely.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(90 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.sipOptionsPingTokens removeObject:token];
    });

    [self performSelector:@selector(thread_sendSIPOptionsPingWithToken:) onThread:self.thread withObject:token waitUntilDone:NO];
}

- (void)thread_sendSIPOptionsPingWithToken:(AKSIPOptionsPingToken *)token {
    @autoreleasepool {
        if (![self isStarted]) {
            [self completeSIPOptionsPingToken:token result:SoftphoneSIPPingResult(
                token,
                SoftphoneSIPPingStatusFailed,
                @"SIP user agent is not ready.",
                @"Start the SIP user agent before sending a SIP OPTIONS ping.",
                @""
            ) removeToken:YES];
            return;
        }

        pjsip_tx_data *tdata = NULL;
        pj_str_t target = [token.target pjString];
        pj_status_t status;
        if (token.account != nil && token.account.identifier != kAKSIPUserAgentInvalidIdentifier) {
            status = pjsua_acc_create_request(
                (pjsua_acc_id)token.account.identifier,
                pjsip_get_options_method(),
                &target,
                &tdata
            );
        } else {
            // SIP Ping is a diagnostics tool, so allow OPTIONS probes before the
            // selected account has been registered with PJSUA.
            NSString *fromAddress = SoftphoneSIPOptionsFrom(token.account);
            pj_str_t from = [fromAddress pjString];
            status = pjsip_endpt_create_request(
                pjsua_get_pjsip_endpt(),
                pjsip_get_options_method(),
                &target,
                &from,
                &target,
                &from,
                NULL,
                -1,
                NULL,
                &tdata
            );
        }
        if (status != PJ_SUCCESS) {
            [self completeSIPOptionsPingToken:token result:SoftphoneSIPPingResult(
                token,
                SoftphoneSIPPingStatusFailed,
                @"Could not create SIP OPTIONS request.",
                SoftphonePJSIPErrorString(status),
                @""
            ) removeToken:YES];
            return;
        }

        status = pjsip_endpt_send_request(
            pjsua_get_pjsip_endpt(),
            tdata,
            -1,
            (__bridge void *)token,
            &SoftphoneSIPOptionsPingCallback
        );
        if (status != PJ_SUCCESS) {
            if (tdata != NULL) {
                pjsip_tx_data_dec_ref(tdata);
            }
            [self completeSIPOptionsPingToken:token result:SoftphoneSIPPingResult(
                token,
                SoftphoneSIPPingStatusFailed,
                @"Could not send SIP OPTIONS request.",
                SoftphonePJSIPErrorString(status),
                @""
            ) removeToken:YES];
        }
    }
}

- (void)completeSIPOptionsPingToken:(AKSIPOptionsPingToken *)token result:(NSDictionary *)result removeToken:(BOOL)removeToken {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!token.completed) {
            token.completed = YES;
            if (token.completion) {
                token.completion(result);
            }
        }
        if (removeToken) {
            [self.sipOptionsPingTokens removeObject:token];
        }
    });
}

- (NSString *)stringForSIPResponseCode:(NSInteger)responseCode {
    NSString *theString = nil;
    
    switch (responseCode) {
            // Provisional 1xx.
        case PJSIP_SC_TRYING:
            theString = @"Trying";
            break;
        case PJSIP_SC_RINGING:
            theString = @"Ringing";
            break;
        case PJSIP_SC_CALL_BEING_FORWARDED:
            theString = @"Call Is Being Forwarded";
            break;
        case PJSIP_SC_QUEUED:
            theString = @"Queued";
            break;
        case PJSIP_SC_PROGRESS:
            theString = @"Session Progress";
            break;
            
            // Successful 2xx.
        case PJSIP_SC_OK:
            theString = @"OK";
            break;
        case PJSIP_SC_ACCEPTED:
            theString = @"Accepted";
            break;
            
            // Redirection 3xx.
        case PJSIP_SC_MULTIPLE_CHOICES:
            theString = @"Multiple Choices";
            break;
        case PJSIP_SC_MOVED_PERMANENTLY:
            theString = @"Moved Permanently";
            break;
        case PJSIP_SC_MOVED_TEMPORARILY:
            theString = @"Moved Temporarily";
            break;
        case PJSIP_SC_USE_PROXY:
            theString = @"Use Proxy";
            break;
        case PJSIP_SC_ALTERNATIVE_SERVICE:
            theString = @"Alternative Service";
            break;
            
            // Request Failure 4xx.
        case PJSIP_SC_BAD_REQUEST:
            theString = @"Bad Request";
            break;
        case PJSIP_SC_UNAUTHORIZED:
            theString = @"Unauthorized";
            break;
        case PJSIP_SC_PAYMENT_REQUIRED:
            theString = @"Payment Required";
            break;
        case PJSIP_SC_FORBIDDEN:
            theString = @"Forbidden";
            break;
        case PJSIP_SC_NOT_FOUND:
            theString = @"Not Found";
            break;
        case PJSIP_SC_METHOD_NOT_ALLOWED:
            theString = @"Method Not Allowed";
            break;
        case PJSIP_SC_NOT_ACCEPTABLE:
            theString = @"Not Acceptable";
            break;
        case PJSIP_SC_PROXY_AUTHENTICATION_REQUIRED:
            theString = @"Proxy Authentication Required";
            break;
        case PJSIP_SC_REQUEST_TIMEOUT:
            theString = @"Request Timeout";
            break;
        case PJSIP_SC_GONE:
            theString = @"Gone";
            break;
        case PJSIP_SC_REQUEST_ENTITY_TOO_LARGE:
            theString = @"Request Entity Too Large";
            break;
        case PJSIP_SC_REQUEST_URI_TOO_LONG:
            theString = @"Request-URI Too Long";
            break;
        case PJSIP_SC_UNSUPPORTED_MEDIA_TYPE:
            theString = @"Unsupported Media Type";
            break;
        case PJSIP_SC_UNSUPPORTED_URI_SCHEME:
            theString = @"Unsupported URI Scheme";
            break;
        case PJSIP_SC_BAD_EXTENSION:
            theString = @"Bad Extension";
            break;
        case PJSIP_SC_EXTENSION_REQUIRED:
            theString = @"Extension Required";
            break;
        case PJSIP_SC_SESSION_TIMER_TOO_SMALL:
            theString = @"Session Timer Too Small";
            break;
        case PJSIP_SC_INTERVAL_TOO_BRIEF:
            theString = @"Interval Too Brief";
            break;
        case PJSIP_SC_TEMPORARILY_UNAVAILABLE:
            theString = @"Temporarily Unavailable";
            break;
        case PJSIP_SC_CALL_TSX_DOES_NOT_EXIST:
            theString = @"Call/Transaction Does Not Exist";
            break;
        case PJSIP_SC_LOOP_DETECTED:
            theString = @"Loop Detected";
            break;
        case PJSIP_SC_TOO_MANY_HOPS:
            theString = @"Too Many Hops";
            break;
        case PJSIP_SC_ADDRESS_INCOMPLETE:
            theString = @"Address Incomplete";
            break;
        case PJSIP_AC_AMBIGUOUS:
            theString = @"Ambiguous";
            break;
        case PJSIP_SC_BUSY_HERE:
            theString = @"Busy Here";
            break;
        case PJSIP_SC_REQUEST_TERMINATED:
            theString = @"Request Terminated";
            break;
        case PJSIP_SC_NOT_ACCEPTABLE_HERE:
            theString = @"Not Acceptable Here";
            break;
        case PJSIP_SC_BAD_EVENT:
            theString = @"Bad Event";
            break;
        case PJSIP_SC_REQUEST_UPDATED:
            theString = @"Request Updated";
            break;
        case PJSIP_SC_REQUEST_PENDING:
            theString = @"Request Pending";
            break;
        case PJSIP_SC_UNDECIPHERABLE:
            theString = @"Undecipherable";
            break;
            
            // Server Failure 5xx.
        case PJSIP_SC_INTERNAL_SERVER_ERROR:
            theString = @"Server Internal Error";
            break;
        case PJSIP_SC_NOT_IMPLEMENTED:
            theString = @"Not Implemented";
            break;
        case PJSIP_SC_BAD_GATEWAY:
            theString = @"Bad Gateway";
            break;
        case PJSIP_SC_SERVICE_UNAVAILABLE:
            theString = @"Service Unavailable";
            break;
        case PJSIP_SC_SERVER_TIMEOUT:
            theString = @"Server Time-out";
            break;
        case PJSIP_SC_VERSION_NOT_SUPPORTED:
            theString = @"Version Not Supported";
            break;
        case PJSIP_SC_MESSAGE_TOO_LARGE:
            theString = @"Message Too Large";
            break;
        case PJSIP_SC_PRECONDITION_FAILURE:
            theString = @"Precondition Failure";
            break;
            
            // Global Failures 6xx.
        case PJSIP_SC_BUSY_EVERYWHERE:
            theString = @"Busy Everywhere";
            break;
        case PJSIP_SC_DECLINE:
            theString = @"Decline";
            break;
        case PJSIP_SC_DOES_NOT_EXIST_ANYWHERE:
            theString = @"Does Not Exist Anywhere";
            break;
        case PJSIP_SC_NOT_ACCEPTABLE_ANYWHERE:
            theString = @"Not Acceptable";
            break;
        default:
            theString = [NSString stringWithFormat:@"Response code: %ld", responseCode];
            break;
    }
    
    return theString;
}

@end
