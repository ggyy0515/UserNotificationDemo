//
//  NotificationService.m
//  ServiceExtension
//
//  Created by Hong on 16/9/30.
//  Copyright © 2016年 Hong. All rights reserved.
//

#import "NotificationService.h"
#import <UIKit/UIKit.h>

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

/*
 
 {
 "aps": {
 "alert": "Testing.. (34)",
 "badge": 1,
 "sound": "default",
 "mutable-content": 1
 },
 "attUrl": "http://img1.gtimg.com/sports/pics/hv1/194/44/2136/138904814.jpg",
 "alertTitle": "标题"
 }
 
 注：发送推送信息时必须要加"mutable-content"这个妈卖批
 
 视频测试地址:http://baobab.wdjcdn.com/1455969783448_5560_854x480.mp4
 gif测试地址:https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=2543917993,526494728&fm=23&gp=0.jpg
 jpg测试地址:http://img1.gtimg.com/sports/pics/hv1/194/44/2136/138904814.jpg
 */

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    NSLog(@"sandbox service extension : %@", NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject);
    
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    // Modify the notification content here...
    self.bestAttemptContent.title = [NSString stringWithFormat:@"%@ [modified]", self.bestAttemptContent.title];
    
    NSDictionary * userInfo = request.content.userInfo;
    
    NSURL *url = [NSURL URLWithString:[userInfo objectForKey:@"attUrl"]];
    __weak NSURL *weakUrl = url;
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    if (url) {
        NSURLRequest * urlRequest = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5];
        //注意使用DownloadTask，这点会详细说明
        /*
         WWDC2016上的俄罗斯口音小伙上台讲Notification Service Extension的时候，明确提到了”You will get a short execution time, which means this is not for long background running tasks.“，但实际测试过程中，Notification Service Extension非常容易崩溃crash和内存溢出out of memory。
         
         更加坑的是debug运行的时候和真机运行的时候，Notification Service Extension性能表现是不一样的，真机运行的时候Notification Service Extension非常容易不起作用，我做了几次实验，图片稍大，Notification Service Extension就崩溃了不起作用了，而相同的debug调试环境下则没问题，我觉得他应该也提提这个，比如说你下载资源的时候最好分段缓存下载，真机环境下NSURLSessionDataTask下载数据不好使，必须使用NSURLSessionDownloadTask才可以，这点很无奈。
         
         */
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:urlRequest completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!error) {
                NSString *fileExt = [[weakUrl absoluteString] pathExtension];
                NSString *path = [location.path stringByAppendingString:[NSString stringWithFormat:@".%@",fileExt]];
                NSError *err = nil;
                NSURL * pathUrl = [NSURL fileURLWithPath:path];
                [[NSFileManager defaultManager] moveItemAtURL:location toURL:pathUrl error:nil];
                //下载完毕生成附件，添加到内容中
                UNNotificationAttachment *resource_attachment = [UNNotificationAttachment attachmentWithIdentifier:@"attachment" URL:pathUrl options:nil error:&err];
                if (resource_attachment) {
                    self.bestAttemptContent.attachments = @[resource_attachment];
                }
                if (error) {
                    NSLog(@"%@", error);
                }
                //设置为@""以后，进入app将没有启动页
                self.bestAttemptContent.launchImageName = @"";
                UNNotificationSound *sound = [UNNotificationSound defaultSound];
                self.bestAttemptContent.sound = sound;
                //回调给系统
                self.contentHandler(self.bestAttemptContent);
            }
            else{
                self.contentHandler(self.bestAttemptContent);
            }
        }];
        [task resume];
    } else {
         self.contentHandler(self.bestAttemptContent);
    }
    
    
    
    
#if 0
    
    
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"download attachment image error : %@", error);
        }else{
            NSString *path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject
                               stringByAppendingPathComponent:@"download"];
            NSFileManager *manager = [NSFileManager defaultManager];
            if (![manager fileExistsAtPath:path]) {
                [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
            }
            NSString *fileExt = [[weakUrl absoluteString] pathExtension];
            NSString *fileName = [NSString stringWithFormat:@"%lld.%@", (long long)[[NSDate date] timeIntervalSince1970] * 1000, fileExt];
            path = [path stringByAppendingPathComponent:fileName];
//            UIImage *image = [UIImage imageWithData:data];
            NSLog(@"path------- : %@", path);
            
            NSError *err = nil;
            [data writeToFile:path options:NSAtomicWrite error:&err];
//            [UIImageJPEGRepresentation(image, 1) writeToFile:path options:NSAtomicWrite error:&err];
            
            UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"remote-atta1" URL:[NSURL fileURLWithPath:path] options:nil error:&err];
            if (attachment) {
                self.bestAttemptContent.attachments = @[attachment];
            }
        }
        
        self.contentHandler(self.bestAttemptContent);
    }];
    
    [task resume];
#endif
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    self.contentHandler(self.bestAttemptContent);
}

@end
