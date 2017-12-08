//
//  ViewController.m
//  Service Side
//
//  Created by Minecode on 2017/12/6.
//  Copyright © 2017年 Minecode. All rights reserved.
//

#import "ViewController.h"

#import <sys/types.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <string.h>
#import <stdlib.h>
#import <fcntl.h>
#import <sys/shm.h>

#define RECV_BUFFER_SIZE 1024
#define REPLY_BUFFER_SIZE 1024


@interface ViewController ()

// 分割线
@property (weak) IBOutlet NSView *separatorLine1;
@property (weak) IBOutlet NSView *separatorLine2;
@property (weak) IBOutlet NSView *separatorLine3;
// 输入框
@property (weak) IBOutlet NSTextField *portField;
@property (weak) IBOutlet NSTextField *msgField;
@property (weak) IBOutlet NSTextField *appLayer;
@property (weak) IBOutlet NSTextField *transLayer;
@property (weak) IBOutlet NSTextField *networkLayer;
@property (weak) IBOutlet NSTextField *dlinkLayer;
@property (weak) IBOutlet NSTextField *phyLayer;
// 按钮
@property (weak) IBOutlet NSButton *bindButton;
// 标签
@property (weak) IBOutlet NSTextField *msgLabel;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupSeparatorLine];
    [self setupEnabled];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - 初始化方法
- (void)setupSeparatorLine {
    [self.separatorLine1 setWantsLayer:YES];
    [self.separatorLine1.layer setBackgroundColor:[[NSColor lightGrayColor] CGColor]];
    [self.separatorLine2 setWantsLayer:YES];
    [self.separatorLine2.layer setBackgroundColor:[[NSColor lightGrayColor] CGColor]];
    [self.separatorLine3 setWantsLayer:YES];
    [self.separatorLine3.layer setBackgroundColor:[[NSColor lightGrayColor] CGColor]];
}

// 设置控件开关
- (void)setupEnabled {
    self.msgField.editable = NO;
}

#pragma mark - 私有API
- (IBAction)bindButtonClicked:(id)sender {
    NSString *portStr = [self.portField stringValue];
    // 开启子线程，创建服务端
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self bindSocketWithPort:[portStr integerValue]];
    });
}

- (void)clearCurrentMsg {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.appLayer.stringValue = @"";
        self.transLayer.stringValue = @"";
        self.networkLayer.stringValue = @"";
        self.dlinkLayer.stringValue = @"";
        self.phyLayer.stringValue = @"";
    });
}

- (void)bindSocketWithPort:(NSInteger)port {
    // 创建Socket地址
    struct sockaddr_in server_addr;                             // socket地址
    server_addr.sin_len = sizeof(struct sockaddr_in);           // 设置地址结构体大小
    server_addr.sin_family = AF_INET;                           // AF_INET地址簇
    server_addr.sin_port = htons((short)port);                  // 设置端口
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);            // 服务器地址
    
    // 创建Socket
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);        // 创建Socket
    if (server_socket == -1) {
        [self showMessageWithMsg:@"创建Socket失败"];
        return;
    }
    else {
        [self showMessageWithMsg:@"创建Socket成功"];
        [NSThread sleepForTimeInterval:0.3];
    }
    
    int reuse = 1;
    int sockOpt = setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    if (sockOpt == -1) {
        [self showMessageWithMsg:@"重设Socket失败"];
        return;
    }
    
    // 绑定Socket
    // 将创建的Socket绑定到本地IP和端口,用于侦听客户端请求
    int bind_result = bind(server_socket, (struct sockaddr *)&server_addr, sizeof(server_addr));
    if (bind_result == -1) {
        [self showMessageWithMsg:@"绑定Socket失败"];
        return;
    }
    else {
        [self showMessageWithMsg:@"绑定Socket成功"];
        [NSThread sleepForTimeInterval:0.3];
    }
    
    // 侦听客户端消息
    if (listen(server_socket, 5) == -1) {
        [self showMessageWithMsg:@"开启侦听失败"];
        return;
    }
    else {
        [self showMessageWithMsg:@"开启侦听成功"];
        [NSThread sleepForTimeInterval:0.3];
        [self showMessageWithMsg:@"搜索客户端中..."];
    }
    
    // 获取客户端端口信息
    struct sockaddr_in client_address;
    socklen_t address_len;
    int client_socket = accept(server_socket, (struct sockaddr *)&client_address, &address_len);
    if (client_socket == -1) {
        [self showMessageWithMsg:@"客户端握手失败"];
        return;
    }
    else {
        [self showMessageWithMsg:@"客户端握手成功"];
        [NSThread sleepForTimeInterval:0.3];
    }
    
    [self showMessageWithMsg:@"侦听客户端消息中..."];
    
    char recv_msg[RECV_BUFFER_SIZE];
    char reply_msg[REPLY_BUFFER_SIZE];
    // 子线程开启循环持续检测客户端消息，避免阻塞主线程
    // 收到消息后，于主线程回调更新UI
    while (YES) {
        bzero(recv_msg, RECV_BUFFER_SIZE);
        bzero(reply_msg, REPLY_BUFFER_SIZE);
        
        // 设置服务器回复数据
        // 也可由用户自行输入，添加文本框即可
        
        long byteLen = recv(client_socket, recv_msg, RECV_BUFFER_SIZE, 0);
        recv_msg[byteLen] = '\0';                   // 添加消息结尾
        NSMutableString *msgStr = [NSMutableString stringWithFormat:@"%s", recv_msg];
        [self clearCurrentMsg];
        strcpy(recv_msg, [[self reciveFromClient:msgStr] UTF8String]);
        
        if (strcmp(recv_msg, "") != 0) {
            strcpy(reply_msg, "服务端消息:收到");
            strcat(reply_msg, recv_msg);
            send(client_socket, reply_msg, REPLY_BUFFER_SIZE, 0);
        }
    }
}

- (void)showMessageWithMsg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.msgLabel setStringValue:[msg copy]];
    });
}

- (NSMutableString *)reciveFromClient:(NSMutableString *)msg {
    NSMutableString *resStr = [self phyProcessWithString:[msg copy]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.msgField setStringValue:resStr];
    });
    
    return [resStr copy];
}

#pragma mark - 五层模型解包
- (NSMutableString *)phyProcessWithString:(NSMutableString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.phyLayer.stringValue = [str copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return [self dlinkLayerWithstring: [str substringFromIndex:14]];
}

- (NSMutableString *)dlinkLayerWithstring:(NSMutableString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dlinkLayer.stringValue = [str copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    NSMutableString *noPrefixString = [str substringFromIndex:25];
    NSMutableString *resStr = [noPrefixString substringWithRange:NSMakeRange(0, noPrefixString.length-17)];
    return [self networkLayerWithstring:resStr];
}

- (NSMutableString *)networkLayerWithstring:(NSMutableString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.networkLayer.stringValue = [str copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return [self transLayerWithstring:[str substringFromIndex:161]];
}

- (NSMutableString *)transLayerWithstring:(NSMutableString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.transLayer.stringValue = [str copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];

    return [self appLayerWithstring:[str substringFromIndex:177]];
}

- (NSMutableString *)appLayerWithstring:(NSMutableString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.appLayer.stringValue = [str copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return [str substringFromIndex:10];
}

@end
