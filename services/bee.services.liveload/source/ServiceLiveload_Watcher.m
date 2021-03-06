//
//  ServiceLiveload_Watcher.m
//  dribbble
//
//  Created by QFish on 2/10/14.
//  Copyright (c) 2014 geek-zoo studio. All rights reserved.
//

#if (TARGET_IPHONE_SIMULATOR)

#import "ServiceLiveload_Watcher.h"
#import "ServiceLiveload_Category.h"

static NSMutableDictionary * __watcherMap = nil;

@implementation ServiceLiveload_Watcher

DEF_SINGLETON( ServiceLiveload_Watcher );

+ (void)setWatcher:(id)watcher forPath:(NSString *)path
{
    if ( __watcherMap == nil )
    {
        __watcherMap = [[NSMutableDictionary alloc] init];
    }
    
    NSMutableArray * watchers = __watcherMap[path];
    
    if ( watchers )
    {
        if ( ![watchers containsObject:watcher] )
        {
            [watchers addObject:watcher];
        }
    }
    else
    {
        watchers = [NSMutableArray nonRetainingArray];
        [watchers addObject:watcher];
        [__watcherMap setValue:watchers forKey:path];
        
        [self watchForChangesToFilePath:path withCallback:^{

            NSArray * thisWatchers = __watcherMap[path];
            
            for ( NSObject * obj in thisWatchers )
            {
                [obj __liveReloadWithObject:path];
            }
        }];
    }
}

+ (void)removeWatcher:(id)watcher forPath:(NSString *)path
{
    NSMutableArray * watchers = __watcherMap[path];

    if ( [watchers containsObject:watcher] )
    {
        [watchers removeObject:watcher];
    }
}

#pragma mark - file watcher

+ (void)watchForChangesToFilePath:(NSString *)filePath
                     withCallback:(dispatch_block_t)callback
{
    dispatch_queue_t queue =
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    int fileDescriptor = open([filePath UTF8String], O_EVTONLY);
	
    NSAssert(fileDescriptor > 0, @"Error could subscribe to events \
             for file at path: %@", filePath);
	
    __block dispatch_source_t source =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                               fileDescriptor,
                               DISPATCH_VNODE_DELETE |
                               DISPATCH_VNODE_WRITE |
                               DISPATCH_VNODE_EXTEND,
                               queue);
    
    dispatch_source_set_event_handler(source, ^{
        unsigned long flags = dispatch_source_get_data(source);
        if (flags) {
            dispatch_source_cancel(source);
            dispatch_async(dispatch_get_main_queue(), ^{
                callback();
            });
            
            double delayInSeconds = 0.5f;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, queue, ^(void){
                [self watchForChangesToFilePath:filePath withCallback:callback];
            });
        }
    });
    
    dispatch_source_set_cancel_handler(source, ^(void){
        close(fileDescriptor);
    });
    
    dispatch_resume(source);
}

@end

#endif  // #if (TARGET_IPHONE_SIMULATOR)
