//
//  SelectImageVideo.h
//  BoyueApp
//
//  Created by Embrace on 2017/6/19.
//
//

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import "MediaUtils.h"
#import "BYImagePickerController.h"

typedef NS_ENUM(NSInteger, RCExportMP4Status)
{
    RCExportMP4StatusNormal,
    RCExportMP4StatusProcessing,
    RCExportMP4StatusComplete,
    RCExportMP4StatusFail
    
    
};
@interface SelectImageVideo : CDVPlugin<BYImagePickerControllerDelegate> {
    RCExportMP4Status _exportStatus;
    NSURL *_exportMP4Path;
}

@property (nonatomic, strong) NSMutableArray *ImgArr;
@property (nonatomic, strong) NSMutableArray *VideoArr;
@property (strong, nonatomic) CDVInvokedUrlCommand* latestCommand;
@property (readwrite, assign) BOOL hasPendingOperation;


@property (nonatomic, strong) NSArray *getImgArr;
@property (nonatomic, strong) NSArray *finishImgArr;

@property (nonatomic, strong) BYImagePickerController *imgPicker;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger photoCount;

-(void)selectAll:(CDVInvokedUrlCommand *)command;
-(void)selectImage:(CDVInvokedUrlCommand *)command;
-(void)selectVideo:(CDVInvokedUrlCommand *)command;
-(void)selectAllSingle:(CDVInvokedUrlCommand *)command;
-(void)selectImageSingle:(CDVInvokedUrlCommand *)command;
-(void)selectVideoSingle:(CDVInvokedUrlCommand *)command;
-(void)selectVideoByCrop:(CDVInvokedUrlCommand *)command;
-(void)dismissController ;
-(void) imgArr:(NSMutableArray *)imgArr videoArr:(NSMutableArray *)videoArr;

@end

