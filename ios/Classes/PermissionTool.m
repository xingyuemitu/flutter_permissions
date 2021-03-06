//
//  PermissionTool.m
//  flutter_permissions
//
//  Created by linwenhui on 2018/10/12.
//

#import "PermissionTool.h"

typedef void(^AuthStatus)(NSInteger authStatus);

@interface PermissionTool ()

@property(nonatomic, copy)AuthStatus statusBlock;

@end

static PermissionTool *tools;

@implementation PermissionTool
#pragma mark 单例-定位代理用
+(instancetype)shareUserInfo {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tools = [[self alloc] init];
    });
    return tools;
}
// 返回主线程 (如果当前是主线程 则无需返回)
+ (void)returnMainThread:(void (^)(void))block {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    } else {
        block();
    }
}

/**
 *  获取写入照片权限
 */
#pragma mark 照片
+(void)getPhotosPermission:(void (^)(NSInteger authStatus))block {
    NSDictionary *infoDict =[[NSBundle mainBundle] infoDictionary];
    if (!infoDict[@"NSPhotoLibraryUsageDescription"]) {
        NSLog(@"为适配iOS10 请在info.plist文件中加入\n\"NSPhotoLibraryUsageDescription\"字段");
    }
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    PHAuthorizationStatus authStatus =[PHPhotoLibrary authorizationStatus];
    switch (authStatus) {
        case AVAuthorizationStatusNotDetermined: {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    [PermissionTool returnMainThread:^{
                        block(3);
                    }];
                } else {
                    [PermissionTool returnMainThread:^{
                        block(2);
                    }];
                }
            }];
            break;
        }
        case AVAuthorizationStatusRestricted: {
            [PermissionTool returnMainThread:^{
                block(1);
            }];
            break;
        }
        case AVAuthorizationStatusDenied: {
            [PermissionTool returnMainThread:^{
                block(2);
            }];
            break;
        }
        default: {
            [PermissionTool returnMainThread:^{
                block(0);
            }];
            break;
        }
    }
    
#else
    //    iOS8以前
    if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusNotDetermined) {
        //需要询问
        ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
        [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (*stop) {
                [PermissionTool returnMainThread:^{
                    block(3);
                }];
            } else {
                [PermissionTool returnMainThread:^{
                    block(2);
                }];            }
            *stop = TRUE;//不能省略
        } failureBlock:^(NSError *error) {
            [PermissionTool returnMainThread:^{
                block(2);
            }];
        }];
    } else if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusRestricted) {
        [PermissionTool returnMainThread:^{
            block(1);
        }];
    } else if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusDenied) {
        [PermissionTool returnMainThread:^{
            block(2);
        }];
    } else {
        [PermissionTool returnMainThread:^{
            block(0);
        }];
    }
#endif
}
//摄像头/麦克风
+ (void)userPermission:(NSString*)mediaTyp result:(void (^)(NSInteger authStatus))block {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaTyp];
    switch (authStatus) {
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:mediaTyp completionHandler:^(BOOL granted) {
                [PermissionTool returnMainThread:^{
                    if (granted) {
                        block(3);
                    } else {
                        block(2);
                    }
                }];
            }];
            break;
        }
        case AVAuthorizationStatusRestricted: {
            [PermissionTool returnMainThread:^{
                block(1);
            }];
            break;
        }
        case AVAuthorizationStatusDenied: {
            [PermissionTool returnMainThread:^{
                block(2);
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized:{
            [PermissionTool returnMainThread:^{
                block(3);
            }];
        }
            break;
        default: {
            [PermissionTool returnMainThread:^{
                block(0);
            }];
            break;
        }
    }
}
/**
 *  获取访问摄像头权限(模拟器上无法测试)
 */
#pragma mark 摄像头
+ (void)getCamerasPermission:(void (^)(NSInteger authStatus))block {
    NSDictionary *infoDict =[[NSBundle mainBundle] infoDictionary];
    if (!infoDict[@"NSCameraUsageDescription"]) {
        NSLog(@"为适配iOS10 请在info.plist文件中加入\n\"NSCameraUsageDescription\"字段");
    }
    [PermissionTool userPermission:AVMediaTypeVideo result:^(NSInteger authStatus) {
        [PermissionTool returnMainThread:^{
            block(authStatus);
        }];
    }];
}
/**
 *  获取访问麦克风权限(模拟器上无法测试)
 */
#pragma mark 麦克风
+ (void)getMicrophonePermission:(void (^)(NSInteger authStatus))block {
    NSDictionary *infoDict =[[NSBundle mainBundle] infoDictionary];
    if (!infoDict[@"NSMicrophoneUsageDescription"]) {
        NSLog(@"为适配iOS10 请在info.plist文件中加入\n\"NSMicrophoneUsageDescription\"字段");
    }
    [PermissionTool userPermission:AVMediaTypeAudio result:^(NSInteger authStatus) {
        [PermissionTool returnMainThread:^{
            block(authStatus);
        }];
    }];
}

/**
 *  打开"设置"->"允许权限访问"页
 */
#pragma mark "设置"->"允许权限访问"
+ (void)openSettingPermission {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:^(BOOL success) {
        
    }];
#else
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
#endif
    
    
}

/**
 *  获取位置权限
 */
#pragma mark 位置
+ (void)getLocationPermission:(BOOL)isAlwaysUse result:(AuthStatus)block {
    BOOL isLocation = [CLLocationManager locationServicesEnabled];
    if (!isLocation) {
        block(2);
        return;
    }
    NSDictionary *infoDict =[[NSBundle mainBundle] infoDictionary];
    if (isAlwaysUse &&!infoDict[@"NSLocationAlwaysUsageDescription"]) {
        NSLog(@"请在info.plist文件中加入\n\"NSLocationAlwaysUsageDescription\"字段");
    }
    if (!isAlwaysUse &&!infoDict[@"NSLocationWhenInUseUsageDescription"]) {
        NSLog(@"请在info.plist文件中加入\n\"NSLocationWhenInUseUsageDescription\"字段");
    }
    CLAuthorizationStatus CLstatus = [CLLocationManager authorizationStatus];
    switch (CLstatus) {
        case kCLAuthorizationStatusAuthorizedAlways: {
            [PermissionTool returnMainThread:^{
                block(3);
            }];
        } break;
        case kCLAuthorizationStatusAuthorizedWhenInUse: {
            [PermissionTool returnMainThread:^{
                block(3);
            }];
        } break;
        case kCLAuthorizationStatusDenied: {
            [PermissionTool returnMainThread:^{
                block(2);
            }];
        } break;
        case kCLAuthorizationStatusNotDetermined: {
            static CLLocationManager *manager;
            manager =[[CLLocationManager alloc] init];
            [PermissionTool shareUserInfo].statusBlock =block;
            if (isAlwaysUse) {
                [manager requestAlwaysAuthorization];//一直获取定位信息
            } else {
                [manager requestWhenInUseAuthorization];//使用的时候获取定位信息
            }
            manager.delegate =[PermissionTool shareUserInfo];
            break;
        }
        case kCLAuthorizationStatusRestricted: {
            [PermissionTool returnMainThread:^{
                block(1);
            }];
        } break;
        default:
            [PermissionTool returnMainThread:^{
                block(0);
            }];
            break;
    }
}
//定位代理
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways: {
            [PermissionTool returnMainThread:^{
                self.statusBlock(3);
            }];
        } break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:{
            [PermissionTool returnMainThread:^{
                self.statusBlock(3);
            }];
        } break;
        case kCLAuthorizationStatusDenied: {
            [PermissionTool returnMainThread:^{
                self.statusBlock(2);
            }];
        } break;
        case kCLAuthorizationStatusNotDetermined:
            break;
        case kCLAuthorizationStatusRestricted: {
            [PermissionTool returnMainThread:^{
                self.statusBlock(1);
            }];
        } break;
        default:
            break;
    }
}
#pragma mark 通讯录
+ (void)getAddressBookPermission:(void (^)(NSInteger authStatus))block {
    NSDictionary *infoDict =[[NSBundle mainBundle] infoDictionary];
    if (!infoDict[@"NSContactsUsageDescription"]) {
        NSLog(@"为适配iOS10 请在info.plist文件中加入\n\"NSContactsUsageDescription\"字段");
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    switch (status) {
        case CNAuthorizationStatusNotDetermined: {
            static CNContactStore *contactStore;
            contactStore =[[CNContactStore alloc]init];
            [contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                [PermissionTool returnMainThread:^{
                    if (granted) {
                        block(3);
                    } else {
                        block(2);
                    }
                }];
            }];
            break;
        }
        case CNAuthorizationStatusRestricted: {
            [PermissionTool returnMainThread:^{
                block(1);
            }];
        } break;
        case CNAuthorizationStatusDenied: {
            [PermissionTool returnMainThread:^{
                block(2);
            }];
        } break;
        case CNAuthorizationStatusAuthorized: {
            [PermissionTool returnMainThread:^{
                block(3);
            }];
        } break;
        default:
            [PermissionTool returnMainThread:^{
                block(0);
            }];
            break;
    }
#else
    ABAuthorizationStatus ABstatus = ABAddressBookGetAuthorizationStatus();
    switch (ABstatus) {
        case kABAuthorizationStatusAuthorized: {
            [PermissionTool returnMainThread:^{
                block(1);
            }];
        } break;
        case kABAuthorizationStatusDenied: {
            [PermissionTool returnMainThread:^{
                block(3);
            }];
        } break;
        case kABAuthorizationStatusNotDetermined: {
            ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
            ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
                [PermissionTool returnMainThread:^{
                    if (granted) {
                        block(1);
                    } else {
                        block(3);
                    }
                }];
                
                CFRelease(addressBook);
            });
            break;
        }
        case kABAuthorizationStatusRestricted: {
            [PermissionTool returnMainThread:^{
                block(3);
            }];
        } break;
        default:
            break;
    }
#endif
}
/**
 *  日历/备忘录权限
 */
+ (void)entityPermission:(EKEntityType)entityType result:(void (^)(NSInteger authStatus))block {
    
    EKAuthorizationStatus status = [EKEventStore  authorizationStatusForEntityType:entityType];
    switch (status) {
        case EKAuthorizationStatusAuthorized: {
            [PermissionTool returnMainThread:^{
                block(3);
            }];
        } break;
        case EKAuthorizationStatusDenied: {
            [PermissionTool returnMainThread:^{
                block(2);
            }];
        } break;
        case EKAuthorizationStatusNotDetermined: {
            EKEventStore *store = [[EKEventStore alloc]init];
            [store requestAccessToEntityType:entityType completion:^(BOOL granted, NSError * _Nullable error) {
                [PermissionTool returnMainThread:^{
                    if (granted) {
                        block(3);
                    } else {
                        block(2);
                    }
                }];
            }];
            break;
        }
        case EKAuthorizationStatusRestricted: {
            [PermissionTool returnMainThread:^{
                block(1);
            }];
        } break;
        default:
            [PermissionTool returnMainThread:^{
                block(0);
            }];
            break;
    }
}
//获取日历权限
+(void)getEventPermission:(void (^)(NSInteger authStatus))block {
    NSDictionary *infoDict =[[NSBundle mainBundle] infoDictionary];
    if (!infoDict[@"NSCalendarsUsageDescription"]) {
        NSLog(@"为适配iOS10 请在info.plist文件中加入\n\"NSCalendarsUsageDescription\"字段");
    }
    [PermissionTool entityPermission:EKEntityTypeEvent result:^(NSInteger authStatus) {
        [PermissionTool returnMainThread:^{
            block(authStatus);
        }];
    }];
}

//获取备忘录权限
+(void)getReminderPermission:(void (^)(NSInteger authStatus))block {
    NSDictionary *infoDict =[[NSBundle mainBundle] infoDictionary];
    if (!infoDict[@"NSRemindersUsageDescription"]) {
        NSLog(@"为适配iOS10 请在info.plist文件中加入\n\"NSRemindersUsageDescription\"字段");
    }
    [PermissionTool entityPermission:EKEntityTypeReminder result:^(NSInteger authStatus) {
        [PermissionTool returnMainThread:^{
            block(authStatus);
        }];
    }];
}

@end

