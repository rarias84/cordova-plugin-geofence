//
//  GeofenceHelper.m
//  OutSystems
//
//  Created by Vitor Oliveira on 20/04/16.
//
//

#import "GeofenceHelper.h"
#import "OutSystems-Swift.h"

@implementation GeofenceHelper

+(BOOL) validateTimeIntervalWithDictionary: (NSDictionary *) parsedData {
    Boolean showNotification = NO;
    //Compare with dates of event to validate if we should create the Local Notification
    NSString * timeDateStart = [[parsedData valueForKey:@"notification"] valueForKey:@"dateStart"];
    NSString * timeDateEnd = [[parsedData valueForKey:@"notification"] valueForKey:@"dateEnd"];
    BOOL happensOnce = [[[parsedData valueForKey:@"notification"] valueForKey:@"happensOnce"] boolValue];
    BOOL notificationShowed = [[[parsedData valueForKey:@"notification"] valueForKey:@"notificationShowed"] boolValue];
    
    NSString *timestampNotificationShowedString = [[parsedData valueForKey:@"notification"] valueForKey:@"dateNotificationShowed"];
    NSDate *timestampNotificationShowed = [self convertStringToDate:timestampNotificationShowedString];
    NSInteger secondsBetweenNotifications = [[[parsedData valueForKey:@"notification"] valueForKey:@"secondsBetweenNotifications"] integerValue];
    
    NSLog(@"ReceiveTransitionsIntentService - Geofence transition detected - happensOnce - %hhd ",happensOnce);
    NSLog(@"ReceiveTransitionsIntentService - Geofence transition detected - notificationShowed - %hhd ",notificationShowed);
    NSLog(@"ReceiveTransitionsIntentService - Geofence transition detected - timestampNotificationShowed - %@ ",timestampNotificationShowed);
    NSLog(@"ReceiveTransitionsIntentService - Geofence transition detected - secondsBetweenNotifications - %ld ",(long)secondsBetweenNotifications);
    
    //Get Date Now
    NSDate * dateNow = [NSDate date];
    
    if(!timeDateStart && !timeDateEnd) {
        NSLog(@"ReceiveTransitionsIntentService - Time Date not defined...");
        NSLog(@"ReceiveTransitionsIntentService - secondsBetweenNotifications %d", secondsBetweenNotifications);
        if (secondsBetweenNotifications == 0) {
            NSLog(@"ReceiveTransitionsIntentService - secondsBetweenNotifications is 0");
            showNotification = YES;
        }else{
            NSLog(@"ReceiveTransitionsIntentService - secondsBetweenNotifications is NOT  0");
            if (timestampNotificationShowed == nil ){
                NSLog(@"ReceiveTransitionsIntentService - timestampNotificationShowed is nil");
                showNotification = YES;
                
            }else{
                NSLog(@"ReceiveTransitionsIntentService - timestampNotificationShowed is NOT nil");
                NSDate *calendar = [NSDate dateWithTimeInterval:secondsBetweenNotifications sinceDate:timestampNotificationShowed];
                NSLog(@"ReceiveTransitionsIntentService - Now %@", dateNow);
                NSLog(@"ReceiveTransitionsIntentService - timestampNotificationShowed %@", timestampNotificationShowed);
                NSLog(@"ReceiveTransitionsIntentService - calendar o sea +120 segundos  %@", calendar);
                
                showNotification = ![self date:dateNow isBetweenDate:timestampNotificationShowed andDate:calendar];
                NSLog(@"asdf %hhd", [self date:dateNow isBetweenDate:timestampNotificationShowed andDate:calendar]);
                NSLog(@"ReceiveTransitionsIntentService - showNotification %hhu ",showNotification);
            }
            if (showNotification){
                NSLog(@"Testing ");
                NSLog(@"%@", [self convertDateToString:dateNow]);
                [[parsedData valueForKey:@"notification"] setValue:[self convertDateToString:dateNow] forKey:@"dateNotificationShowed"];
                // Update Geofence
                NSLog(@"%@",parsedData);
                NSError * err;
                NSData * jsonData = [NSJSONSerialization  dataWithJSONObject:parsedData options:0 error:&err];
                NSString * geofenceStr = [[NSString alloc] initWithData:jsonData   encoding:NSUTF8StringEncoding];
                
                WrapperStore *wrapper = [[WrapperStore alloc] init];
                [wrapper updateDB:geofenceStr];
            }
        }
    } else {
        NSLog(@"ReceiveTransitionsIntentService - Time Date defined...");
        
        if(notificationShowed && happensOnce) {
            showNotification = NO;
            return showNotification;
        }

        // Convert Date String to NSDate
        NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
        //[formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
        NSDate *_timeDateStart = [formatter dateFromString:timeDateStart];
        NSDate *_timeDateEnd = [formatter dateFromString:timeDateEnd];
        
        if([_timeDateEnd compare:_timeDateStart] == NSOrderedSame || [_timeDateEnd compare:_timeDateStart] == NSOrderedAscending) {
            _timeDateEnd = [NSDate date];
        }
        
        showNotification = [self date:dateNow isBetweenDate:_timeDateStart andDate:_timeDateEnd];
        
        if (timestampNotificationShowed != nil ){
            NSDate *calendar = [NSDate dateWithTimeInterval:secondsBetweenNotifications sinceDate:timestampNotificationShowed];
            showNotification = showNotification ? ![self date:dateNow isBetweenDate:timestampNotificationShowed andDate:calendar] : showNotification;
        }
        
        if(showNotification && !notificationShowed && happensOnce) {
            [[parsedData valueForKey:@"notification"] setValue:[NSNumber numberWithBool:YES] forKey:@"notificationShowed"];
            [[parsedData valueForKey:@"notification"] setValue:[self convertDateToString:dateNow] forKey:@"dateNotificationShowed"];
            // Update Geofence
            NSError * err;
            NSData * jsonData = [NSJSONSerialization  dataWithJSONObject:parsedData options:0 error:&err];
            NSString * geofenceStr = [[NSString alloc] initWithData:jsonData   encoding:NSUTF8StringEncoding];
            
            WrapperStore *wrapper = [[WrapperStore alloc] init];
            [wrapper updateDB:geofenceStr];
        }
    }
    
    return showNotification;
}

+ (NSDate *)convertStringToDate:(NSString*)date {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MM/dd/yyyy hh:mm:ss Z"];
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    NSDate *cI = [dateFormat dateFromString:date];
    return cI;
}

+ (NSString *)convertDateToString:(NSDate*)date {
    NSLog(@"Probar");
    NSLog(@"%@", date);
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yyyy hh:mm:ss Z"];
    return [formatter stringFromDate:[NSDate date]];
}

+ (BOOL)date:(NSDate*)date isBetweenDate:(NSDate*)beginDate andDate:(NSDate*)endDate
{
    if ([date compare:beginDate] == NSOrderedAscending)
        return NO;
    
    if ([date compare:endDate] == NSOrderedDescending)
        return NO;
    
    return YES;
}

+(BOOL) validateTimeIntervalWithString: (NSString*) geofenceStr {
    NSError *jsonError;
    NSData *objectData = [geofenceStr dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:objectData
                                                                      options:NSJSONReadingMutableContainers
                                                                        error:&jsonError];
    return [self validateTimeIntervalWithDictionary:parsedData];

}


@end