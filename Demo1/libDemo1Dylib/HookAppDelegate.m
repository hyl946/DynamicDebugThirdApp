//
//  HookAppDelegate.m
//  libDemo1Dylib
//
//  Created by Loren on 2018/5/11.
//  Copyright © 2018年 Loren. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CaptainHook.h>


static __attribute__((constructor)) void entry(){
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"AppDelegate" message:@"UIApplicationDidFinishLaunching" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    }];
}
