//
//  ViewController.m
//  ThreadTest
//
//  Created by PTX on 10/05/2018.
//  Copyright © 2018 PTX. All rights reserved.
//

#import "ViewController.h"

static NSInteger totalBread = 100; //面包总数
static NSInteger breadPool = 10; //面包池

@interface ViewController () {
    NSLock *lock;
    NSCondition *condition;
    
    dispatch_semaphore_t semaphore;
    NSInteger produceNum; //当前做的面包数
    NSInteger consumeNum; //吃完的面包数
    
    BOOL produceWait;
    BOOL consumeWait;
}


@property (nonatomic, assign) NSInteger test; //实践证明atomic并不能保存线程安全

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //    [self threadSyn];
    
    //    [self producerAndConsumer];
    
    //    NSMutableArray *testArray = [NSMutableArray array];
    //    NSCondition *con = [[NSCondition alloc] init];
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //        while (1) {
    //            [con lock];
    //            if (testArray.count == 0) {
    //                NSLog(@"wait to add obj!");
    //                [con wait];
    //            }
    //            [testArray removeObjectAtIndex:0];
    //            NSLog(@"consume a obj!");
    //            [con unlock];
    //        }
    //    });
    //
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //        while (1) {
    //            [con lock];
    //            [testArray addObject:[[NSObject alloc]init]];
    //            NSLog(@"product a obj!");
    //            [con signal];
    //            [con unlock];
    //            sleep(1);
    //        }
    //
    //    });
    
    
    //    NSThread *test = [[NSThread alloc] initWithTarget:self selector:@selector(testThread) object:nil];
    //    [test start];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    //    queue.maxConcurrentOperationCount = 1;
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"%@", [NSThread currentThread]);
    }];
    for (NSInteger i = 0; i < 5; i++) {
        [operation addExecutionBlock:^{
            NSLog(@"第%ld次%@", i, [NSThread currentThread]);
        }];
    }
    [queue addOperationWithBlock:^{
        NSLog(@"123");
    }];
    [queue addOperation:operation];
}

- (void)testThread {
    [self performSelector:@selector(testCallBack) withObject:nil afterDelay:3];
    [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];
    NSLog(@"runloop结束");
    
}
- (void)testCallBack {
    //...
}

#pragma mark - 生产者与消费者
- (void)producerAndConsumer {
    //信号量为负数的时候，对当前线程进行阻塞，我们这里设置为1，是提供给两个线程操作的时候，放第一个线程去工作，阻塞第二个线程。
    //    semaphore = dispatch_semaphore_create(1);
    semaphore = dispatch_semaphore_create(0);
    
    NSThread *mom = [[NSThread alloc] initWithTarget:self selector:@selector(produce) object:nil];
    [mom setName:@"妈妈"];
    [mom start];
    
    NSThread *son1 = [[NSThread alloc] initWithTarget:self selector:@selector(consume) object:nil];
    [son1 setName:@"小明"];
    [son1 start];
    
    NSThread *son2 = [[NSThread alloc] initWithTarget:self selector:@selector(consume) object:nil];
    [son2 setName:@"小红"];
    [son2 start];
}

- (void)produce {
    while (totalBread > 0) {
        if (produceNum < breadPool) {
            produceWait = NO;
            totalBread--;
            produceNum++;
            NSLog(@"妈妈做出了第%ld个面包",100 - totalBread);
            
            //唤醒吃面包线程
            if (consumeWait) {
                NSLog(@"唤醒儿子吃面包");
                dispatch_semaphore_signal(semaphore);
            }
            
        }else {
            NSLog(@"面包做的太多了，%@等待儿子吃面包。。。", [[NSThread currentThread] name]);
            //面包池已满，等待儿子吃面包
            produceWait = YES;
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
    }
    NSLog(@"今天的面包已做完");
    
    //    for (NSInteger i = 0; i < 1000; i++) {
    //        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //        self.test++;
    //        NSLog(@"%@ , %ld", [NSThread currentThread],self.test);
    //        dispatch_semaphore_signal(semaphore);
    //    }
}

- (void)consume {
    while (totalBread > 0 || produceNum > 0) {
        [lock lock];
        if (produceNum > 0) {
            consumeWait = NO;
            consumeNum++;
            produceNum--;
            NSLog(@"儿子吃了第%ld个面包", consumeNum);
            
            //唤醒做面包线程
            if (produceWait) {
                NSLog(@"唤醒妈妈吃面包");
                dispatch_semaphore_signal(semaphore);
            }
            
        }else {
            NSLog(@"做的面包吃完了，儿子等待妈妈做面包。。。");
            //面包池已空，等待妈妈做面包
            consumeWait = YES;
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
        [lock unlock];
    }
    NSLog(@"今天的面包已吃完");
    
    //    for (NSInteger i = 0; i < 1000; i++) {
    //        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //        self.test++;
    //        NSLog(@"%@ , %ld", [NSThread currentThread],self.test);
    //        dispatch_semaphore_signal(semaphore);
    //    }
}

#pragma mark - 线程同步
- (void)threadSyn {
    self.test = 0;
    condition = [[NSCondition alloc] init];
    lock = [[NSLock alloc] init];
    for (NSInteger i = 0; i < 1000; i++) {
        [NSThread detachNewThreadSelector:@selector(add) toTarget:self withObject:nil];
    }
}

- (void)add {
    //1
    [lock lock];
    self.test++;
    NSLog(@"%@ , %ld", [NSThread currentThread],self.test);
    [lock unlock];
    
    //2
    //    @synchronized(self){
    //        self.test++;
    //        NSLog(@"%@ , %ld", [NSThread currentThread],self.test);
    //    }
    
    //3
    //    [condition lock];
    //    self.test++;
    //    NSLog(@"%@ , %ld", [NSThread currentThread],self.test);
    //    [condition unlock];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

