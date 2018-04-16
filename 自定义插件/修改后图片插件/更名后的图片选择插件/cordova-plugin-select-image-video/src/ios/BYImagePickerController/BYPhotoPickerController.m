//
//  BYPhotoPickerController.m
//  BoYue
//
//  Created by Embrace on 2017/10/28.
//  Copyright © 2017年 __CompanyName__.com. All rights reserved.
//

#import "BYPhotoPickerController.h"
#import "BYImagePickerController.h"
#import "BYPhotoPreviewController.h"
#import "BYAssetCell.h"
#import "BYAssetModel.h"
#import "UIView+BYLayout.h"
#import "BYImageManager.h"
#import "BYVideoPlayerController.h"
#import "BYGifPhotoPreviewController.h"
#import "BYLocationManager.h"
#import "ImageCutViewController.h"

@interface BYPhotoPickerController ()<UICollectionViewDataSource,UICollectionViewDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,UIAlertViewDelegate> {
    NSMutableArray *_models;
    
    UIView *_bottomToolBar;
    UIButton *_previewButton;
    UIButton *_doneButton;
    UIImageView *_numberImageView;
    UILabel *_numberLabel;
    UIButton *_originalPhotoButton;
    UILabel *_originalPhotoLabel;
    UIView *_divideLine;
    
    BOOL _shouldScrollToBottom;
    BOOL _showTakePhotoBtn;
    
    CGFloat _offsetItemCount;
}
    @property CGRect previousPreheatRect;
    @property (nonatomic, assign) BOOL isSelectOriginalPhoto;
    @property (nonatomic, strong) BYCollectionView *collectionView;
    @property (strong, nonatomic) UICollectionViewFlowLayout *layout;
    @property (nonatomic, strong) UIImagePickerController *imagePickerVc;
    @property (strong, nonatomic) CLLocation *location;
    
    @property (nonatomic, strong)  ImageCutViewController*cutVC;
    @property (nonatomic, strong) NSArray *finishImgArr;
    @end

static CGSize AssetGridThumbnailSize;
static CGFloat itemMargin = 5;

@implementation BYPhotoPickerController
    static inline CGSize JKMainScreenSize() {
        return [UIScreen mainScreen].bounds.size;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (UIImagePickerController *)imagePickerVc {
    if (_imagePickerVc == nil) {
        _imagePickerVc = [[UIImagePickerController alloc] init];
        _imagePickerVc.delegate = self;
        // set appearance / 改变相册选择页的导航栏外观
        _imagePickerVc.navigationBar.barTintColor = self.navigationController.navigationBar.barTintColor;
        _imagePickerVc.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
        UIBarButtonItem *BYBarItem, *BarItem;
        if (iOS9Later) {
            BYBarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[BYImagePickerController class]]];
            BarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UIImagePickerController class]]];
        } else {
            BYBarItem = [UIBarButtonItem appearanceWhenContainedIn:[BYImagePickerController class], nil];
            BarItem = [UIBarButtonItem appearanceWhenContainedIn:[UIImagePickerController class], nil];
        }
        NSDictionary *titleTextAttributes = [BYBarItem titleTextAttributesForState:UIControlStateNormal];
        [BarItem setTitleTextAttributes:titleTextAttributes forState:UIControlStateNormal];
    }
    return _imagePickerVc;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    _isSelectOriginalPhoto = BYImagePickerVc.isSelectOriginalPhoto;
    _shouldScrollToBottom = YES;
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = _model.name;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:BYImagePickerVc.cancelBtnTitleStr style:UIBarButtonItemStylePlain target:BYImagePickerVc action:@selector(cancelButtonClick)];
    if (BYImagePickerVc.navLeftBarButtonSettingBlock) {
        UIButton *leftButton = [UIButton buttonWithType:UIButtonTypeCustom];
        leftButton.frame = CGRectMake(0, 0, 44, 44);
        [leftButton addTarget:self action:@selector(navLeftBarButtonClick) forControlEvents:UIControlEventTouchUpInside];
        BYImagePickerVc.navLeftBarButtonSettingBlock(leftButton);
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
    }
    _showTakePhotoBtn = (_model.isCameraRoll && BYImagePickerVc.allowTakePicture);
    // [self resetCachedAssets];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeStatusBarOrientationNotification:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}
    
- (void)fetchAssetModels {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    if (_isFirstAppear) {
        [BYImagePickerVc showProgressHUD];
    }
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        if (!BYImagePickerVc.sortAscendingByModificationDate && _isFirstAppear && iOS8Later) {
            [[BYImageManager manager] getCameraRollAlbum:BYImagePickerVc.allowPickingVideo allowPickingImage:BYImagePickerVc.allowPickingImage completion:^(BYAlbumModel *model) {
                _model = model;
                _models = [NSMutableArray arrayWithArray:_model.models];
                [self initSubviews];
            }];
        } else {
            if (_showTakePhotoBtn || !iOS8Later || _isFirstAppear) {
                [[BYImageManager manager] getAssetsFromFetchResult:_model.result allowPickingVideo:BYImagePickerVc.allowPickingVideo allowPickingImage:BYImagePickerVc.allowPickingImage completion:^(NSArray<BYAssetModel *> *models) {
                    _models = [NSMutableArray arrayWithArray:models];
                    [self initSubviews];
                }];
            } else {
                _models = [NSMutableArray arrayWithArray:_model.models];
                [self initSubviews];
            }
        }
    });
}
    
- (void)initSubviews {
    dispatch_async(dispatch_get_main_queue(), ^{
        BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
        [BYImagePickerVc hideProgressHUD];
        
        [self checkSelectedModels];
        [self configCollectionView];
        _collectionView.hidden = YES;
        [self configBottomToolBar];
        
        [self scrollCollectionViewToBottom];
    });
}
    
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    BYImagePickerVc.isSelectOriginalPhoto = _isSelectOriginalPhoto;
}
    
- (BOOL)prefersStatusBarHidden {
    return NO;
}
    
- (void)configCollectionView {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    
    _layout = [[UICollectionViewFlowLayout alloc] init];
    _collectionView = [[BYCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:_layout];
    _collectionView.backgroundColor = [UIColor whiteColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.alwaysBounceHorizontal = NO;
    _collectionView.contentInset = UIEdgeInsetsMake(itemMargin, itemMargin, itemMargin, itemMargin);
    
    if (_showTakePhotoBtn && BYImagePickerVc.allowTakePicture ) {
        _collectionView.contentSize = CGSizeMake(self.view.BY_width, ((_model.count + self.columnNumber) / self.columnNumber) * self.view.BY_width);
    } else {
        _collectionView.contentSize = CGSizeMake(self.view.BY_width, ((_model.count + self.columnNumber - 1) / self.columnNumber) * self.view.BY_width);
    }
    [self.view addSubview:_collectionView];
    [_collectionView registerClass:[BYAssetCell class] forCellWithReuseIdentifier:@"BYAssetCell"];
    [_collectionView registerClass:[BYAssetCameraCell class] forCellWithReuseIdentifier:@"BYAssetCameraCell"];
}
    
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Determine the size of the thumbnails to request from the PHCachingImageManager
    CGFloat scale = 2.0;
    if ([UIScreen mainScreen].bounds.size.width > 600) {
        scale = 1.0;
    }
    CGSize cellSize = ((UICollectionViewFlowLayout *)_collectionView.collectionViewLayout).itemSize;
    AssetGridThumbnailSize = CGSizeMake(cellSize.width * scale, cellSize.height * scale);
    
    if (!_models) {
        [self fetchAssetModels];
    }
}
    
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (iOS8Later) {
        // [self updateCachedAssets];
    }
}
    
- (void)configBottomToolBar {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    if (!BYImagePickerVc.showSelectBtn) return;
    
    _bottomToolBar = [[UIView alloc] initWithFrame:CGRectZero];
    CGFloat rgb = 253 / 255.0;
    _bottomToolBar.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:1.0];
    
    _previewButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_previewButton addTarget:self action:@selector(previewButtonClick) forControlEvents:UIControlEventTouchUpInside];
    _previewButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [_previewButton setTitle:BYImagePickerVc.previewBtnTitleStr forState:UIControlStateNormal];
    [_previewButton setTitle:BYImagePickerVc.previewBtnTitleStr forState:UIControlStateDisabled];
    [_previewButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_previewButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    _previewButton.enabled = BYImagePickerVc.selectedModels.count;
    
    if (BYImagePickerVc.allowPickingOriginalPhoto) {
        _originalPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _originalPhotoButton.imageEdgeInsets = UIEdgeInsetsMake(0, -10, 0, 0);
        [_originalPhotoButton addTarget:self action:@selector(originalPhotoButtonClick) forControlEvents:UIControlEventTouchUpInside];
        _originalPhotoButton.titleLabel.font = [UIFont systemFontOfSize:16];
        [_originalPhotoButton setTitle:BYImagePickerVc.fullImageBtnTitleStr forState:UIControlStateNormal];
        [_originalPhotoButton setTitle:BYImagePickerVc.fullImageBtnTitleStr forState:UIControlStateSelected];
        [_originalPhotoButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [_originalPhotoButton setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
        [_originalPhotoButton setImage:[UIImage imageNamedFromMyBundle:BYImagePickerVc.photoOriginDefImageName] forState:UIControlStateNormal];
        [_originalPhotoButton setImage:[UIImage imageNamedFromMyBundle:BYImagePickerVc.photoOriginSelImageName] forState:UIControlStateSelected];
        _originalPhotoButton.selected = _isSelectOriginalPhoto;
        _originalPhotoButton.enabled = BYImagePickerVc.selectedModels.count > 0;
        
        _originalPhotoLabel = [[UILabel alloc] init];
        _originalPhotoLabel.textAlignment = NSTextAlignmentLeft;
        _originalPhotoLabel.font = [UIFont systemFontOfSize:16];
        _originalPhotoLabel.textColor = [UIColor blackColor];
        if (_isSelectOriginalPhoto) [self getSelectedPhotoBytes];
    }
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [_doneButton addTarget:self action:@selector(doneButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_doneButton setTitle:BYImagePickerVc.doneBtnTitleStr forState:UIControlStateNormal];
    [_doneButton setTitle:BYImagePickerVc.doneBtnTitleStr forState:UIControlStateDisabled];
    [_doneButton setTitleColor:BYImagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
    [_doneButton setTitleColor:BYImagePickerVc.oKButtonTitleColorDisabled forState:UIControlStateDisabled];
    _doneButton.enabled = BYImagePickerVc.selectedModels.count || BYImagePickerVc.alwaysEnableDoneBtn;
    
    _numberImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamedFromMyBundle:BYImagePickerVc.photoNumberIconImageName]];
    _numberImageView.hidden = BYImagePickerVc.selectedModels.count <= 0;
    _numberImageView.backgroundColor = [UIColor clearColor];
    
    _numberLabel = [[UILabel alloc] init];
    _numberLabel.font = [UIFont systemFontOfSize:15];
    _numberLabel.textColor = [UIColor whiteColor];
    _numberLabel.textAlignment = NSTextAlignmentCenter;
    _numberLabel.text = [NSString stringWithFormat:@"%zd",BYImagePickerVc.selectedModels.count];
    _numberLabel.hidden = BYImagePickerVc.selectedModels.count <= 0;
    _numberLabel.backgroundColor = [UIColor clearColor];
    
    _divideLine = [[UIView alloc] init];
    CGFloat rgb2 = 222 / 255.0;
    _divideLine.backgroundColor = [UIColor colorWithRed:rgb2 green:rgb2 blue:rgb2 alpha:1.0];
    
    [_bottomToolBar addSubview:_divideLine];
    [_bottomToolBar addSubview:_previewButton];
    [_bottomToolBar addSubview:_doneButton];
    [_bottomToolBar addSubview:_numberImageView];
    [_bottomToolBar addSubview:_numberLabel];
    [self.view addSubview:_bottomToolBar];
    [self.view addSubview:_originalPhotoButton];
    [_originalPhotoButton addSubview:_originalPhotoLabel];
}
    
#pragma mark - Layout
    
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    
    CGFloat top = 0;
    CGFloat collectionViewHeight = 0;
    CGFloat naviBarHeight = self.navigationController.navigationBar.BY_height;
    BOOL isStatusBarHidden = [UIApplication sharedApplication].isStatusBarHidden;
    if (self.navigationController.navigationBar.isTranslucent) {
        top = naviBarHeight;
        if (iOS7Later && !isStatusBarHidden) top += 20;
        collectionViewHeight = BYImagePickerVc.showSelectBtn ? self.view.BY_height - 50 - top : self.view.BY_height - top;;
    } else {
        collectionViewHeight = BYImagePickerVc.showSelectBtn ? self.view.BY_height - 50 : self.view.BY_height;
    }
    _collectionView.frame = CGRectMake(0, top, self.view.BY_width, collectionViewHeight);
    CGFloat itemWH = (self.view.BY_width - (self.columnNumber + 1) * itemMargin) / self.columnNumber;
    _layout.itemSize = CGSizeMake(itemWH, itemWH);
    _layout.minimumInteritemSpacing = itemMargin;
    _layout.minimumLineSpacing = itemMargin;
    [_collectionView setCollectionViewLayout:_layout];
    if (_offsetItemCount > 0) {
        CGFloat offsetY = _offsetItemCount * (_layout.itemSize.height + _layout.minimumLineSpacing);
        [_collectionView setContentOffset:CGPointMake(0, offsetY)];
    }
    
    CGFloat yOffset = 0;
    if (!self.navigationController.navigationBar.isHidden) {
        yOffset = self.view.BY_height - 50;
    } else {
        CGFloat navigationHeight = naviBarHeight;
        if (iOS7Later) navigationHeight += 20;
        yOffset = self.view.BY_height - 50 - navigationHeight;
    }
    _bottomToolBar.frame = CGRectMake(0, yOffset, self.view.BY_width, 50);
    CGFloat previewWidth = [BYImagePickerVc.previewBtnTitleStr boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16]} context:nil].size.width + 2;
    if (!BYImagePickerVc.allowPreview) {
        previewWidth = 0.0;
    }
    _previewButton.frame = CGRectMake(10, 3, previewWidth, 44);
    _previewButton.BY_width = !BYImagePickerVc.showSelectBtn ? 0 : previewWidth;
    if (BYImagePickerVc.allowPickingOriginalPhoto) {
        CGFloat fullImageWidth = [BYImagePickerVc.fullImageBtnTitleStr boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]} context:nil].size.width;
        _originalPhotoButton.frame = CGRectMake(CGRectGetMaxX(_previewButton.frame), self.view.BY_height - 50, fullImageWidth + 56, 50);
        _originalPhotoLabel.frame = CGRectMake(fullImageWidth + 46, 0, 80, 50);
    }
    _doneButton.frame = CGRectMake(self.view.BY_width - 44 - 12, 3, 44, 44);
    _numberImageView.frame = CGRectMake(self.view.BY_width - 56 - 28, 10, 30, 30);
    _numberLabel.frame = _numberImageView.frame;
    _divideLine.frame = CGRectMake(0, 0, self.view.BY_width, 1);
    
    [BYImageManager manager].columnNumber = [BYImageManager manager].columnNumber;
    [self.collectionView reloadData];
}
    
#pragma mark - Notification
    
- (void)didChangeStatusBarOrientationNotification:(NSNotification *)noti {
    _offsetItemCount = _collectionView.contentOffset.y / (_layout.itemSize.height + _layout.minimumLineSpacing);
}
    
#pragma mark - Click Event
- (void)navLeftBarButtonClick{
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)previewButtonClick {
    BYPhotoPreviewController *photoPreviewVc = [[BYPhotoPreviewController alloc] init];
    [self pushPhotoPrevireViewController:photoPreviewVc];
}
    
- (void)originalPhotoButtonClick {
    _originalPhotoButton.selected = !_originalPhotoButton.isSelected;
    _isSelectOriginalPhoto = _originalPhotoButton.isSelected;
    _originalPhotoLabel.hidden = !_originalPhotoButton.isSelected;
    if (_isSelectOriginalPhoto) [self getSelectedPhotoBytes];
}
    
- (void)doneButtonClick {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    // 1.6.8 判断是否满足最小必选张数的限制
    if (BYImagePickerVc.minImagesCount && BYImagePickerVc.selectedModels.count < BYImagePickerVc.minImagesCount) {
        NSString *title = [NSString stringWithFormat:[NSBundle BY_localizedStringForKey:@"Select a minimum of %zd photos"], BYImagePickerVc.minImagesCount];
        [BYImagePickerVc showAlertWithTitle:title];
        return;
    }
    
    [BYImagePickerVc showProgressHUD];
    NSMutableArray *photos = [NSMutableArray array];
    NSMutableArray *assets = [NSMutableArray array];
    NSMutableArray *infoArr = [NSMutableArray array];
    for (NSInteger i = 0; i < BYImagePickerVc.selectedModels.count; i++) { [photos addObject:@1];[assets addObject:@1];[infoArr addObject:@1]; }
    
    __block BOOL havenotShowAlert = YES;
    [BYImageManager manager].shouldFixOrientation = YES;
    __block id alertView;
    for (NSInteger i = 0; i < BYImagePickerVc.selectedModels.count; i++) {
        BYAssetModel *model = BYImagePickerVc.selectedModels[i];
        [[BYImageManager manager] getPhotoWithAsset:model.asset completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
            if (isDegraded) return;
            if (photo) {
                photo = [self scaleImage:photo toSize:CGSizeMake(BYImagePickerVc.photoWidth, (int)(BYImagePickerVc.photoWidth * photo.size.height / photo.size.width))];
                [photos replaceObjectAtIndex:i withObject:photo];
            }
            if (info)  [infoArr replaceObjectAtIndex:i withObject:info];
            [assets replaceObjectAtIndex:i withObject:model.asset];
            
            for (id item in photos) { if ([item isKindOfClass:[NSNumber class]]) return; }
            
            if (havenotShowAlert) {
                [BYImagePickerVc hideAlertView:alertView];
                [self didGetAllPhotos:photos assets:assets infoArr:infoArr];
            }
        } progressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
            // 如果图片正在从iCloud同步中,提醒用户
            if (progress < 1 && havenotShowAlert && !alertView) {
                [BYImagePickerVc hideProgressHUD];
                alertView = [BYImagePickerVc showAlertWithTitle:[NSBundle BY_localizedStringForKey:@"Synchronizing photos from iCloud"]];
                havenotShowAlert = NO;
                return;
            }
            if (progress >= 1) {
                havenotShowAlert = YES;
            }
        } networkAccessAllowed:YES];
    }
    if (BYImagePickerVc.selectedModels.count <= 0) {
        
        [self didGetAllPhotos:photos assets:assets infoArr:infoArr];
    }
}
    
- (void)didGetAllPhotos:(NSArray *)photos assets:(NSArray *)assets infoArr:(NSArray *)infoArr {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    [BYImagePickerVc hideProgressHUD];
    NSLog(@"_height:%ld",_height);
    
    _cutVC= [[ImageCutViewController alloc] init];
    _cutVC.type = JKImageCutterTypeSquare;
    
    if (_height == 0) {
        if (BYImagePickerVc.autoDismiss) {
            [self.navigationController dismissViewControllerAnimated:YES completion:^{
                [self callDelegateMethodWithPhotos:photos assets:assets infoArr:infoArr];
                
            }];
        } else {
            [self callDelegateMethodWithPhotos:photos assets:assets infoArr:infoArr];
        }
        
    } else {
        _cutVC.ImgWidth = JKMainScreenSize().width;
        _cutVC.ImgHeight = (JKMainScreenSize().width/_width)*_height;
        
        [_cutVC
         cutImage:photos completionHandler:^(NSArray *finishArr) {
             
             _finishImgArr = finishArr;
             if (_finishImgArr.count>0) {
                 //             if (BYImagePickerVc.autoDismiss) {
                 [self.navigationController dismissViewControllerAnimated:YES completion:^{
                     [self callDelegateMethodWithPhotos:_finishImgArr assets:assets infoArr:infoArr];
                     //                     NSLog(@"_finishImgArr : %@",_finishImgArr);
                     
                 }];
                 //             } else {
                 [self callDelegateMethodWithPhotos:_finishImgArr assets:assets infoArr:infoArr];
             }
             //         }
         }];
        [self.navigationController pushViewController:_cutVC animated:YES ];
    }
    
    
}
    
- (void)callDelegateMethodWithPhotos:(NSArray *)photos assets:(NSArray *)assets infoArr:(NSArray *)infoArr {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    
    if ([BYImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:)]) {
        [BYImagePickerVc.pickerDelegate imagePickerController:BYImagePickerVc didFinishPickingPhotos:photos sourceAssets:assets isSelectOriginalPhoto:_isSelectOriginalPhoto];
    }
    if ([BYImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:infos:)]) {
        [BYImagePickerVc.pickerDelegate imagePickerController:BYImagePickerVc didFinishPickingPhotos:photos sourceAssets:assets isSelectOriginalPhoto:_isSelectOriginalPhoto infos:infoArr];
    }
    if (BYImagePickerVc.didFinishPickingPhotosHandle) {
        
        BYImagePickerVc.didFinishPickingPhotosHandle(photos,assets,_isSelectOriginalPhoto);
    }
    if (BYImagePickerVc.didFinishPickingPhotosWithInfosHandle) {
        BYImagePickerVc.didFinishPickingPhotosWithInfosHandle(photos,assets,_isSelectOriginalPhoto,infoArr);
    }
}
    
#pragma mark - UICollectionViewDataSource && Delegate
    
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (_showTakePhotoBtn) {
        BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
        if (BYImagePickerVc.allowPickingImage && BYImagePickerVc.allowTakePicture) {
            return _models.count + 1;
        }
    }
    return _models.count;
}
    
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    // the cell lead to take a picture / 去拍照的cell
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    if (((BYImagePickerVc.sortAscendingByModificationDate && indexPath.row >= _models.count) || (!BYImagePickerVc.sortAscendingByModificationDate && indexPath.row == 0)) && _showTakePhotoBtn) {
        BYAssetCameraCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BYAssetCameraCell" forIndexPath:indexPath];
        cell.imageView.image = [UIImage imageNamedFromMyBundle:BYImagePickerVc.takePictureImageName];
        return cell;
    }
    // the cell dipaly photo or video / 展示照片或视频的cell
    BYAssetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BYAssetCell" forIndexPath:indexPath];
    cell.allowPickingMultipleVideo = BYImagePickerVc.allowPickingMultipleVideo;
    cell.photoDefImageName = BYImagePickerVc.photoDefImageName;
    cell.photoSelImageName = BYImagePickerVc.photoSelImageName;
    BYAssetModel *model;
    if (BYImagePickerVc.sortAscendingByModificationDate || !_showTakePhotoBtn) {
        model = _models[indexPath.row];
    } else {
        model = _models[indexPath.row - 1];
    }
    cell.allowPickingGif = BYImagePickerVc.allowPickingGif;
    cell.model = model;
    cell.showSelectBtn = BYImagePickerVc.showSelectBtn;
    cell.allowPreview = BYImagePickerVc.allowPreview;
    
    __weak typeof(cell) weakCell = cell;
    __weak typeof(self) weakSelf = self;
    __weak typeof(_numberImageView.layer) weakLayer = _numberImageView.layer;
    cell.didSelectPhotoBlock = ^(BOOL isSelected) {
        BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)weakSelf.navigationController;
        // 1. cancel select / 取消选择
        if (isSelected) {
            weakCell.selectPhotoButton.selected = NO;
            model.isSelected = NO;
            NSArray *selectedModels = [NSArray arrayWithArray:BYImagePickerVc.selectedModels];
            for (BYAssetModel *model_item in selectedModels) {
                if ([[[BYImageManager manager] getAssetIdentifier:model.asset] isEqualToString:[[BYImageManager manager] getAssetIdentifier:model_item.asset]]) {
                    [BYImagePickerVc.selectedModels removeObject:model_item];
                    break;
                }
            }
            [weakSelf refreshBottomToolBarStatus];
        } else {
            // 2. select:check if over the maxImagesCount / 选择照片,检查是否超过了最大个数的限制
            if (BYImagePickerVc.selectedModels.count < BYImagePickerVc.maxImagesCount) {
                weakCell.selectPhotoButton.selected = YES;
                model.isSelected = YES;
                [BYImagePickerVc.selectedModels addObject:model];
                [weakSelf refreshBottomToolBarStatus];
            } else {
                NSString *title = [NSString stringWithFormat:[NSBundle BY_localizedStringForKey:@"Select a maximum of %zd photos"], BYImagePickerVc.maxImagesCount];
                [BYImagePickerVc showAlertWithTitle:title];
            }
        }
        [UIView showOscillatoryAnimationWithLayer:weakLayer type:BYOscillatoryAnimationToSmaller];
    };
    return cell;
}
    
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // take a photo / 去拍照
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    if (((BYImagePickerVc.sortAscendingByModificationDate && indexPath.row >= _models.count) || (!BYImagePickerVc.sortAscendingByModificationDate && indexPath.row == 0)) && _showTakePhotoBtn)  {
        [self takePhoto]; return;
    }
    // preview phote or video / 预览照片或视频
    NSInteger index = indexPath.row;
    if (!BYImagePickerVc.sortAscendingByModificationDate && _showTakePhotoBtn) {
        index = indexPath.row - 1;
    }
    BYAssetModel *model = _models[index];
    if (model.type == BYAssetModelMediaTypeVideo && !BYImagePickerVc.allowPickingMultipleVideo) {
        if (BYImagePickerVc.selectedModels.count > 0) {
            BYImagePickerController *imagePickerVc = (BYImagePickerController *)self.navigationController;
            [imagePickerVc showAlertWithTitle:[NSBundle BY_localizedStringForKey:@"Can not choose both video and photo"]];
        } else {
            BYVideoPlayerController *videoPlayerVc = [[BYVideoPlayerController alloc] init];
            videoPlayerVc.model = model;
            [self.navigationController pushViewController:videoPlayerVc animated:YES];
        }
    } else if (model.type == BYAssetModelMediaTypePhotoGif && BYImagePickerVc.allowPickingGif && !BYImagePickerVc.allowPickingMultipleVideo) {
        if (BYImagePickerVc.selectedModels.count > 0) {
            BYImagePickerController *imagePickerVc = (BYImagePickerController *)self.navigationController;
            [imagePickerVc showAlertWithTitle:[NSBundle BY_localizedStringForKey:@"Can not choose both photo and GIF"]];
        } else {
            BYGifPhotoPreviewController *gifPreviewVc = [[BYGifPhotoPreviewController alloc] init];
            gifPreviewVc.model = model;
            [self.navigationController pushViewController:gifPreviewVc animated:YES];
        }
    } else {
        BYPhotoPreviewController *photoPreviewVc = [[BYPhotoPreviewController alloc] init];
        photoPreviewVc.currentIndex = index;
        photoPreviewVc.models = _models;
        [self pushPhotoPrevireViewController:photoPreviewVc];
    }
}
    
#pragma mark - UIScrollViewDelegate
    
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (iOS8Later) {
        // [self updateCachedAssets];
    }
}
    
#pragma mark - Private Method
    
    /// 拍照按钮点击事件
- (void)takePhoto {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if ((authStatus == AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied) && iOS7Later) {
        // 无权限 做一个友好的提示
        NSString *appName = [[NSBundle mainBundle].infoDictionary valueForKey:@"CFBundleDisplayName"];
        if (!appName) appName = [[NSBundle mainBundle].infoDictionary valueForKey:@"CFBundleName"];
        NSString *message = [NSString stringWithFormat:[NSBundle BY_localizedStringForKey:@"Please allow %@ to access your camera in \"Settings -> Privacy -> Camera\""],appName];
        if (iOS8Later) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSBundle BY_localizedStringForKey:@"Can not use camera"] message:message delegate:self cancelButtonTitle:[NSBundle BY_localizedStringForKey:@"Cancel"] otherButtonTitles:[NSBundle BY_localizedStringForKey:@"Setting"], nil];
            [alert show];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSBundle BY_localizedStringForKey:@"Can not use camera"] message:message delegate:self cancelButtonTitle:[NSBundle BY_localizedStringForKey:@"OK"] otherButtonTitles:nil];
            [alert show];
        }
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        if (iOS7Later) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self pushImagePickerController];
                    });
                }
            }];
        } else {
            [self pushImagePickerController];
        }
    } else {
        [self pushImagePickerController];
    }
}
    
    // 调用相机
- (void)pushImagePickerController {
    // 提前定位
    __weak typeof(self) weakSelf = self;
    [[BYLocationManager manager] startLocationWithSuccessBlock:^(CLLocation *location, CLLocation *oldLocation) {
        weakSelf.location = location;
    } failureBlock:^(NSError *error) {
        weakSelf.location = nil;
    }];
    
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        self.imagePickerVc.sourceType = sourceType;
        if(iOS8Later) {
            _imagePickerVc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        }
        [self presentViewController:_imagePickerVc animated:YES completion:nil];
    } else {
        NSLog(@"模拟器中无法打开照相机,请在真机中使用");
    }
}
    
- (void)refreshBottomToolBarStatus {
   BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    
    _previewButton.enabled = BYImagePickerVc.selectedModels.count > 0;
    _doneButton.enabled = BYImagePickerVc.selectedModels.count > 0 || BYImagePickerVc.alwaysEnableDoneBtn;
    
    _numberImageView.hidden = BYImagePickerVc.selectedModels.count <= 0;
    _numberLabel.hidden = BYImagePickerVc.selectedModels.count <= 0;
    _numberLabel.text = [NSString stringWithFormat:@"%zd",BYImagePickerVc.selectedModels.count];
    
    _originalPhotoButton.enabled = BYImagePickerVc.selectedModels.count > 0;
    _originalPhotoButton.selected = (_isSelectOriginalPhoto && _originalPhotoButton.enabled);
    _originalPhotoLabel.hidden = (!_originalPhotoButton.isSelected);
    if (_isSelectOriginalPhoto) [self getSelectedPhotoBytes];
}
    
- (void)pushPhotoPrevireViewController:(BYPhotoPreviewController *)photoPreviewVc {
    __weak typeof(self) weakSelf = self;
    photoPreviewVc.isSelectOriginalPhoto = _isSelectOriginalPhoto;
    [photoPreviewVc setBackButtonClickBlock:^(BOOL isSelectOriginalPhoto) {
        weakSelf.isSelectOriginalPhoto = isSelectOriginalPhoto;
        [weakSelf.collectionView reloadData];
        [weakSelf refreshBottomToolBarStatus];
    }];
    [photoPreviewVc setDoneButtonClickBlock:^(BOOL isSelectOriginalPhoto) {
        weakSelf.isSelectOriginalPhoto = isSelectOriginalPhoto;
        [weakSelf doneButtonClick];
    }];
    [photoPreviewVc setDoneButtonClickBlockCropMode:^(UIImage *cropedImage, id asset) {
        [weakSelf didGetAllPhotos:@[cropedImage] assets:@[asset] infoArr:nil];
    }];
    [self.navigationController pushViewController:photoPreviewVc animated:YES];
}
    
- (void)getSelectedPhotoBytes {
    BYImagePickerController *imagePickerVc = (BYImagePickerController *)self.navigationController;
    [[BYImageManager manager] getPhotosBytesWithArray:imagePickerVc.selectedModels completion:^(NSString *totalBytes) {
        _originalPhotoLabel.text = [NSString stringWithFormat:@"(%@)",totalBytes];
    }];
}
    
    /// Scale image / 缩放图片
- (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)size {
    if (image.size.width < size.width) {
        return image;
    }
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
    
- (void)scrollCollectionViewToBottom {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    if (_shouldScrollToBottom && _models.count > 0) {
        NSInteger item = 0;
        if (BYImagePickerVc.sortAscendingByModificationDate) {
            item = _models.count - 1;
            if (_showTakePhotoBtn) {
                BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
                if (BYImagePickerVc.allowPickingImage && BYImagePickerVc.allowTakePicture) {
                    item += 1;
                }
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
            _shouldScrollToBottom = NO;
            _collectionView.hidden = NO;
        });
    } else {
        _collectionView.hidden = NO;
    }
}
    
- (void)checkSelectedModels {
    for (BYAssetModel *model in _models) {
        model.isSelected = NO;
        NSMutableArray *selectedAssets = [NSMutableArray array];
        BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
        for (BYAssetModel *model in BYImagePickerVc.selectedModels) {
            [selectedAssets addObject:model.asset];
        }
        if ([[BYImageManager manager] isAssetsArray:selectedAssets containAsset:model.asset]) {
            model.isSelected = YES;
        }
    }
}
    
#pragma mark - UIAlertViewDelegate
    
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // 去设置界面，开启相机访问权限
        if (iOS8Later) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }
    }
}
    
#pragma mark - UIImagePickerControllerDelegate
    
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    if ([type isEqualToString:@"public.image"]) {
        BYImagePickerController *imagePickerVc = (BYImagePickerController *)self.navigationController;
        [imagePickerVc showProgressHUD];
        UIImage *photo = [info objectForKey:UIImagePickerControllerOriginalImage];
        if (photo) {
            [[BYImageManager manager] savePhotoWithImage:photo location:self.location completion:^(NSError *error){
                if (!error) {
                    [self reloadPhotoArray];
                }
            }];
            self.location = nil;
        }
    }
}
    
- (void)reloadPhotoArray {
    BYImagePickerController *BYImagePickerVc = (BYImagePickerController *)self.navigationController;
    [[BYImageManager manager] getCameraRollAlbum:BYImagePickerVc.allowPickingVideo allowPickingImage:BYImagePickerVc.allowPickingImage completion:^(BYAlbumModel *model) {
        _model = model;
        [[BYImageManager manager] getAssetsFromFetchResult:_model.result allowPickingVideo:BYImagePickerVc.allowPickingVideo allowPickingImage:BYImagePickerVc.allowPickingImage completion:^(NSArray<BYAssetModel *> *models) {
            [BYImagePickerVc hideProgressHUD];
            
            BYAssetModel *assetModel;
            if (BYImagePickerVc.sortAscendingByModificationDate) {
                assetModel = [models lastObject];
                [_models addObject:assetModel];
            } else {
                assetModel = [models firstObject];
                [_models insertObject:assetModel atIndex:0];
            }
            
            if (BYImagePickerVc.maxImagesCount <= 1) {
                if (BYImagePickerVc.allowCrop) {
                    BYPhotoPreviewController *photoPreviewVc = [[BYPhotoPreviewController alloc] init];
                    if (BYImagePickerVc.sortAscendingByModificationDate) {
                        photoPreviewVc.currentIndex = _models.count - 1;
                    } else {
                        photoPreviewVc.currentIndex = 0;
                    }
                    photoPreviewVc.models = _models;
                    [self pushPhotoPrevireViewController:photoPreviewVc];
                } else {
                    [BYImagePickerVc.selectedModels addObject:assetModel];
                    [self doneButtonClick];
                }
                return;
            }
            
            if (BYImagePickerVc.selectedModels.count < BYImagePickerVc.maxImagesCount) {
                assetModel.isSelected = YES;
                [BYImagePickerVc.selectedModels addObject:assetModel];
                [self refreshBottomToolBarStatus];
            }
            _collectionView.hidden = YES;
            [_collectionView reloadData];
            
            _shouldScrollToBottom = YES;
            [self scrollCollectionViewToBottom];
        }];
    }];
}
    
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}
    
- (void)dealloc {
    // NSLog(@"%@ dealloc",NSStringFromClass(self.class));
}
    
#pragma mark - Asset Caching
    
- (void)resetCachedAssets {
    [[BYImageManager manager].cachingImageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}
    
- (void)updateCachedAssets {
    BOOL isViewVisible = [self isViewLoaded] && [[self view] window] != nil;
    if (!isViewVisible) { return; }
    
    // The preheat window is twice the height of the visible rect.
    CGRect preheatRect = _collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    /*
     Check if the collection view is showing an area that is significantly
     different to the last preheated area.
     */
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(_collectionView.bounds) / 3.0f) {
        
        // Compute the assets to start caching and to stop caching.
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self aapl_indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self aapl_indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        // Update the assets the PHCachingImageManager is caching.
        [[BYImageManager manager].cachingImageManager startCachingImagesForAssets:assetsToStartCaching
                                                                       targetSize:AssetGridThumbnailSize
                                                                      contentMode:PHImageContentModeAspectFill
                                                                          options:nil];
        [[BYImageManager manager].cachingImageManager stopCachingImagesForAssets:assetsToStopCaching
                                                                      targetSize:AssetGridThumbnailSize
                                                                     contentMode:PHImageContentModeAspectFill
                                                                         options:nil];
        
        // Store the preheat rect to compare against in the future.
        self.previousPreheatRect = preheatRect;
    }
}
    
- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler {
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}
    
- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths {
    if (indexPaths.count == 0) { return nil; }
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.item < _models.count) {
            BYAssetModel *model = _models[indexPath.item];
            [assets addObject:model.asset];
        }
    }
    
    return assets;
}
    
- (NSArray *)aapl_indexPathsForElementsInRect:(CGRect)rect {
    NSArray *allLayoutAttributes = [_collectionView.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (allLayoutAttributes.count == 0) { return nil; }
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    return indexPaths;
}
#pragma clang diagnostic pop
    
    @end



@implementation BYCollectionView
    
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ([view isKindOfClass:[UIControl class]]) {
        return YES;
    }
    return [super touchesShouldCancelInContentView:view];
}

@end
