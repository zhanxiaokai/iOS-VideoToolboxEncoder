//
//  ViewController.m
//  VideoToolboxEncoder
//
//  Created by apple on 2017/2/23.
//  Copyright © 2017年 xiaokai.zhan. All rights reserved.
//

#import "ViewController.h"
#import "ELPushStreamViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)forward:(id)sender {
    NSLog(@"forward To Preview...");
    ELPushStreamViewController* viewController = [[ELPushStreamViewController alloc] init];
    [[self navigationController] pushViewController:viewController animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
