//
//  NetworkManager.m
//  TinderForPets
//
//  Created by Patrick Trudel on 2019-05-22.
//  Copyright © 2019 Patrick Trudel. All rights reserved.
//

#import "NetworkManager.h"
#import "TinderForPets-Swift.h"

@interface NetworkManager()

@property (nonatomic) BOOL needToInitialize;

@end

@implementation NetworkManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _needToInitialize = YES;
    }
    return self;
}

-(void)fetchAccessToken {
    
    self.clientID = @"chrzhAzFCmSjRpzhiQbMrer1RetIAtJ8vkSAFtlBHxLiUwNkfS";
    self.clientSecret = @"PGJx0pOrLGlM185SNzs2mSN2Rw15ma4JhQR98q3m";
    
    NSString * urlString = @"https://api.petfinder.com/v2/oauth2/token";
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    
    NSString *post = [NSString stringWithFormat:@"grant_type=client_credentials&client_id=%@&client_secret=%@", self.clientID, self.clientSecret];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:postData];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"error: %@", error.localizedDescription);
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        self.accessToken = jsonResponse[@"access_token"];

    }];
    
    [dataTask resume];
}

-(void)fetchDogDataWithLocation: (CLLocation*) location {
    
    if (!self.currentPage) {
        self.currentPage = 1;
    } else {
        self.currentPage += 1;
    }
    
    NSString* lat = [NSString stringWithFormat:@"%f", location.coordinate.latitude];
    
    NSString* lon = [NSString stringWithFormat:@"%f", location.coordinate.longitude];
 
    NSString * urlString = [NSString stringWithFormat:@"https://api.petfinder.com/v2/animals?type=dog&page=%ld&location=%@,%@",(long)self.currentPage,lat,lon];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    NSString *value = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
    [urlRequest addValue:value forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"error: %@", error.localizedDescription);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
        
        
        //checking if token is expired if it is , fetch token then fetch dog data
        if (httpResponse.statusCode == 401) {
            [self fetchAccessToken];
            [self fetchDogDataWithLocation:LocationManager.shared.currentLocation];
        }
        
        NSError *jsonError = nil;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        NSArray *dogs = jsonResponse[@"animals"];
        
        if (jsonError) {
            NSLog(@"jsonError: %@", jsonError.localizedDescription);
            return;
        }
        
        for (NSDictionary *dogDictionary in dogs) {
            Dog * dog = [Dog initWithJSONWithJson:dogDictionary];
            if (dog != nil) {
                
                User.shared.allDogs = [User.shared.allDogs arrayByAddingObject:dog];
                
            }
        }
        
        [self fetchImageForDogsWithCompletionHandler:^(BOOL completed) {
            
            if (completed) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    
                    if (self.needToInitialize) {
                        [self.updateCardDelegate initializeCard];
                        self.needToInitialize = NO;
                    }
                    
                }];
            }
            
        }];
        
        [self.delegate didFetchDogs];
        
        
        
    }];
    
    [dataTask resume];
}



-(void)fetchImageForDogsWithCompletionHandler:(void(^)(BOOL))completed {
    
    for (Dog *dog in User.shared.allDogs) {
        
        
        
        if (dog.image == nil) {
            
            NSURL *url = [NSURL URLWithString:dog.imageURL];
            
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
            
            NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"session error: %@", error.localizedDescription);
                    return;
                }
                
                
                if (User.shared.allDogs.firstObject.image != nil) {
                    completed(YES);
                }
                
                dog.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:location]];
                
                
                
            }];
            
            [downloadTask resume];
        }
        
        
        
        
    }
    
    
    
    
}

#define SINGLETON_FOR_CLASS(NetworkManager)
+ (NetworkManager *) shared {
    static dispatch_once_t pred = 0;
    static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}


@end
