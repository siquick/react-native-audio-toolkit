//
//  AudioPlayer.m
//  ReactNativeAudioToolkit
//
//  Created by Oskar Vuola on 28/06/16.
//  Copyright (c) 2016 Futurice.
//
//  Licensed under the MIT license. For more information, see LICENSE.

#import "AudioPlayer.h"
#import "Helpers.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVAsset.h>


@interface AudioPlayer ()

@property (nonatomic, strong) NSMutableDictionary *playerPool;

@end

@implementation AudioPlayer

@synthesize bridge = _bridge;


-(NSMutableDictionary*) playerPool {
    if (!_playerPool) {
        _playerPool = [NSMutableDictionary new];
    }
    return _playerPool;
}

-(AVPlayer*) playerForKey:(nonnull NSNumber*)key {
    return [_playerPool objectForKey:key];
}

-(NSNumber*) keyForPlayer:(nonnull AVPlayer*)player {
    return [[_playerPool allKeysForObject:player] firstObject];
}


#pragma mark React exposed methods

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(init:(nonnull NSNumber*)playerId withPath:(NSString* _Nullable)path withCallback:(RCTResponseSenderBlock)callback) {
    if ([path length] == 0) {
        NSDictionary* dict = [Helpers errObjWithCode:@"nopath" withMessage:@"Provided path was empty"];
        callback(@[dict]);
        return;
    }
    
    NSURL *url;
    
    NSString* mainBundle = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], path];
    BOOL isDir;
    NSFileManager* fm = [[NSFileManager alloc] init];
    if ([fm fileExistsAtPath:mainBundle isDirectory:isDir]) {
        url = [NSURL fileURLWithPath:mainBundle];
    } else {
        url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSError* error;
    AVPlayer* player = [[AVPlayer alloc]
                        initWithURL:url];
    //initWithURL:[NSURL fileURLWithPath:[path stringByRemovingPercentEncoding]]];
    //error:&error];
    
    //initWithContentsOfURL:
    if (player) {
        [[self playerPool] setObject:player forKey:playerId];
        
        callback(@[[NSNull null]]);
    } else {
        callback(@[RCTJSErrorFromNSError(error)]);
    }
}

RCT_EXPORT_METHOD(destroy:(nonnull NSNumber*)playerId) {
    AVPlayer* player = [self playerForKey:playerId]; if (player) {
        [player pause];
        [[self playerPool] removeObjectForKey:playerId];
    }
}

RCT_EXPORT_METHOD(prepare:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player cancelPendingPrerolls];
    
    [player prerollAtRate:0.0 completionHandler:^(BOOL finished) {
        callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration)),
                                    @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
    }];
}

RCT_EXPORT_METHOD(seek:(nonnull NSNumber*)playerId withPos:(nonnull NSNumber*)position withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player cancelPendingPrerolls];
    
    if (position >= 0) {
        NSLog(@"%d", position);
        if (position == 0) {
            [player.currentItem
             seekToTime:kCMTimeZero
             toleranceBefore:kCMTimeZero // for precise positioning
             toleranceAfter:kCMTimeZero
             completionHandler:^(BOOL finished) {
                 callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration)),
                                             @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
             }];
        } else {
            [player.currentItem
             seekToTime:CMTimeMakeWithSeconds([position doubleValue] / 1000, 60000)
             completionHandler:^(BOOL finished) {
                 callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration)),
                                             @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
             }];
        }
    }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player play];
    callback(@[[NSNull null], @{@"duration": @(CMTimeGetSeconds(player.currentItem.asset.duration)),
                                @"position": @(CMTimeGetSeconds(player.currentTime) * 1000)}]);
}

RCT_EXPORT_METHOD(set:(nonnull NSNumber*)playerId withOpts:(NSDictionary*)options withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    float volume = [[options objectForKey:@"volume"] floatValue];
    if (volume) {
        [player setVolume:volume];
    }
    
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player pause];
    [player.currentItem seekToTime:CMTimeMakeWithSeconds(0.0, 60000)];
    
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player pause];
    
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(resume:(nonnull NSNumber*)playerId withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:playerId];
    
    if (!player) {
        NSDictionary* dict = [Helpers errObjWithCode:@"notfound"
                                         withMessage:[NSString stringWithFormat:@"playerId %d not found.", playerId]];
        callback(@[dict]);
        return;
    }
    
    [player play];
    
    callback(@[[NSNull null]]);
}

//#pragma mark Audio
#pragma mark Audio Delegates

- (void)playerItemDidReachEnd:(AVPlayer *)player
                 successfully:(BOOL)flag {
    
    NSNumber* playerId = [self keyForPlayer:player];
    
    NSLog (@"RCTAudioPlayer: Playing finished, successful: %d", flag);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:ended"
                                                    body:@{@"status": @"Finished playback"}];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setActive:NO error:&error];
    
    if (error) {
        NSLog (@"RCTAudioPlayer: Could not deactivate current audio session. Error: %@", error);
        [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
                                                        body:@{@"error": [error description]}];
        return;
    }
}
/*
 
 - (void)audioPlayerDecodeErrorDidOccur:(AVPlayer *)player
 error:(NSError *)error {
 
 NSString *errorDescription = [NSString stringWithFormat:@"Decoding error during playback: %@", [error description]];
 [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTAudioPlayer:error"
 body:@{@"error": errorDescription}];
 }
 
 */

@end
