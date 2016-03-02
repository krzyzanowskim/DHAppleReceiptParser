//
// Created by Chase Caster on 11/8/13.
// Copyright 2012 Dark Horse Comics
//


#import "DHAppStoreReceipt.h"
#include <openssl/pkcs7.h>
#include <openssl/objects.h>
#import "Payload.h"

@implementation DHASN1Attribute {
    NSData * _Nullable value;
}
@synthesize type;
@synthesize version;
@synthesize dataValue = value;

- (nonnull instancetype)initWithType:(DHAttributeType)theType version:(NSInteger)theVersion value:(nullable id)theValue {
    self = [super init];
    if (self) {
        type = theType;
        version = theVersion;
        value = theValue;
    }
    return self;
}

- (int)dataType {
    const unsigned char *bytes = [value bytes];
    return bytes[0];
}

- (NSString * _Nullable)stringValue {
    NSString *result = nil;

    // strip data type & length from value data, leaving us with only the juicy string bits
    NSData *subData = [value subdataWithRange:NSMakeRange(2, [value length] - 2)];
    if ([self dataType] == V_ASN1_UTF8STRING) {
        result = [[NSString alloc] initWithData:subData encoding:NSUTF8StringEncoding];
    } else if ([self dataType] == V_ASN1_IA5STRING) {
        result = [[NSString alloc] initWithData:subData encoding:NSASCIIStringEncoding];
    }
    return result;
}

- (NSDate * _Nullable)dateValue {
    NSDate *date = nil;
    if ([self dataType] == V_ASN1_IA5STRING) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        date = [formatter dateFromString:[self stringValue]];
    }
    return date;
}

- (NSInteger)integerValue {
    NSInteger result = 0;
    if ([self dataType] == V_ASN1_INTEGER) {
        const unsigned char *bytes = [value bytes];
        int length = [value length];
        // Start counting at 2, because 1 is data type (integer) and 2 is length (which we already know)
        for (int i = 2; i < length; i++) {
            result = result << 8;
            result += bytes[i];
        }
    }
    return result;
}

@end

@implementation DHASN1Parser {
@protected
    NSDictionary *attributesByType;
}

- (NSArray * _Nonnull)attributesForData:(NSData * _Nullable)receiptData {
    NSMutableArray *attributes = [NSMutableArray array];
    if (receiptData == nil) {
        return attributes;
    }

    void *data = (void *)[receiptData bytes];
    size_t len = (size_t)[receiptData length];
    Payload_t *payload = NULL;

    asn_DEF_Payload.ber_decoder(NULL, &asn_DEF_Payload, (void **)&payload, data, len, 0);
    for (size_t i = 0; i < payload->list.count; i++) {
        ReceiptAttribute_t *receiptAttribute = payload->list.array[i];
        OCTET_STRING_t *valueOctet = &receiptAttribute->value;
        NSData *attributeValue = [NSData dataWithBytes:valueOctet->buf length:valueOctet->size];
        [attributes addObject:[[DHASN1Attribute alloc] initWithType:(DHAttributeType)receiptAttribute->type
                                                            version:receiptAttribute->version
                                                              value:attributeValue]];
    }
    return attributes;
}

- (nullable DHASN1Attribute *)attributeByType:(DHAttributeType)type {
    return [attributesByType objectForKey:@(type)];
}

@end

@interface DHAppStoreReceipt ()
@property(readwrite, nonatomic) NSArray<DHInAppReceipt *> * _Nonnull inAppReceipts;
@end

@implementation DHAppStoreReceipt {
}

- (NSArray<DHInAppReceipt *> *)inAppReceipts {
    if (!_inAppReceipts) {
        _inAppReceipts = [NSArray<DHInAppReceipt *> new];
    }
    return _inAppReceipts;
}

+ (DHAppStoreReceipt * _Nullable)mainBundleReceipt {
    return [[DHAppStoreReceipt alloc] initWithURL:[[NSBundle mainBundle] appStoreReceiptURL]];
}

- (_Nullable instancetype)initWithURL:(NSURL * _Nonnull)receiptURL {
    self = [super init];
    if (self) {
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
        receiptData = [self decodePKCS7:receiptData];
        
        if (!receiptData) {
            return nil;
        }

        NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary];
        NSMutableArray <DHInAppReceipt *>*mutableInAppReceiptsArray = [NSMutableArray array];
        for (DHASN1Attribute *attribute in [self attributesForData:receiptData]) {
            if (DH_ATTRIBUTE_TYPE_IN_APP_RECEIPT == attribute.type) {
                DHInAppReceipt *inAppReceipt = [[DHInAppReceipt alloc] initWithData:attribute.dataValue];
                [mutableInAppReceiptsArray addObject:inAppReceipt];
            } else {
                [mutableAttributes setObject:attribute forKey:@(attribute.type)];
            }
        }
        attributesByType = [NSDictionary dictionaryWithDictionary:mutableAttributes];
        self.inAppReceipts = [NSArray arrayWithArray:mutableInAppReceiptsArray];
    }
    return self;
}

- (DHInAppReceipt * _Nullable)receiptForProductId:(NSString * _Nonnull)productId {
    for (DHInAppReceipt *receipt in self.inAppReceipts) {
        if ([receipt.productId isEqualToString: productId]) {
            return receipt;
        }
    }
    return nil;
}


- (NSData *)decodePKCS7:(NSData *)data {
    const unsigned char *bytes = [data bytes];
    PKCS7 *p7 = d2i_PKCS7(NULL, &bytes, [data length]);
    
    if (p7 == NULL) {
        return nil;
    }

    if (!PKCS7_type_is_signed(p7)) {
        PKCS7_free(p7);
        return nil;
    }

    if (!PKCS7_type_is_data(p7->d.sign->contents)) {
        PKCS7_free(p7);
        return nil;
    }
    ASN1_OCTET_STRING *octets = p7->d.sign->contents->d.data;
    return [NSData dataWithBytes:octets->data length:(NSUInteger)octets->length];
}

- (nullable NSString *)bundleId {
    return [[self attributeByType:DH_ATTRIBUTE_TYPE_BUNDLE_ID] stringValue];
}

- (nullable NSString *)applicationVersion {
    return [[self attributeByType:DH_ATTRIBUTE_TYPE_APPLICATION_VERSION] stringValue];
}

- (nullable NSData *)opaqueValue {
    return [[self attributeByType:DH_ATTRIBUTE_TYPE_OPAQUE_VALUE] dataValue];
}

- (nullable NSData *)SHA1Hash {
    return [[self attributeByType:DH_ATTRIBUTE_TYPE_SHA_HASH] dataValue];
}

- (NSString *)originalApplicationVersion {
    return [[self attributeByType:DH_ATTRIBUTE_TYPE_ORIGINAL_APPLICATION_VERSION] stringValue];
}

@end

@implementation DHInAppReceipt
@synthesize receiptData;

- (_Nonnull instancetype)initWithData:(NSData * _Nonnull)data {
    self = [super init];
    if (self) {
        receiptData = data;
        NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary];
        for (DHASN1Attribute *attribute in [self attributesForData:data]) {
            [mutableAttributes setObject:attribute forKey:@(attribute.type)];
        }
        attributesByType = [NSDictionary dictionaryWithDictionary:mutableAttributes];
    }
    return self;
}

- (NSInteger)quantity {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_QUANTITY] integerValue];
}

- (nullable NSString *)productId {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_PRODUCT_ID] stringValue];
}

- (nullable NSString *)transactionId {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_TRANSACTION_ID] stringValue];
}

- (nullable NSString *)originalTransactionId {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_ORIGINAL_TRANSACTION_ID] stringValue];
}

- (nullable NSDate *)purchaseDate {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_PURCHASE_DATE] dateValue];
}

- (nullable NSDate *)originalPurchaseDate {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_ORIGINAL_PURCHASE_DATE] dateValue];
}

- (nullable NSDate *)subscriptionExpirationDate {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_SUBSCRIPTION_EXPIRATION_DATE] dateValue];
}

- (nullable NSDate *)cancellationDate {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_CANCELLATION_DATE] dateValue];
}

- (NSInteger)webOrderLineItemId {
    return [[self attributeByType:DH_ATTRIBUTE_IN_APP_TYPE_WEB_ORDER_LINE_ITEM_ID] integerValue];
}

@end
