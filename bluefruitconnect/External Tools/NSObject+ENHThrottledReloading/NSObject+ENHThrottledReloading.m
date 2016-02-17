//
//  NSObject+ENHThrottledReloading.m
//
//  Created by Dillan Laughlin on 2/18/15.
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Enharmonic Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "NSObject+ENHThrottledReloading.h"
#import <mach/mach_time.h>
#import <objc/runtime.h>

static NSString *kENHTimebaseInfoAssociatedObjectKey = @"com.enharmonichq.timebaseInfo";
static NSString *kENHLastReloadMachTimeAssociatedObjectKey = @"com.enharmonichq.lastReloadMachTime";
static NSString *kENHAwaitingReloadAssociatedObjectKey = @"com.enharmonichq.awaitingReload";
static NSString *kENHMinimumNanosecondsBetweenThrottledReloadsAssociatedObjectKey = @"com.enharmonichq.minimumNanosecondsBetweenThrottledReloads";

@interface NSObject ()

/**
 *  The last mach time when a throttled reload occured.
 */
@property (nonatomic, assign) uint64_t enh_lastReloadMachTime;

/**
 *  Bool indicating wheather a throttled reload is currently pending.
 */
@property (nonatomic, assign) BOOL enh_awaitingReload;

@end

@implementation NSObject (ENHThrottledReloading)

-(void)enh_throttledReloadData
{
    uint64_t now = mach_absolute_time ();
    uint64_t lastReloadMachTime = [self enh_lastReloadMachTime];
    uint64_t timeSinceLastUpdate = now - lastReloadMachTime;
    mach_timebase_info_data_t timebaseInfo = [self enh_timebaseInfo];
    uint64_t nanos = timeSinceLastUpdate * timebaseInfo.numer / timebaseInfo.denom;
    uint64_t minimumTimeDiffNanosecondsForUpdate = [self enh_minimumNanosecondsBetweenThrottledReloads];
    BOOL awaitingReload = [self enh_awaitingReload];
    
    if(nanos > minimumTimeDiffNanosecondsForUpdate || lastReloadMachTime == 0.0)
    {
        [self setEnh_lastReloadMachTime:now];
        [self setEnh_awaitingReload:NO];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];
        if ([self respondsToSelector:@selector(reloadData)])
        {
            [self performSelector:@selector(reloadData)];
        }
        else
        {
            NSAssert(NO, @"object does not respond to reloadData selector");
        }
    }
    else if (!awaitingReload)
    {
        NSTimeInterval delay = ((double)minimumTimeDiffNanosecondsForUpdate - nanos) / NSEC_PER_SEC;
        [self performSelector:_cmd withObject:nil afterDelay:delay];
        [self setEnh_awaitingReload:YES];
    }
}

-(void)enh_cancelPendingReload
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(enh_throttledReloadData) object:nil];
}

#pragma mark - Accessors

-(void)setEnh_minimumNanosecondsBetweenThrottledReloads:(uint64_t)enh_minimumNanosecondsBetweenThrottledReloads
{
    objc_setAssociatedObject(self, (__bridge const void *)kENHMinimumNanosecondsBetweenThrottledReloadsAssociatedObjectKey, @(enh_minimumNanosecondsBetweenThrottledReloads), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(uint64_t)enh_minimumNanosecondsBetweenThrottledReloads
{
    uint64_t minimumNanosecondsBetweenThrottledReloads = NSEC_PER_SEC * 0.3; // 0.3 seconds
    NSNumber *value = objc_getAssociatedObject(self, (__bridge const void *)kENHMinimumNanosecondsBetweenThrottledReloadsAssociatedObjectKey);
    if (value)
    {
        minimumNanosecondsBetweenThrottledReloads = [value unsignedLongLongValue];
    }
    
    return minimumNanosecondsBetweenThrottledReloads;
}

-(mach_timebase_info_data_t)enh_timebaseInfo
{
    mach_timebase_info_data_t timebaseInfo;
    
    NSValue *value = objc_getAssociatedObject(self, (__bridge const void *)kENHTimebaseInfoAssociatedObjectKey);
    if (!value)
    {
        if(mach_timebase_info(&timebaseInfo) != KERN_SUCCESS)
        {
            NSAssert(0, @"mach_timebase_info not successful");
        }
        value = [NSValue value:&timebaseInfo withObjCType:@encode(mach_timebase_info_data_t)];
        objc_setAssociatedObject(self, (__bridge const void *)kENHTimebaseInfoAssociatedObjectKey, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    else
    {
        [value getValue:&timebaseInfo];
    }
    
    return timebaseInfo;
}

-(void)setEnh_lastReloadMachTime:(uint64_t)enh_lastReloadMachTime
{
    objc_setAssociatedObject(self, (__bridge const void *)kENHLastReloadMachTimeAssociatedObjectKey, @(enh_lastReloadMachTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(uint64_t)enh_lastReloadMachTime
{
    NSNumber *value = objc_getAssociatedObject(self, (__bridge const void *)kENHLastReloadMachTimeAssociatedObjectKey);
    uint64_t lastReloadMachTime = [value unsignedLongLongValue];
    
    return lastReloadMachTime;
}

-(void)setEnh_awaitingReload:(BOOL)enh_awaitingReload
{
    objc_setAssociatedObject(self, (__bridge const void *)kENHAwaitingReloadAssociatedObjectKey, @(enh_awaitingReload), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(BOOL)enh_awaitingReload
{
    NSNumber *value = objc_getAssociatedObject(self, (__bridge const void *)kENHAwaitingReloadAssociatedObjectKey);
    BOOL awaitingReload = [value boolValue];
    
    return awaitingReload;
}

@end
