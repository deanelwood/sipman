//
//  AKTelephoneNumberFormatter.m
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

#import "AKTelephoneNumberFormatter.h"

static NSInteger const AKPhoneNumberFormatInternational = 1;
static NSInteger const AKPhoneNumberFormatNational = 2;

@implementation AKTelephoneNumberFormatter

- (NSString *)stringForObjectValue:(id)anObject {
    if (![anObject isKindOfClass:[NSString class]]) {
        return nil;
    }

    NSString *libPhoneNumberValue = [self libPhoneNumberFormattedStringForString:anObject];
    if ([libPhoneNumberValue length] > 0) {
        return libPhoneNumberValue;
    }

    return [self legacyStringForObjectValue:anObject];
}

- (NSString *)libPhoneNumberFormattedStringForString:(NSString *)string {
    NSString *trimmedString = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![self canFormatWithLibPhoneNumber:trimmedString]) {
        return nil;
    }

    Class utilClass = NSClassFromString(@"NBPhoneNumberUtil");
    if (utilClass == nil) {
        return nil;
    }

    id util = [self libPhoneNumberUtilWithClass:utilClass];
    if (util == nil) {
        return nil;
    }

    id phoneNumber = [self libPhoneNumberFromString:trimmedString util:util];
    if (phoneNumber == nil) {
        return nil;
    }

    return [self formattedLibPhoneNumber:phoneNumber
                                    util:util
                            numberFormat:[trimmedString hasPrefix:@"+"] ? AKPhoneNumberFormatInternational : AKPhoneNumberFormatNational];
}

- (BOOL)canFormatWithLibPhoneNumber:(NSString *)string {
    if ([string rangeOfString:@"@"].location != NSNotFound ||
        [string rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound ||
        [string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"*#"]].location != NSNotFound) {
        return NO;
    }

    NSString *digits = [self digitsOnlyFromString:string];
    return [digits length] >= 6 && [digits length] <= 15;
}

- (NSString *)digitsOnlyFromString:(NSString *)string {
    NSCharacterSet *digitCharacterSet = NSCharacterSet.decimalDigitCharacterSet;
    NSMutableString *digits = [[NSMutableString alloc] init];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    NSString *scannedDigits;

    while (![scanner isAtEnd]) {
        [scanner scanUpToCharactersFromSet:digitCharacterSet intoString:NULL];
        if ([scanner scanCharactersFromSet:digitCharacterSet intoString:&scannedDigits]) {
            [digits appendString:scannedDigits];
        }
    }

    return [digits copy];
}

- (id)libPhoneNumberUtilWithClass:(Class)utilClass {
    SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
    if ([utilClass respondsToSelector:sharedInstanceSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id sharedInstance = [utilClass performSelector:sharedInstanceSelector];
#pragma clang diagnostic pop
        if (sharedInstance != nil) {
            return sharedInstance;
        }
    }
    return [[utilClass alloc] init];
}

- (id)libPhoneNumberFromString:(NSString *)string util:(id)util {
    SEL parseSelector = NSSelectorFromString(@"parse:defaultRegion:error:");
    if (![util respondsToSelector:parseSelector]) {
        return nil;
    }

    NSMethodSignature *signature = [util methodSignatureForSelector:parseSelector];
    if (signature == nil) {
        return nil;
    }

    NSString *region = [self defaultRegionCode];
    NSError *__autoreleasing error = nil;
    __unsafe_unretained id unsafePhoneNumber = nil;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:util];
    [invocation setSelector:parseSelector];
    [invocation setArgument:&string atIndex:2];
    [invocation setArgument:&region atIndex:3];
    [invocation setArgument:&error atIndex:4];
    [invocation invoke];
    [invocation getReturnValue:&unsafePhoneNumber];

    id phoneNumber = unsafePhoneNumber;
    return error == nil ? phoneNumber : nil;
}

- (NSString *)formattedLibPhoneNumber:(id)phoneNumber util:(id)util numberFormat:(NSInteger)numberFormat {
    SEL formatSelector = NSSelectorFromString(@"format:numberFormat:error:");
    if (![util respondsToSelector:formatSelector]) {
        return nil;
    }

    NSMethodSignature *signature = [util methodSignatureForSelector:formatSelector];
    if (signature == nil) {
        return nil;
    }

    NSError *__autoreleasing error = nil;
    __unsafe_unretained NSString *unsafeFormattedString = nil;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:util];
    [invocation setSelector:formatSelector];
    [invocation setArgument:&phoneNumber atIndex:2];
    [invocation setArgument:&numberFormat atIndex:3];
    [invocation setArgument:&error atIndex:4];
    [invocation invoke];
    [invocation getReturnValue:&unsafeFormattedString];

    NSString *formattedString = unsafeFormattedString;
    return error == nil ? formattedString : nil;
}

- (NSString *)defaultRegionCode {
    NSString *regionCode;
    if (@available(macOS 13.0, *)) {
        regionCode = [[NSLocale currentLocale] regionCode];
    } else {
        regionCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    }
    return [regionCode length] > 0 ? [regionCode uppercaseString] : @"US";
}

- (NSString *)legacyStringForObjectValue:(id)anObject {
    if (![anObject isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    NSString *theString;
    NSUInteger length = [anObject length];
    
    if ([[NSPredicate predicateWithFormat:@"SELF MATCHES '\\\\d{6,15}'"] evaluateWithObject:anObject]) {
        switch (length) {
            case 6:
                if ([self splitsLastFourDigits]) {  // ##-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 2)],
                                 [anObject substringWithRange:NSMakeRange(2, 2)],
                                 [anObject substringWithRange:NSMakeRange(4, 2)]];
                } else {                             // ###-###
                    theString = [NSString stringWithFormat:@"%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 3)],
                                 [anObject substringWithRange:NSMakeRange(3, 3)]];
                }
                break;
                
            case 7:
                if ([self splitsLastFourDigits]) {  // ###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 3)],
                                 [anObject substringWithRange:NSMakeRange(3, 2)],
                                 [anObject substringWithRange:NSMakeRange(5, 2)]];
                } else {                            // ###-####
                    theString = [NSString stringWithFormat:@"%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 3)],
                                 [anObject substringWithRange:NSMakeRange(3, 4)]];
                }
                break;
                
            case 8:
                if ([self splitsLastFourDigits]) {  // #-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 1)],
                                 [anObject substringWithRange:NSMakeRange(1, 3)],
                                 [anObject substringWithRange:NSMakeRange(4, 2)],
                                 [anObject substringWithRange:NSMakeRange(6, 2)]];
                } else {                            // #-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 1)],
                                 [anObject substringWithRange:NSMakeRange(1, 3)],
                                 [anObject substringWithRange:NSMakeRange(4, 4)]];
                }
                break;
                
            case 9:
                if ([self splitsLastFourDigits]) {  // ##-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 2)],
                                 [anObject substringWithRange:NSMakeRange(2, 3)],
                                 [anObject substringWithRange:NSMakeRange(5, 2)],
                                 [anObject substringWithRange:NSMakeRange(7, 2)]];
                } else {                            // ##-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 2)],
                                 [anObject substringWithRange:NSMakeRange(2, 3)],
                                 [anObject substringWithRange:NSMakeRange(5, 4)]];
                }
                break;
                
            case 10:
                if ([self splitsLastFourDigits]) {  // ###-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 3)],
                                 [anObject substringWithRange:NSMakeRange(3, 3)],
                                 [anObject substringWithRange:NSMakeRange(6, 2)],
                                 [anObject substringWithRange:NSMakeRange(8, 2)]];
                } else {                            // ###-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 3)],
                                 [anObject substringWithRange:NSMakeRange(3, 3)],
                                 [anObject substringWithRange:NSMakeRange(6, 4)]];
                }
                break;
                
            case 11:
                if ([self splitsLastFourDigits]) {  // #-###-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 1)],
                                 [anObject substringWithRange:NSMakeRange(1, 3)],
                                 [anObject substringWithRange:NSMakeRange(4, 3)],
                                 [anObject substringWithRange:NSMakeRange(7, 2)],
                                 [anObject substringWithRange:NSMakeRange(9, 2)]];
                } else {                            // #-###-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 1)],
                                 [anObject substringWithRange:NSMakeRange(1, 3)],
                                 [anObject substringWithRange:NSMakeRange(4, 3)],
                                 [anObject substringWithRange:NSMakeRange(7, 4)]];
                }
                break;
                
            case 12:
                if ([self splitsLastFourDigits]) {  // ##-###-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 2)],
                                 [anObject substringWithRange:NSMakeRange(2, 3)],
                                 [anObject substringWithRange:NSMakeRange(5, 3)],
                                 [anObject substringWithRange:NSMakeRange(8, 2)],
                                 [anObject substringWithRange:NSMakeRange(10, 2)]];
                } else {                            // ##-###-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 2)],
                                 [anObject substringWithRange:NSMakeRange(2, 3)],
                                 [anObject substringWithRange:NSMakeRange(5, 3)],
                                 [anObject substringWithRange:NSMakeRange(8, 4)]];
                }
                break;
                
            case 13:
                if ([self splitsLastFourDigits]) {  // ###-###-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 3)],
                                 [anObject substringWithRange:NSMakeRange(3, 3)],
                                 [anObject substringWithRange:NSMakeRange(6, 3)],
                                 [anObject substringWithRange:NSMakeRange(9, 2)],
                                 [anObject substringWithRange:NSMakeRange(11, 2)]];
                } else {                            // ###-###-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 3)],
                                 [anObject substringWithRange:NSMakeRange(3, 3)],
                                 [anObject substringWithRange:NSMakeRange(6, 3)],
                                 [anObject substringWithRange:NSMakeRange(9, 4)]];
                }
                break;
                
            case 14:
                if ([self splitsLastFourDigits]) {  // ####-###-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 4)],
                                 [anObject substringWithRange:NSMakeRange(4, 3)],
                                 [anObject substringWithRange:NSMakeRange(7, 3)],
                                 [anObject substringWithRange:NSMakeRange(10, 2)],
                                 [anObject substringWithRange:NSMakeRange(12, 2)]];
                } else {                            // ####-###-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 4)],
                                 [anObject substringWithRange:NSMakeRange(4, 3)],
                                 [anObject substringWithRange:NSMakeRange(7, 3)],
                                 [anObject substringWithRange:NSMakeRange(10, 4)]];
                }
                break;
                
            case 15:
                if ([self splitsLastFourDigits]) {  // #####-###-###-##-##
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 5)],
                                 [anObject substringWithRange:NSMakeRange(5, 3)],
                                 [anObject substringWithRange:NSMakeRange(8, 3)],
                                 [anObject substringWithRange:NSMakeRange(11, 2)],
                                 [anObject substringWithRange:NSMakeRange(13, 2)]];
                } else {                            // #####-###-###-####
                    theString = [NSString stringWithFormat:@"%@-%@-%@-%@",
                                 [anObject substringWithRange:NSMakeRange(0, 5)],
                                 [anObject substringWithRange:NSMakeRange(5, 3)],
                                 [anObject substringWithRange:NSMakeRange(8, 3)],
                                 [anObject substringWithRange:NSMakeRange(11, 4)]];
                }
                break;
                
            default:
                theString = anObject;
                break;
        }
    } else if ([[NSPredicate predicateWithFormat:@"SELF MATCHES '\\\\+(1|7)\\\\d{10}'"] evaluateWithObject:anObject]) {
        if ([self splitsLastFourDigits]) {        // +# ###-###-##-##
            theString = [NSString stringWithFormat:@"%@ %@-%@-%@-%@",
                         [anObject substringWithRange:NSMakeRange(0, 2)],
                         [anObject substringWithRange:NSMakeRange(2, 3)],
                         [anObject substringWithRange:NSMakeRange(5, 3)],
                         [anObject substringWithRange:NSMakeRange(8, 2)],
                         [anObject substringWithRange:NSMakeRange(10, 2)]];
        } else {                                  // +# ###-###-####
            theString = [NSString stringWithFormat:@"%@ %@-%@-%@",
                         [anObject substringWithRange:NSMakeRange(0, 2)],
                         [anObject substringWithRange:NSMakeRange(2, 3)],
                         [anObject substringWithRange:NSMakeRange(5, 3)],
                         [anObject substringWithRange:NSMakeRange(8, 4)]];
        }
    } else {
        theString = anObject;
    }
    
    return theString;
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error {
    BOOL returnValue = NO;
    
    NSMutableCharacterSet *phoneNumberCharacterSet
        = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    NSMutableString *telephoneNumber = [[NSMutableString alloc] init];
    
    if ([string hasPrefix:@"+"]) {
        [telephoneNumber appendString:@"+"];
        [scanner setScanLocation:1];
    } else {
        // If the number is not in the international format, allow asterisk and
        // number sign.
        [phoneNumberCharacterSet addCharactersInString:@"*#"];
    }
    
    NSString *aString;
    while (![scanner isAtEnd]) {
        [scanner scanUpToCharactersFromSet:phoneNumberCharacterSet intoString:NULL];
        BOOL scanned = [scanner scanCharactersFromSet:phoneNumberCharacterSet intoString:&aString];
        if (scanned) {
            [telephoneNumber appendString:aString];
        }
    }
    
    if ([telephoneNumber length] > 0) {
        returnValue = YES;
        if (anObject != NULL) {
            *anObject = [telephoneNumber copy];
        }
    } else if (error != NULL) {
        *error = [NSString stringWithFormat:@"Couldn't convert \"%@\" to telephone number", string];
    }
    
    return returnValue;
}

- (NSString *)telephoneNumberFromString:(NSString *)string {
    NSString *telephoneNumber, *error;
    BOOL converted = [self getObjectValue:&telephoneNumber forString:string errorDescription:&error];
    if (converted) {
        return telephoneNumber;
    } else {
        NSLog(@"%@", error);
        return nil;
    }
}

@end
