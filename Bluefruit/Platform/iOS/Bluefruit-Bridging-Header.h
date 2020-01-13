//
//  Bluefruit-Bridging-Header.h
//  bluefruit
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

#ifndef Bluefruit_Bridging_Header_h
#define Bluefruit_Bridging_Header_h

#import "MSWeakTimer/MSWeakTimer.h"
#import "NSObject+ENHThrottledReloading.h"
#import "ISColorWheel.h"

#if TARGET_OS_MACCATALYST
    // ImageMagick libs are not compiled for macOS
#else
#import "ImageMagick.h"
#import "MagickWand.h"
#endif

#endif /* Bluefruit_Bridging_Header_h */
