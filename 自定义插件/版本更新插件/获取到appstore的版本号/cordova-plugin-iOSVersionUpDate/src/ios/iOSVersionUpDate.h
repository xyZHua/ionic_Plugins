//
//  iOSVersionUpDate.h
//  test6
//
//  Created by Embrace on 2017/10/23.
//

#import <Cordova/CDV.h>

@interface iOSVersionUpDate : CDVPlugin
-(void)checkUpVersion:(CDVInvokedUrlCommand*)command;
@property (strong, nonatomic) CDVInvokedUrlCommand* latestCommand;
   
@end
