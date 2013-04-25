//
//  ApplicationBlocker.h
//  ApplicationBlocker
//
//  Created by Oleksii Shvachenko on 24.04.13.
//  Copyright (c) 2013 home. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ApplicationBlocker : NSObject

- (BOOL)canStartApplication;
- (void)blockApplicationForUserInteraction;

@end
