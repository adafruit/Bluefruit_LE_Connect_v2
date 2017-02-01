//
//  NSObject+ENHThrottledReloading.h
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

#import <UIKit/UIKit.h>

@protocol ENHThrottledReloading <NSObject>

-(void)reloadData;

@end

@interface NSObject (ENHThrottledReloading)

/**
 *  Schedules a throttled call to `reloadData` so that multiple calls may be aggregated.
 */
-(void)enh_throttledReloadData;

/**
 *  Cancels any pending throttled call to `reloadData`. 
 *  Typically called in `dealloc` implementation of the class that initiates the throttled calls.
 */
-(void)enh_cancelPendingReload;

/**
 *  Minimum number of nanoseconds between reloading data. Defaults to 0.3 seconds.
 */
@property (nonatomic, assign) uint64_t enh_minimumNanosecondsBetweenThrottledReloads;

@end

@interface UICollectionView (ENHThrottledReloading) <ENHThrottledReloading>

@end

@interface UITableView (ENHThrottledReloading) <ENHThrottledReloading>

@end