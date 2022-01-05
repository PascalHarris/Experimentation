#import <Foundation/Foundation.h>

@implementation NSString (String_Wangers)

- (NSArray<NSString *> *)componentsSeparatedByCaseInsensitiveString:(NSString *)separator {
    NSMutableArray* returnArray = NSMutableArray.new;
    NSRange searchRange = NSMakeRange(0,self.length);
    NSRange iRange;
    while (true) {
        searchRange.length = self.length - searchRange.location;
        iRange = [self rangeOfString:separator options:NSCaseInsensitiveSearch range:searchRange];
        if (iRange.location != NSNotFound) {
            searchRange.location = iRange.location+iRange.length;
            NSString* subString = [self substringWithRange:NSMakeRange(searchRange.location,self.length - searchRange.location)];
            NSRange jRange = [subString rangeOfString:separator options:NSCaseInsensitiveSearch];
            [returnArray addObject:(jRange.location != NSNotFound)?[subString substringWithRange:NSMakeRange(0,jRange.location)]:subString];
        } else {
            iRange = [self rangeOfString:separator options:NSCaseInsensitiveSearch];
            [returnArray insertObject:(iRange.location != NSNotFound)?[self substringWithRange:NSMakeRange(0,iRange.location)]:self atIndex:0];
            break;
        }
    }
    return returnArray;
}

@end