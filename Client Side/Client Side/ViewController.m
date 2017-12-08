//
//  ViewController.m
//  Client Side
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
@property (weak) IBOutlet NSTextField *ipField;
@property (weak) IBOutlet NSTextField *portField;
@property (weak) IBOutlet NSTextField *msgField;
@property (weak) IBOutlet NSTextField *replyField;
@property (weak) IBOutlet NSTextField *appLayer;
@property (weak) IBOutlet NSTextField *transLayer;
@property (weak) IBOutlet NSTextField *networkLayer;
@property (weak) IBOutlet NSTextField *dlinkLayer;
@property (weak) IBOutlet NSTextField *phyLayer;
// 按钮
@property (weak) IBOutlet NSButton *connectButton;
@property (weak) IBOutlet NSButton *sendButton;
// 标签
@property (weak) IBOutlet NSTextField *msgLabel;
// 连接属性
@property (nonatomic, assign) int server_socket;
@property (nonatomic, assign) short port_num;

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
    self.msgField.selectable = NO;
    self.msgField.placeholderString = @"请先连接主机";
    
    self.replyField.editable = NO;
    
    self.sendButton.enabled = NO;
}

- (void)didConnected {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.msgField.editable = YES;
        self.msgField.selectable = YES;
        self.msgField.stringValue = @"";
        
        self.sendButton.enabled = YES;
    });
}

#pragma mark - 私有API

- (IBAction)connectButtonClicked:(id)sender {
    NSString *portStr = [self.portField stringValue];
    // 开启子线程，连接服务端
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self bindSocketWithIP:[self.ipField.stringValue copy] andPort:[portStr integerValue]];
    });
}

- (IBAction)sendButtonClicked:(id)sender {
    // 开启子线程，发送并接收消息
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self sendMsgAction];
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

- (NSString *)intToBinary:(int)intValue{
    int byteBlock = 8;            // 8 bits per byte
    int totalBits = (sizeof(int)) * byteBlock; // Total bits
    int binaryDigit = totalBits; // Which digit are we processing   // C array - storage plus one for null
    char ndigit[totalBits + 1];
    while (binaryDigit-- > 0) {
        // Set digit in array based on rightmost bit
        ndigit[binaryDigit] = (intValue & 1) ? '1' : '0';
        // Shift incoming value one to right
        intValue >>= 1;
    }   // Append null
    ndigit[totalBits] = 0;
    // Return the binary string
    return [NSString stringWithUTF8String:ndigit];
}

- (void)sendMsgAction {
    NSMutableString *msg = [NSMutableString stringWithFormat:@"%@",self.msgField.stringValue];
    
    char recv_msg[RECV_BUFFER_SIZE];
    char send_msg[REPLY_BUFFER_SIZE];
    // 发送消息，并接收服务器回信
    // 收到消息后，于主线程回调更新UI
    bzero(recv_msg, RECV_BUFFER_SIZE);
    bzero(send_msg, REPLY_BUFFER_SIZE);
    
    // 清除现有消息
    [self clearCurrentMsg];
    
    // 向服务端通过socket发消息
    NSMutableString *resStr = [self appLayerWithString:msg];
    strcpy(send_msg, resStr.UTF8String);
    long send_result = send(self.server_socket, send_msg, REPLY_BUFFER_SIZE, 0);
    if (send_result == -1) {
        [self showMessageWithMsg:@"消息发送失败"];
        return;
    }
    else {
        [self showMessageWithMsg:@"消息发送成功"];
        [NSThread sleepForTimeInterval:0.3];
    }
    
    // 接收服务端消息
    long recv_result = recv(self.server_socket, recv_msg, RECV_BUFFER_SIZE, 0);
    [self reciveFromServer:[NSString stringWithUTF8String:recv_msg]];
    
}

- (void)bindSocketWithIP:(NSString *)ipStr andPort:(NSInteger)port {
    
    // 创建Socket地址
    struct sockaddr_in server_addr;                                      // 创建Socket地址
    server_addr.sin_len = sizeof(struct sockaddr_in);                    // 设置结构体长度
    server_addr.sin_family = AF_INET;                                    // AF_INET地址簇
    server_addr.sin_port = htons((short)port);                           // 设置端口
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);                     // 服务器地址
    
    // 创建Socket
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket == -1) {
        [self showMessageWithMsg:@"创建Socket失败"];
        return;
    }
    else {
        // 保存Socket
        self.server_socket = server_socket;
        // 保存port
        self.port_num = (short)port;
        [self showMessageWithMsg:@"创建Socket成功"];
        [NSThread sleepForTimeInterval:0.3];
    }
    
    int connect_result = connect(server_socket, (struct sockaddr *)&server_addr, sizeof(struct sockaddr_in));
    if (connect_result == -1) {
        [self showMessageWithMsg:@"连接主机失败"];
        return;
    }
    else {
        [self showMessageWithMsg:@"连接主机成功,等待发送消息..."];
        [NSThread sleepForTimeInterval:0.3];
    }
    
    // 连接成功后的操作
    [self didConnected];
}

- (void)showMessageWithMsg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.msgLabel setStringValue:[msg copy]];
    });
}

- (void)reciveFromServer:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.replyField.stringValue = [msg copy];
    });
}

#pragma mark - 五层传输协议
// 模拟网络层对数据的包装
- (NSMutableString *)appLayerWithString:(NSMutableString *)str {
    NSMutableString *resStr = [NSMutableString stringWithFormat:@"AppHeader#%@", str];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.appLayer.stringValue = [resStr copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return [self transferLayerWithString:resStr];
}

// 模拟传输层对数据的包装
- (NSMutableString *)transferLayerWithString:(NSMutableString *)str {
    NSMutableString *resStr = [NSMutableString string];
    // 添加源端口 16位(0-15)
    [resStr appendFormat:@"0000000011111111"];
    // 添加目的端口 16位(16-31)
    [resStr appendFormat:@"%@", [self intToBinary:self.port_num]];
    // 添加序列编号 32位
    [resStr appendFormat:@"00000000000000000000000000001011"];
    // 添加确认帧 32位
    [resStr appendFormat:@"00000000000000000000000011111011"];
    // 添加报头长度
    [resStr appendFormat:@"0101"];
    // 添加保留长度
    [resStr appendFormat:@"000000"];
    // 添加FLag
    [resStr appendFormat:@"000000"];
    // 添加窗口大小
    [resStr appendFormat:@"0000000000000111"];
    // 添加确认值
    [resStr appendFormat:@"0101010101010010"];
    // 添加UrgentPointer
    [resStr appendFormat:@"0000000000001111"];
    // 添加Header结尾
    [resStr appendFormat:@"#%@", str];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.transLayer.stringValue = [resStr copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return [self networkLayerWith:resStr];
}

// 模拟网络层对数据的包装
- (NSMutableString *)networkLayerWith:(NSMutableString *)str {
    NSMutableString *resStr = [NSMutableString string];
    
    // 添加VER
    [resStr appendFormat:@"0100"];
    // 添加HLEN
    [resStr appendFormat:@"1111"];
    // 添加Service
    [resStr appendFormat:@"00000000"];
    // 添加totalLength
    [resStr appendFormat:@"0101010101010101"];
    // 添加Identification
    [resStr appendFormat:@"0000000000000000"];
    // 添加Flag
    [resStr appendFormat:@"000"];
    // 添加FragmentationOffset
    [resStr appendFormat:@"0000000000000"];
    // 添加TTL
    [resStr appendFormat:@"00000000"];
    // 添加Protocol
    [resStr appendFormat:@"00000000"];
    // 添加HeaderChecksum
    [resStr appendFormat:@"0000000000000000"];
    // 添加SourIPAddress
    [resStr appendFormat:@"00000000000000000000000000000000"];
    // 添加DestinationIPAddress
    [resStr appendFormat:@"00000000000000000000000000000000"];
    
    // 添加Header结尾
    [resStr appendFormat:@"#%@", str];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.networkLayer.stringValue = [resStr copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return [self dlinkLayerWithString:resStr];
}

// 模拟链路层对数据的包装
- (NSMutableString *)dlinkLayerWithString:(NSMutableString *)str {
    NSMutableString *resStr1 = [NSMutableString string];
    // 添加FrameFlag1
    [resStr1 appendFormat:@"00001111"];
    // 添加FrameAdd
    [resStr1 appendFormat:@"11101011"];
    // 添加FrameControl
    [resStr1 appendFormat:@"01111000"];
    
    NSMutableString *resStr2 = [NSMutableString string];
    // 添加FrameFCS
    [resStr2 appendFormat:@"00001111"];
    // 添加FrameFlag2
    [resStr2 appendFormat:@"11101011"];
    
    // 合成帧
    NSMutableString *resStr = [NSMutableString stringWithFormat:@"%@#%@#%@", resStr1, str, resStr2];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dlinkLayer.stringValue = [resStr copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return [self phyLayerWithString:resStr];
}

- (NSMutableString *)phyLayerWithString:(NSMutableString *)str {
    NSMutableString *resStr = [NSMutableString stringWithFormat:@"PhysicsHeader#%@", str];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.phyLayer.stringValue = [resStr copy];
    });
    
    [NSThread sleepForTimeInterval:0.3];
    
    return resStr;
}

@end
