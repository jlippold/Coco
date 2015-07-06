//
//  IAPHelper.m
//  dtvRemote
//
//  Created by Jed Lippold on 6/9/15.
//  Copyright (c) 2015 jed. All rights reserved.
//

#import "IAPHelper.h"

// You need to use StoreKit to access the In-App Purchase APIs, so you import the StoreKit here.
@import StoreKit;

NSString *const IAPHelperProductPurchasedNotification = @"IAPHelperProductPurchasedNotification";
/*
 To receive a list of products from StoreKit, you need to implement the SKProductsRequestDelegate protocol.
 Here you mark the class as implementing this protocol in the class extension.
 For purchasing: modify the class extension to mark the class as implementing the SKPaymentTransactionObserver:
 */
@interface IAPHelper () <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@end

@implementation IAPHelper
{
    /*
     You create an instance variable to store the SKProductsRequest you will issue to retrieve a list of products, while it is active.
     */
    SKProductsRequest *_productsRequest;
    // You also keep track of the completion handler for the outstanding products request, ...
    RequestProductsCompletionHandler _completionHandler;
    // ... the list of product identifiers passed in, ...
    NSSet *_productIdentifiers;
    // ... and the list of product identifiers that have been previously purchased.
    NSMutableSet * _purchasedProductIdentifiers;
}

// Initialitzer to check which products have been purchased or not
- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers
{
    self = [super init];
    if (self) {
        // Store product identifiers
        _productIdentifiers = productIdentifiers;
        
        // Check for previously purchased products
        // This is important in order to check if a user already purchased products, so that we can show them to the user ...
        _purchasedProductIdentifiers = [NSMutableSet set];
        for (NSString *productIdentifier in _productIdentifiers) {
            // TODO: create a BOOL value named "productPurchased" and return a BOOL value for a given productIdentifier (boolForKey) for NSUserDefaults' standardUserDefaults method
            // TODO: once you implemented this, uncomment the if-else statement. Everything should build just fine.
            
            NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.dtvRemote.shares"];
            BOOL productPurchased = [sharedDefaults boolForKey:productIdentifier];
            if (productPurchased) {
                [_purchasedProductIdentifiers addObject:productIdentifier];
                NSLog(@"Previously purchased: %@", productIdentifier);
            } else {
                NSLog(@"Not purchased: %@", productIdentifier);
            }
        }
        // add self as transaction observer
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler
{
    // a copy of the completion handler block inside the instance variable so it can notify the caller when the product request asynchronously completes
    _completionHandler = [completionHandler copy];
    // Create a new instance of SKProductsRequest, which is the Apple-written class that contains the code to pull the info from iTunes Connect
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    _productsRequest = nil;
    NSArray *skProducts = response.products;
    _completionHandler(YES, skProducts);
    _completionHandler = nil;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Failed to load list of products."
                                                      message:nil
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
    [message show];
    
    _productsRequest = nil;
    
    // method definition; (BOOL success, NSArray * products) ... success NO, and the array of products is nil
    _completionHandler(NO, nil);
    _completionHandler = nil;
}

- (BOOL)productPurchased:(NSString *)productIdentifier
{
    return [_purchasedProductIdentifiers containsObject:productIdentifier];
}

- (void)buyProduct:(SKProduct *)product
{
    
    //    TODO: create a SKPayment object ("payment") and call paymentWithProduct that returns a new payment for the specified product ("product)". (hint: 1 LOC)
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    
    //    TODO: issue the SKPayment to the SKPaymentQueue: make the SKPaymentQueue class call the defaultQueue method and add a payment request to the queue (addPayment) for a given payment ("payment"). (hint: 1 LOC)
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    };
}

// called when the transaction was successful
- (void)completeTransaction:(SKPaymentTransaction *)transaction
{
    
    [self provideContentForProductIdentifier:transaction.payment.productIdentifier];
    
    //[[NSUserDefaults standardUserDefaults] setBool:YES forKey:transaction.payment.productIdentifier];
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.dtvRemote.shares"];
    [sharedDefaults setBool:YES forKey:transaction.payment.productIdentifier];
    [sharedDefaults synchronize];
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

// called when a transaction has been restored and successfully completed
- (void)restoreTransaction:(SKPaymentTransaction *)transaction
{
    
    [self provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

// called when a transaction has failed
- (void)failedTransaction:(SKPaymentTransaction *)transaction
{
    if (transaction.error.code != SKErrorPaymentCancelled) {
        NSLog(@"Transaction error: %@", transaction.error.localizedDescription);
        
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Eek!"
                                                          message:transaction.error.localizedDescription
                                                         delegate:nil
                                                cancelButtonTitle:@"OK"
                                                otherButtonTitles:nil];
        [message show];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier
{
    [_purchasedProductIdentifiers addObject:productIdentifier];
    //[[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
    //[[NSUserDefaults standardUserDefaults] synchronize];
    
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.dtvRemote.shares"];
    [sharedDefaults setBool:YES forKey:productIdentifier];
    [sharedDefaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotification
                                                        object:productIdentifier
                                                      userInfo:nil];
}

- (void)restoreCompletedTransactions
{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

@end