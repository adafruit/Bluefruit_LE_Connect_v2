// Based on https://developer.apple.com/library/mac/qa/qa1576/_index.html
// Uses the same function names that UIColor+Hex Pod. Update all with a pod that supports UIColor/NSColor when available
#import "NSColor+hex.h"

@implementation NSColor (hex)

- (NSString *)hexString {
    
    CGFloat redFloatValue, greenFloatValue, blueFloatValue;
    int redIntValue, greenIntValue, blueIntValue;
    NSString *redHexValue, *greenHexValue, *blueHexValue;

    //Convert the NSColor to the RGB color space before we can access its components
    NSColor *convertedColor=[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

    if(convertedColor)
    {
        // Get the red, green, and blue components of the color
        [convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];

        // Convert the components to numbers (unsigned decimal integer) between 0 and 255
        redIntValue=redFloatValue*255.99999f;
        greenIntValue=greenFloatValue*255.99999f;
        blueIntValue=blueFloatValue*255.99999f;

        // Convert the numbers to hex strings
        redHexValue=[NSString stringWithFormat:@"%02x", redIntValue]; 
        greenHexValue=[NSString stringWithFormat:@"%02x", greenIntValue];
        blueHexValue=[NSString stringWithFormat:@"%02x", blueIntValue];

        // Concatenate the red, green, and blue components' hex strings together with a "#"
        return [NSString stringWithFormat:@"#%@%@%@", redHexValue, greenHexValue, blueHexValue];
    }
    return nil;
}

+ (NSColor *)colorWithCSS:(NSString *)hex {
    
    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringWithRange:NSMakeRange(1, [hex length] - 1)];
    }
    
	unsigned int colorCode = 0;
	
	if (hex) {
		NSScanner *scanner = [NSScanner scannerWithString:hex];
		(void)[scanner scanHexInt:&colorCode];
	}
    
	return [NSColor colorWithDeviceRed:((colorCode>>16)&0xFF)/255.0 green:((colorCode>>8)&0xFF)/255.0 blue:((colorCode)&0xFF)/255.0 alpha:1.0];
}

@end
