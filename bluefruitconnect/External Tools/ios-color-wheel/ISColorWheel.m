/*
 By: Justin Meiners
 
 Copyright (c) 2015 Justin Meiners
 Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
 */

#import "ISColorWheel.h"

static CGFloat ISColorWheel_PointDistance (CGPoint p1, CGPoint p2)
{
    return sqrtf((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y));
}

static ISColorWheelPixelRGB ISColorWheel_HSBToRGB (CGFloat h, CGFloat s, CGFloat v)
{
    h *= 6.0f;
    
    NSInteger i = (NSInteger)floorf(h);
    CGFloat f = h - (CGFloat)i;
    CGFloat p = v *  (1.0f - s);
    CGFloat q = v * (1.0f - s * f);
    CGFloat t = v * (1.0f - s * (1.0f - f));
    
    CGFloat r;
    CGFloat g;
    CGFloat b;
    
    switch (i)
    {
        case 0:
            r = v;
            g = t;
            b = p;
            break;
        case 1:
            r = q;
            g = v;
            b = p;
            break;
        case 2:
            r = p;
            g = v;
            b = t;
            break;
        case 3:
            r = p;
            g = q;
            b = v;
            break;
        case 4:
            r = t;
            g = p;
            b = v;
            break;
        default:        // case 5:
            r = v;
            g = p;
            b = q;
            break;
    }
    
    ISColorWheelPixelRGB pixel;
    pixel.r = r * 255.0f;
    pixel.g = g * 255.0f;
    pixel.b = b * 255.0f;
    
    return pixel;
}

@interface ISColorKnobView : UIView
@property(nonatomic, strong)UIColor* fillColor;

@end

@implementation ISColorKnobView

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        self.backgroundColor = [UIColor clearColor];
        self.fillColor = [UIColor clearColor];
        
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGFloat borderWidth = 2.0f;
    CGRect borderFrame = CGRectInset(self.bounds, borderWidth / 2.0, borderWidth / 2.0);
    
    CGContextSetFillColorWithColor(ctx, _fillColor.CGColor);
    CGContextAddEllipseInRect(ctx, borderFrame);
    CGContextFillPath(ctx);

    
    CGContextSetLineWidth(ctx, borderWidth);
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextAddEllipseInRect(ctx, borderFrame);
    CGContextStrokePath(ctx);
}

@end


@interface ISColorWheel ()
{
    CGImageRef _radialImage;
    ISColorWheelPixelRGB* _imageData;
    int _imageDataLength;
    float _radius;
    CGPoint _touchPoint;
}

- (ISColorWheelPixelRGB)colorAtPoint:(CGPoint)point;

- (CGPoint)viewToImageSpace:(CGPoint)point;
- (void)updateKnob;


@end



@implementation ISColorWheel

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        _radialImage = nil;
        _imageData = nil;
        
        _imageDataLength = 0;
        
        _brightness = 1.0;
        _knobSize = CGSizeMake(28, 28);
        
        _touchPoint = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
        
        
        self.borderColor = [UIColor blackColor];
        self.borderWidth = 3.0;
        
        self.backgroundColor = [UIColor clearColor];
        self.knobView = [[ISColorKnobView alloc] init];

        _continuous = false;
    }
    return self;
}

- (void)dealloc
{
    if (_radialImage)
    {
        CGImageRelease(_radialImage);
        _radialImage = nil;
    }
    
    if (_imageData)
    {
        free(_imageData);
    }
    
    self.knobView = nil;
}


- (ISColorWheelPixelRGB)colorAtPoint:(CGPoint)point
{
    CGPoint center = CGPointMake(_radius, _radius);
    
    CGFloat angle = atan2(point.x - center.x, point.y - center.y) + M_PI;
    CGFloat dist = ISColorWheel_PointDistance(point, CGPointMake(center.x, center.y));
    
    CGFloat hue = angle / (M_PI * 2.0f);
    
    hue = MIN(hue, 1.0f - .0000001f);
    hue = MAX(hue, 0.0f);
    
    CGFloat sat = dist / (_radius);
    
    sat = MIN(sat, 1.0f);
    sat = MAX(sat, 0.0f);
    
    return ISColorWheel_HSBToRGB(hue, sat, _brightness);
}

- (CGPoint)viewToImageSpace:(CGPoint)point
{
    float width = self.bounds.size.width;
    float height = self.bounds.size.height;
    
    point.y = height - point.y;
    
    CGPoint min = CGPointMake(width / 2.0 - _radius, height / 2.0 - _radius);
    
    point.x = point.x - min.x;
    point.y = point.y - min.y;
    
    return point;
}

- (void)updateKnob
{
    if (!_knobView)
    {
        return;
    }
    
    _knobView.bounds = CGRectMake(0, 0, _knobSize.width, _knobSize.height);
    _knobView.center = _touchPoint;
}

- (void)updateImage
{
    if (self.bounds.size.width == 0 || self.bounds.size.height == 0)
    {
        return;
    }
    
    if (_radialImage)
    {
        CGImageRelease(_radialImage);
        _radialImage = nil;
    }
    
    int width = _radius * 2.0;
    int height = width;
    
    int dataLength = sizeof(ISColorWheelPixelRGB) * width * height;
    
    if (dataLength != _imageDataLength)
    {
        if (_imageData)
        {
            free(_imageData);
        }
        _imageData = malloc(dataLength);
        _imageDataLength = dataLength;
    }
    
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            _imageData[x + y * width] = [self colorAtPoint:CGPointMake(x, y)];
        }
    }
    
    CGBitmapInfo bitInfo = kCGBitmapByteOrderDefault;
    
	CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, _imageData, dataLength, NULL);
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
	_radialImage = CGImageCreate(width,
                                 height,
                                 8,
                                 24,
                                 width * 3,
                                 colorspace,
                                 bitInfo,
                                 ref,
                                 NULL,
                                 true,
                                 kCGRenderingIntentDefault);
    
    CGColorSpaceRelease(colorspace);
    CGDataProviderRelease(ref);
    
    [self setNeedsDisplay];
}

- (UIColor*)currentColor
{
    ISColorWheelPixelRGB pixel = [self colorAtPoint:[self viewToImageSpace:_touchPoint]];
    return [UIColor colorWithRed:pixel.r / 255.0f green:pixel.g / 255.0f blue:pixel.b / 255.0f alpha:1.0];
}

- (void)setCurrentColor:(UIColor*)color
{
    CGFloat h = 0.0;
    CGFloat s = 0.0;
    CGFloat b = 1.0;
    CGFloat a = 1.0;
    
    [color getHue:&h saturation:&s brightness:&b alpha:&a];
    
    self.brightness = b;
    
    CGPoint center = CGPointMake(_radius, _radius);
    
    float angle = (h * (M_PI * 2.0)) + M_PI / 2;
    float dist = s * _radius;
    
    CGPoint point;
    point.x = center.x + (cosf(angle) * dist);
    point.y = center.y + (sinf(angle) * dist);
    
    [self setTouchPoint: point];
    [self updateImage];
}

- (void)setBrightness:(CGFloat)brightness
{
    _brightness = brightness;
    
    [self updateImage];
    
    if ([_knobView respondsToSelector:@selector(setFillColor:)])
    {
        [_knobView performSelector:@selector(setFillColor:) withObject:self.currentColor afterDelay:0.0f];
        [_knobView setNeedsDisplay];
    }
    
    [_delegate colorWheelDidChangeColor:self];
}

- (void)setKnobView:(UIView *)knobView
{
    if (_knobView)
    {
        [_knobView removeFromSuperview];
    }
    
    _knobView = knobView;
    
    if (_knobView)
    {
        [self addSubview:_knobView];
    }
    
    [self updateKnob];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState (ctx);
    
    NSInteger width = self.bounds.size.width;
    NSInteger height = self.bounds.size.height;
    CGPoint center = CGPointMake(width / 2.0, height / 2.0);

    
    CGRect wheelFrame = CGRectMake(center.x - _radius, center.y - _radius, _radius * 2.0, _radius * 2.0);
    CGRect borderFrame = CGRectInset(wheelFrame, -_borderWidth / 2.0, -_borderWidth / 2.0);

    if (_borderWidth > 0.0f)
    {
        CGContextSetLineWidth(ctx, _borderWidth);
        CGContextSetStrokeColorWithColor(ctx, [_borderColor CGColor]);
        CGContextAddEllipseInRect(ctx, borderFrame);
        CGContextStrokePath(ctx);
    }
    
    CGContextAddEllipseInRect(ctx, wheelFrame);
    CGContextClip(ctx);
    
    if (_radialImage)
    {
        CGContextDrawImage(ctx, wheelFrame, _radialImage);
    }
    
    CGContextRestoreGState (ctx);
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _radius = (MIN(self.bounds.size.width, self.bounds.size.height) / 2.0) - MAX(0.0f, _borderWidth);
    
    [self updateImage];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self setTouchPoint:[[touches anyObject] locationInView:self]];
    
    if ([_knobView respondsToSelector:@selector(setFillColor:)])
    {
        [_knobView performSelector:@selector(setFillColor:) withObject:self.currentColor afterDelay:0.0f];
        [_knobView setNeedsDisplay];
    }
    
    [_delegate colorWheelDidChangeColor:self];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self setTouchPoint:[[touches anyObject] locationInView:self]];
    
    if ([_knobView respondsToSelector:@selector(setFillColor:)])
    {
        [_knobView performSelector:@selector(setFillColor:) withObject:self.currentColor afterDelay:0.0f];
        [_knobView setNeedsDisplay];
    }
    
    if (_continuous)
    {
        [_delegate colorWheelDidChangeColor:self];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_delegate colorWheelDidChangeColor:self];
}


- (void)setTouchPoint:(CGPoint)point
{
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    
    CGPoint center = CGPointMake(width / 2.0, height / 2.0);
    
    // Check if the touch is outside the wheel
    if (ISColorWheel_PointDistance(center, point) < _radius)
    {
        _touchPoint = point;
    }
    else
    {
        // If so we need to create a drection vector and calculate the constrained point
        CGPoint vec = CGPointMake(point.x - center.x, point.y - center.y);
        
        float extents = sqrtf((vec.x * vec.x) + (vec.y * vec.y));
        
        vec.x /= extents;
        vec.y /= extents;
        
        _touchPoint = CGPointMake(center.x + vec.x * _radius, center.y + vec.y * _radius);
    }
    
    [self updateKnob];
}

@end
