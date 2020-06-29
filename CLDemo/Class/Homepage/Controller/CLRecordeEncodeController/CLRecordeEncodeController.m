//
//  CLRecordeEncodeController.m
//  CLDemo
//
//  Created by JmoVxia on 2020/6/24.
//  Copyright © 2020 JmoVxia. All rights reserved.
//

#import "CLRecordeEncodeController.h"
#import "CLRecorder.h"
#import "CLDemo-Swift.h"
#import <AVFoundation/AVFoundation.h>
#import "CLVoicePlayer.h"

static void set_bits(uint8_t *bytes, int32_t bitOffset, int32_t numBits, int32_t value) {
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    uint8_t *data = bytes;
    data += bitOffset / 8;
    bitOffset %= 8;
    *((int32_t *)data) |= ((value) << bitOffset);
}



@interface CLRecordeEncodeController ()

@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) CLRecorder *recorder;
@property (nonatomic, strong) CLChatVoiceWave *waveView;
@property (nonatomic, strong) CLChatVoiceWave *waveView1;
@property (nonatomic, strong) CLVoicePlayer *player;

@end

@implementation CLRecordeEncodeController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.recorder = [[CLRecorder alloc] init];
    [self.view addSubview:self.startButton];
    [self.view addSubview:self.playButton];
    [self.view addSubview:self.waveView];
    [self.view addSubview:self.waveView1];
    [self.startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(90);
        make.top.mas_equalTo(200);
    }];
    [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(200);
        make.right.mas_equalTo(-90);
    }];
    [self.waveView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.mas_equalTo(self.view);
        make.size.mas_equalTo(CGSizeMake(200, 50));
    }];
    [self.waveView1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.view);
        make.top.mas_equalTo(self.waveView.mas_bottom);
        make.size.mas_equalTo(CGSizeMake(200, 50));
    }];

    self.waveView.peakHeight = 50;
    self.waveView1.peakHeight = 50;
}

- (void)startAction {
    if (!self.startButton.selected) {
        NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
        [self.recorder startRecorder];
        NSTimeInterval end = [[NSDate date] timeIntervalSince1970];
        CLLog(@"%f",end - start);
        CLLog(@"%@",self.recorder.mp3Path);
    }else {
        [self.recorder stopRecorder];
        if (self.recorder.mp3Path.length > 0) {
            NSData *waveSamples = [self audioWaveform];
            self.waveView.waveData = waveSamples;
            
            NSData *waveSamples1 = [self audioWaveform:[NSURL fileURLWithPath:self.recorder.mp3Path]];
            self.waveView1.waveData = waveSamples1;
        }
    }
    self.startButton.selected = !self.startButton.selected;
}
- (void)playAction {
    if (self.recorder.mp3Path.length > 0) {
        if (!self.playButton.isSelected) {
            [self.player playWithUrl:[NSURL fileURLWithPath:self.recorder.mp3Path]];
        }else {
            [self.player stop];
        }
        self.playButton.selected = !self.playButton.selected;
    }
}
- (NSData *)audioWaveform:(NSURL *)url {
//    NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    CMTime audioDuration = asset.duration;
    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
    CLLog(@"获取到时长为 %f", audioDurationSeconds);

    if (asset == nil) {
        CLLog(@"asset is not defined!");
        return nil;
    }
    
    NSError *assetError = nil;
    AVAssetReader *iPodAssetReader = [AVAssetReader assetReaderWithAsset:asset error:&assetError];
    if (assetError) {
        CLLog (@"error: %@", assetError);
        return nil;
    }
    
    AVAssetReaderOutput *readerOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:outputSettings];
    
    if (! [iPodAssetReader canAddOutput: readerOutput]) {
        CLLog (@"can't add reader output... die!");
        return nil;
    }
    
    // add output reader to reader
    [iPodAssetReader addOutput: readerOutput];
    
    if (! [iPodAssetReader startReading]) {
        CLLog(@"Unable to start reading!");
        return nil;
    }
//    NSTimeInterval end = [[NSDate date] timeIntervalSince1970];
//    NSLog(@"%f",end - start);

    NSMutableData *_waveformSamples = [[NSMutableData alloc] init];
    int16_t _waveformPeak = 0;
    int _waveformPeakCount = 0;
    
    while (iPodAssetReader.status == AVAssetReaderStatusReading) {
        // Check if the available buffer space is enough to hold at least one cycle of the sample data
        CMSampleBufferRef nextBuffer = [readerOutput copyNextSampleBuffer];
        
        if (nextBuffer) {
            AudioBufferList abl;
            CMBlockBufferRef blockBuffer = NULL;
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
            UInt64 size = CMSampleBufferGetTotalSampleSize(nextBuffer);
            if (size != 0) {
                int16_t *samples = (int16_t *)(abl.mBuffers[0].mData);
                int count = (int)size / 2;
                
                for (int i = 0; i < count; i++) {
                    int16_t sample = samples[i];
                    if (sample < 0) {
                        sample = -sample;
                    }
                    
                    if (_waveformPeak < sample) {
                        _waveformPeak = sample;
                    }
                    _waveformPeakCount++;
                    
                    if (_waveformPeakCount >= 100) {
                        [_waveformSamples appendBytes:&_waveformPeak length:2];
                        _waveformPeak = 0;
                        _waveformPeakCount = 0;
                    }
                }
            }
            
            CFRelease(nextBuffer);
            if (blockBuffer) {
                CFRelease(blockBuffer);
            }
        }
        else {
            break;
        }
    }
    
    int16_t scaledSamples[100];
    memset(scaledSamples, 0, 100 * 2);
    int16_t *samples = _waveformSamples.mutableBytes;
    int count = (int)_waveformSamples.length / 2;
    for (int i = 0; i < count; i++) {
        int16_t sample = samples[i];
        int index = i * 100 / count;
        if (scaledSamples[index] < sample) {
            scaledSamples[index] = sample;
        }
    }
    
    int16_t peak = 0;
    int64_t sumSamples = 0;
    for (int i = 0; i < 100; i++) {
        int16_t sample = scaledSamples[i];
        if (peak < sample) {
            peak = sample;
        }
        sumSamples += sample;
    }
    uint16_t calculatedPeak = 0;
    calculatedPeak = (uint16_t)(sumSamples * 1.8f / 100);
    
    if (calculatedPeak < 2500) {
        calculatedPeak = 2500;
    }
    
    for (int i = 0; i < 100; i++) {
        uint16_t sample = (uint16_t)((int64_t)samples[i]);
        if (sample > calculatedPeak) {
            scaledSamples[i] = calculatedPeak;
        }
    }
    
    int numSamples = 100;
    int number = 5;
    int bitstreamLength = (numSamples * number) / 8 + (((numSamples * number) % 8) == 0 ? 0 : 1);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:bitstreamLength];
    {
        int32_t maxSample = peak;
        uint16_t const *samples = (uint16_t *)scaledSamples;
        uint8_t *bytes = result.mutableBytes;
        
        for (int i = 0; i < numSamples; i++) {
            int32_t value = MIN(31, ABS((int32_t)samples[i]) * 31 / maxSample);
            set_bits(bytes, i * number, number, value & 31);
        }
    }
    return result;
}
- (NSData *)audioWaveform {
    int16_t scaledSamples[100];
    memset(scaledSamples, 0, 100 * 2);
    int16_t *samples = self.recorder.waveformSamples.mutableBytes;
    int count = (int)self.recorder.waveformSamples.length / 2;
    for (int i = 0; i < count; i++) {
        int16_t sample = samples[i];
        int index = i * 100 / count;
        if (scaledSamples[index] < sample) {
            scaledSamples[index] = sample;
        }
    }
    
    int16_t peak = 0;
    int64_t sumSamples = 0;
    for (int i = 0; i < 100; i++) {
        int16_t sample = scaledSamples[i];
        if (peak < sample) {
            peak = sample;
        }
        sumSamples += sample;
    }
    uint16_t calculatedPeak = 0;
    calculatedPeak = (uint16_t)(sumSamples * 1.8f / 100);
    
    if (calculatedPeak < 2500) {
        calculatedPeak = 2500;
    }
    
    for (int i = 0; i < 100; i++) {
        uint16_t sample = (uint16_t)((int64_t)samples[i]);
        if (sample > calculatedPeak) {
            scaledSamples[i] = calculatedPeak;
        }
    }
    
    int numSamples = 100;
    int number = 5;
    int bitstreamLength = (numSamples * number) / 8 + (((numSamples * number) % 8) == 0 ? 0 : 1);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:bitstreamLength];
    {
        int32_t maxSample = peak;
        uint16_t const *samples = (uint16_t *)scaledSamples;
        uint8_t *bytes = result.mutableBytes;
        
        for (int i = 0; i < numSamples; i++) {
            int32_t value = MIN(31, ABS((int32_t)samples[i]) * 31 / maxSample);
            set_bits(bytes, i * number, number, value & 31);
        }
    }
    return result;
}


- (UIButton *)startButton {
    if (!_startButton) {
        _startButton = [[UIButton alloc] init];
        [_startButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
        [_startButton setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
        [_startButton setTitle:@"开始" forState:UIControlStateNormal];
        [_startButton setTitle:@"结束" forState:UIControlStateSelected];
        [_startButton addTarget:self action:@selector(startAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _startButton;
}
- (UIButton *)playButton {
    if (!_playButton) {
        _playButton = [[UIButton alloc] init];
        [_playButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
        [_playButton setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
        [_playButton setTitle:@"播放" forState:UIControlStateNormal];
        [_playButton setTitle:@"停止" forState:UIControlStateSelected];
        [_playButton addTarget:self action:@selector(playAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playButton;
}

- (CLChatVoiceWave *)waveView {
    if (!_waveView) {
        _waveView = [[CLChatVoiceWave alloc] init];
    }
    return _waveView;
}
- (CLChatVoiceWave *)waveView1 {
    if (!_waveView1) {
        _waveView1 = [[CLChatVoiceWave alloc] init];
    }
    return _waveView1;
}
- (CLVoicePlayer *)player {
    if (!_player) {
        _player = [[CLVoicePlayer alloc] init];
    }
    return _player;
}
@end