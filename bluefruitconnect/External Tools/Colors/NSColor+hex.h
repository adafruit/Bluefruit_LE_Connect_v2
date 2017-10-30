// Based on https://developer.apple.com/library/mac/qa/qa1576/_index.html
#import <Cocoa/Cocoa.h>

@interface NSColor (hex)

- (NSString *)hexString;
+ (NSColor *)colorWithCSS:(NSString *)hex;

@end