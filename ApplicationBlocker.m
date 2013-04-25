//
//  ApplicationBlocker.m
//  ApplicationBlocker
//
//  Created by Oleksii Shvachenko on 24.04.13.
//  Copyright (c) 2013 home. All rights reserved.
//

#import "ApplicationBlocker.h"
#import <Security/Security.h>

static const NSInteger kWorkingDays = 30;

@interface ApplicationBlocker()

@property (nonatomic, retain) NSMutableDictionary *keychainItemData;
@property (nonatomic, retain) NSMutableDictionary *genericPasswordQuery;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, retain) NSDate *startDate;

@end

@implementation ApplicationBlocker

@synthesize keychainItemData, genericPasswordQuery, identifier, startDate;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        self.identifier = [NSString stringWithFormat:@"ApplicationStartDate_v%@", version];
        [self initKeychain];
        [self setObject:identifier forKey:kSecAttrService];
        self.startDate = [self objectForKey:kSecAttrCreationDate];
        if (startDate == nil)
        {
            self.startDate = [NSDate date];
            [self setObject:self.startDate forKey:kSecAttrCreationDate];
        }
    }
    return self;
}

- (BOOL)canStartApplication
{
    NSInteger workingDaysInSeconds = kWorkingDays * 24 * 60 * 60;
    NSDate *blockingDate = [startDate dateByAddingTimeInterval:workingDaysInSeconds];
    NSComparisonResult compareResult = [blockingDate compare:[NSDate date]];
    
    return compareResult == NSOrderedDescending;
}

- (void)blockApplicationForUserInteraction
{
    UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:@"Time is over" message:@"Time for use this application is over!" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil] autorelease];
    [alertView show];
}

- (void)dealloc
{
    [keychainItemData release];
    [genericPasswordQuery release];
    [startDate release];
    
	[super dealloc];
}
#pragma mark - Private

- (void)setObject:(id)inObject forKey:(id)key
{
    if (inObject == nil) return;
    id currentObject = [keychainItemData objectForKey:key];
    if (![currentObject isEqual:inObject])
    {
        [keychainItemData setObject:inObject forKey:key];
        [self writeToKeychain];
    }
}

- (id)objectForKey:(id)key
{
    return [keychainItemData objectForKey:key];
}


- (void)initKeychain
{
    // Begin Keychain search setup. The genericPasswordQuery leverages the special user
    // defined attribute kSecAttrGeneric to distinguish itself between other generic Keychain
    // items which may be included by the same application.
    genericPasswordQuery = [[NSMutableDictionary alloc] init];
    
    [genericPasswordQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [genericPasswordQuery setObject:self.identifier forKey:(id)kSecAttrGeneric];
    
    // Use the proper search constants, return only the attributes of the first match.
    [genericPasswordQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    [genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
    
    NSDictionary *tempQuery = [NSDictionary dictionaryWithDictionary:genericPasswordQuery];
    
    NSMutableDictionary *outDictionary = nil;
    
    if (! SecItemCopyMatching((CFDictionaryRef)tempQuery, (CFTypeRef *)&outDictionary) == noErr)
    {
        // Stick these default values into keychain item if nothing found.
        [self resetKeychainItem];
        
        // Add the generic attribute and the keychain access group.
        [keychainItemData setObject:self.identifier forKey:(id)kSecAttrGeneric];
    }
    else
    {
        // load the saved data from Keychain.
        self.keychainItemData = [self secItemFormatToDictionary:outDictionary];
    }
    
    [outDictionary release];
}

- (void)resetKeychainItem
{
	OSStatus junk = noErr;
    if (!keychainItemData)
    {
        self.keychainItemData = [[NSMutableDictionary alloc] init];
    }
    else if (keychainItemData)
    {
        NSMutableDictionary *tempDictionary = [self dictionaryToSecItemFormat:keychainItemData];
		junk = SecItemDelete((CFDictionaryRef)tempDictionary);
        NSAssert( junk == noErr || junk == errSecItemNotFound, @"Problem deleting current dictionary." );
    }
    
    // Default attributes for keychain item.
    [keychainItemData setObject:@"" forKey:(id)kSecAttrAccount];
    [keychainItemData setObject:@"" forKey:(id)kSecAttrLabel];
    [keychainItemData setObject:@"" forKey:(id)kSecAttrDescription];
    
	// Default data for keychain item.
    [keychainItemData setObject:@"" forKey:(id)kSecValueData];
}

- (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert
{
    // The assumption is that this method will be called with a properly populated dictionary
    // containing all the right key/value pairs for a SecItem.
    
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    
    // Add the Generic Password keychain item class attribute.
    [returnDictionary setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    
    // Convert the NSString to NSData to meet the requirements for the value type kSecValueData.
	// This is where to store sensitive data that should be encrypted.
    NSString *passwordString = [dictionaryToConvert objectForKey:(id)kSecValueData];
    [returnDictionary setObject:[passwordString dataUsingEncoding:NSUTF8StringEncoding] forKey:(id)kSecValueData];
    
    return returnDictionary;
}

- (NSMutableDictionary *)secItemFormatToDictionary:(NSDictionary *)dictionaryToConvert
{
    // The assumption is that this method will be called with a properly populated dictionary
    // containing all the right key/value pairs for the UI element.
    
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    
    // Add the proper search key and class attribute.
    [returnDictionary setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [returnDictionary setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    
    // Acquire the password data from the attributes.
    NSData *passwordData = NULL;
    if (SecItemCopyMatching((CFDictionaryRef)returnDictionary, (CFTypeRef *)&passwordData) == noErr)
    {
        // Remove the search, class, and identifier key/value, we don't need them anymore.
        [returnDictionary removeObjectForKey:(id)kSecReturnData];
        
        // Add the password to the dictionary, converting from NSData to NSString.
        NSString *password = [[[NSString alloc] initWithBytes:[passwordData bytes] length:[passwordData length]
                                                     encoding:NSUTF8StringEncoding] autorelease];
        [returnDictionary setObject:password forKey:(id)kSecValueData];
    }
    else
    {
        // Don't do anything if nothing is found.
        NSAssert(NO, @"Serious error, no matching item found in the keychain.\n");
    }
    
    [passwordData release];
    
	return returnDictionary;
}

- (void)writeToKeychain
{
    NSDictionary *attributes = NULL;
    NSMutableDictionary *updateItem = NULL;
	OSStatus result;
    
    if (SecItemCopyMatching((CFDictionaryRef)genericPasswordQuery, (CFTypeRef *)&attributes) == noErr)
    {
        // First we need the attributes from the Keychain.
        updateItem = [NSMutableDictionary dictionaryWithDictionary:attributes];
        // Second we need to add the appropriate search key/values.
        [updateItem setObject:[genericPasswordQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
        
        // Lastly, we need to set up the updated attribute list being careful to remove the class.
        NSMutableDictionary *tempCheck = [self dictionaryToSecItemFormat:keychainItemData];
        [tempCheck removeObjectForKey:(id)kSecClass];
		
#if TARGET_IPHONE_SIMULATOR
		// Remove the access group if running on the iPhone simulator.
		//
		// Apps that are built for the simulator aren't signed, so there's no keychain access group
		// for the simulator to check. This means that all apps can see all keychain items when run
		// on the simulator.
		//
		// If a SecItem contains an access group attribute, SecItemAdd and SecItemUpdate on the
		// simulator will return -25243 (errSecNoAccessForItem).
		//
		// The access group attribute will be included in items returned by SecItemCopyMatching,
		// which is why we need to remove it before updating the item.
		[tempCheck removeObjectForKey:(id)kSecAttrAccessGroup];
#endif
        
        // An implicit assumption is that you can only update a single item at a time.
		
        result = SecItemUpdate((CFDictionaryRef)updateItem, (CFDictionaryRef)tempCheck);
		NSAssert( result == noErr, @"Couldn't update the Keychain Item." );
    }
    else
    {
        // No previous item found; add the new one.
        result = SecItemAdd((CFDictionaryRef)[self dictionaryToSecItemFormat:keychainItemData], NULL);
		NSAssert( result == noErr, @"Couldn't add the Keychain Item." );
    }
}



@end
