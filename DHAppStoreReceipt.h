//
// Created by Chase Caster on 11/8/13.
// Copyright 2012 Dark Horse Comics
//


#import <Foundation/Foundation.h>

@class DHInAppReceipt;

typedef enum {
    DH_ATTRIBUTE_TYPE_BUNDLE_ID = 1,
    DH_ATTRIBUTE_TYPE_APPLICATION_VERSION = 3,
    DH_ATTRIBUTE_TYPE_OPAQUE_VALUE = 4,
    DH_ATTRIBUTE_TYPE_SHA_HASH = 5,
    DH_ATTRIBUTE_TYPE_IN_APP_RECEIPT = 17,
    DH_ATTRIBUTE_TYPE_ORIGINAL_APPLICATION_VERSION = 19,
    DH_ATTRIBUTE_IN_APP_TYPE_QUANTITY = 1701,
    DH_ATTRIBUTE_IN_APP_TYPE_PRODUCT_ID = 1702,
    DH_ATTRIBUTE_IN_APP_TYPE_TRANSACTION_ID = 1703,
    DH_ATTRIBUTE_IN_APP_TYPE_ORIGINAL_TRANSACTION_ID = 1705,
    DH_ATTRIBUTE_IN_APP_TYPE_PURCHASE_DATE = 1704,
    DH_ATTRIBUTE_IN_APP_TYPE_ORIGINAL_PURCHASE_DATE = 1706,
    DH_ATTRIBUTE_IN_APP_TYPE_SUBSCRIPTION_EXPIRATION_DATE = 1708,
    DH_ATTRIBUTE_IN_APP_TYPE_CANCELLATION_DATE = 1712,
    DH_ATTRIBUTE_IN_APP_TYPE_WEB_ORDER_LINE_ITEM_ID = 1711
} DHAttributeType;

@interface DHASN1Attribute : NSObject

- (nonnull instancetype)initWithType:(DHAttributeType)type version:(NSInteger)version value:(nullable id)value;

@property DHAttributeType type;
@property NSInteger version;
@property(readonly) NSData * _Nullable dataValue;
@property(readonly) NSString * _Nullable stringValue;
@property(readonly) NSDate * _Nullable dateValue;
@property(readonly) NSInteger integerValue;

@end

@interface DHASN1Parser : NSObject

- (NSArray * _Nonnull)attributesForData:(NSData * _Nullable)data;

@end

@interface DHAppStoreReceipt : DHASN1Parser

+ (DHAppStoreReceipt * _Nullable)mainBundleReceipt;
- (_Nullable instancetype)initWithURL:(NSURL * _Nonnull)receiptURL;
- (DHInAppReceipt * _Nullable)receiptForProductId:(NSString * _Nonnull)productId;

@property(readonly) NSString * _Nullable bundleId;
@property(readonly) NSString * _Nullable applicationVersion;
@property(readonly) NSData * _Nullable opaqueValue;
@property(readonly) NSData * _Nullable SHA1Hash;
@property(readonly, nonatomic) NSArray<DHInAppReceipt *> * _Nonnull inAppReceipts;
@property(readonly) NSString * _Null_unspecified originalApplicationVersion;

@end

@interface DHInAppReceipt : DHASN1Parser

- (_Nonnull instancetype)init NS_UNAVAILABLE;
- (_Nonnull instancetype)initWithData:(NSData * _Nonnull)data;

@property(readonly) NSInteger quantity;
@property(readonly) NSString * _Nullable productId;
@property(readonly) NSString * _Nullable transactionId;
@property(readonly) NSString * _Nullable originalTransactionId;
@property(readonly) NSDate * _Nullable purchaseDate;
@property(readonly) NSDate * _Nullable originalPurchaseDate;
@property(readonly) NSDate * _Nullable subscriptionExpirationDate;
@property(readonly) NSDate * _Nullable cancellationDate;
@property(readonly) NSInteger webOrderLineItemId;

@property(readonly) NSData * _Nonnull receiptData;

@end
