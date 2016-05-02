//
//  UIColor+Hex.h
//

#import <UIKit/UIKit.h>

@interface UIColor (Hex) 

+ (UIColor*) colorWithCSS: (NSString*) css;
+ (UIColor*) colorWithHex: (NSUInteger) hex;

- (uint)hex;
- (NSString*)hexString;
- (NSString*)cssString;

@end
