//
//  Document.m
//  VLCX
//
//  Created by Guilherme Rambo on 15/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

#import "VXVideoDocument.h"
#import "VXControllerView.h"
#import "VXWindowDragView.h"
#import "VXVideoAdjustmentsController.h"
#import "NSDocumentController+VLCXAdditions.h"
#import "VXPlayerWindow.h"

@interface VXVideoDocument () <NSMenuDelegate>

@property (weak) IBOutlet VXWindowDragView *dragView;
@property (weak) IBOutlet VXControllerView *controllerView;
@property (strong) IBOutlet VLCVideoView *videoView;
@property (strong) IBOutlet VXVideoAdjustmentsController *videoAdjustmentsController;

@end

@implementation VXVideoDocument
{
    BOOL _postponedSetMedia;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    
    return self;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];

    // add the controllerView as an extra control so it fades out when the cursor leaves the window
    [self.dragView addExtraControl:self.controllerView];
    
    self.videoView.fillScreen = YES;
    
    self.player = [[VLCMediaPlayer alloc] initWithVideoView:self.videoView];
    
    // tell the playbackController to control our player
    [self.playbackController setRepresentedObject:self.player];
    
    // the playbackController will get the media delegate callbacks
    self.media.delegate = self.playbackController;
    
    [self.videoAdjustmentsController setPlayer:self.player];
    
    if (!self.media) {
        // we will set the media later
        _postponedSetMedia = YES;
    } else {
        // at this point we already have a VLCMedia object initialized because readFromURL: is called before windowControllerDidLoadNib:
        [self.player setMedia:self.media];
        
        // start playing after a short delay,
        // this short delay ensures there are no audio glitches when starting the playback
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.player play];
        });
    }
}

- (void)setInternetURL:(NSURL *)internetURL
{
    if (!internetURL) return;
    
    [super setInternetURL:internetURL];
    
    self.displayName = self.internetURL.lastPathComponent;
    self.media = [VLCMedia mediaWithURL:self.internetURL];
}

- (void)setMedia:(VLCMedia *)media
{
    [super setMedia:media];
    
    if (_postponedSetMedia) {
        _postponedSetMedia = NO;
        
        [self.player setMedia:self.media];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.player play];
        });
    }
}

#pragma mark Video-specific actions

- (IBAction)snapshot:(id)sender
{
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES);
    NSString *filename = [NSString stringWithFormat:@"vlcxsnap_%.0f.png", [NSDate date].timeIntervalSince1970];
    NSString *snapshotURL = [NSString pathWithComponents:@[searchPaths[0], filename]];
    
    [self.player saveVideoSnapshotAt:snapshotURL withWidth:self.player.videoSize.width andHeight:self.player.videoSize.height];
}

- (IBAction)openSubtitlesFile:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowedFileTypes = [NSDocumentController subtitlesFileTypes];
    openPanel.title = NSLocalizedString(@"Open subtitles file", @"Open subtitles file");
    
    [(VXPlayerWindow *)self.windowForSheet showTitlebarAnimated:NO];
    [openPanel beginSheetModalForWindow:self.windowForSheet completionHandler:^(NSInteger result) {
        if (!result) return;
        
        BOOL opened = [self.player openVideoSubTitlesFromFile:openPanel.URL.path];
        
        if (opened) {
            [self.playbackController updateSubtitlesMenuAfterOpeningCustomSubtitle];
        } else {
            NSError *error = [NSError errorWithDomain:@"vlcx"
                                                 code:0
                                             userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to open subtitles file", @"Unable to open subtitles file")}];
            [[NSAlert alertWithError:error] runModal];
        }
    }];
}

- (IBAction)toggleFullscreen:(id)sender
{
    [self.windowForSheet toggleFullScreen:sender];
}

- (IBAction)toggleVideoAdjustmentsPanel:(id)sender
{
    if (!self.player.media) return;
    
    [self.videoAdjustmentsController togglePanelVisibility];
    
    if (self.videoAdjustmentsController.isPanelVisible) {
        [sender setState:NSOnState];
    } else {
        [sender setState:NSOffState];
    }
}

@end
