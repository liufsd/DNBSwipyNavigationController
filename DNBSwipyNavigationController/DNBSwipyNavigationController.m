//
//  DNBSwipyNavigationController.m
//  DNBSwipyNavigationController
//
//  Created by Aaron Alexander on 1/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DNBSwipyNavigationController.h"
#import <QuartzCore/QuartzCore.h>

typedef enum {
    ControllerPositionRegular = 0,
    ControllerPositionLeft = 1,
    ControllerPositionRight = 2
} ControllerPosition;

@interface DNBSwipyNavigationController() {
    UIView *_transitionView;
    CGPoint _dragOriginPoint;
    ControllerPosition _currentPosition;
}
- (CGRect)adjustedFrameForPannedFrame:(CGRect)frame;
- (void)completePanWithPoint:(CGPoint)point andSpeed:(float)speed;
- (void)pushLeftController:(UIViewController *)controller;
- (void)pushRightController:(UIViewController *)controller;
- (void)snapBackToMiddle;
@property (nonatomic, retain) UIView *container;
@property (nonatomic, readonly) UIView* transitionView;
@end


@implementation DNBSwipyNavigationController
@synthesize container = _container;

@synthesize nilSideControllersShouldPopCurrentControllers = _nilSideControllersShouldPopCurrentControllers;
@synthesize bounceEnabled = _bounceEnabled;

static float const kPAN_DISTANCE_THRESHOLD = 10;
static float const kPAN_MIN_VELOCITY_THRESHOLD = 500;
static float const kPAN_MAX_VELOCITY_THRESHOLD = 3000;


- (id)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super initWithRootViewController:rootViewController];
    if (self) {
        self.container = [[UIScrollView alloc] initWithFrame:self.view.bounds];
        self.container.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.container];
        [self.container addSubview:self.transitionView];
        [self.container addSubview:self.navigationBar];
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [self snapBackToMiddle];
    [super pushViewController:viewController animated:animated];
}

- (void)presentModalViewController:(UIViewController *)modalViewController animated:(BOOL)animated {
    [self snapBackToMiddle];
    [super presentModalViewController:modalViewController animated:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    [self snapBackToMiddle];
    return YES;
}

- (void)navigationBar:(UINavigationBar *)navigationBar didPopItem:(UINavigationItem *)item {
    [self snapBackToMiddle];
}

#pragma mark - Gesture Recognizers
- (void)panned:(UIPanGestureRecognizer *)sender {
    UIGestureRecognizerState state = sender.state;
    UIView *v = self.container;
    
    CGPoint translatedPoint = [sender translationInView:sender.view];
    float velocity = fabsf([sender velocityInView:sender.view].x); 
    
    float speed = 0;
    if (velocity > kPAN_MIN_VELOCITY_THRESHOLD) {
        speed = velocity;
    } if (speed > kPAN_MAX_VELOCITY_THRESHOLD) {
        speed = kPAN_MAX_VELOCITY_THRESHOLD;
    }
    
    switch (state) {
        case UIGestureRecognizerStateBegan:
        {
            _dragOriginPoint = v.frame.origin;
        } break;
        case UIGestureRecognizerStateChanged:
        {
            // Drag container
            CGRect frame = v.frame;
            frame.origin.x = _dragOriginPoint.x + translatedPoint.x;
            v.frame = [self adjustedFrameForPannedFrame:frame];
                        
            if (self.container.frame.origin.x > 0) {
                [self.leftController.view.superview insertSubview:self.leftController.view atIndex:[self.leftController.view.superview.subviews indexOfObject:self.container]-1];
            } else {

            }
            if (self.container.frame.origin.x < 0) {
                [self.rightController.view.superview insertSubview:self.rightController.view atIndex:[self.rightController.view.superview.subviews indexOfObject:self.container]-1];
            } else {

            }
            
        } break;
        case UIGestureRecognizerStateEnded:
        {
            [self completePanWithPoint:translatedPoint andSpeed:speed];
            
        } break;
        case UIGestureRecognizerStateFailed:
        {
          [self completePanWithPoint:translatedPoint andSpeed:speed];  
        } break;
        case UIGestureRecognizerStateCancelled:
        {
          [self completePanWithPoint:translatedPoint andSpeed:speed];  
        } break;
        case UIGestureRecognizerStatePossible:
        {
            
        } break;
    }
}



#pragma mark - Properties

- (void)setNavigationBar:(id)bar {
    UINavigationBar *b = bar;
    if (b) {
        [self setValue:b forKey:@"_navigationBar"];
        b.delegate = self;
        b.clipsToBounds = YES;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
        pan.delegate = self;
        [self.navigationBar addGestureRecognizer:pan];
    }
}

@dynamic transitionView;
- (UIView *)transitionView {
    UIView *ret = nil;
    if (_transitionView) {
        ret = _transitionView;
    } else {
        for (id obj in self.view.subviews) {
            if ([[obj class] isEqual:NSClassFromString(@"UINavigationTransitionView")]) {
                ret = _transitionView = obj;
            }
        }
    }
    
    return ret;
}

- (void)setViewControllers:(NSArray *)viewControllers {
    [super setViewControllers:viewControllers];
}
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated {
    [super setViewControllers:viewControllers animated:animated];
}

// This is to support setting of the controllers directly on the nav controller
// These can be thought of as "root" controllers
- (void)setLeftController:(UIViewController *)leftController {
    [super setLeftController:leftController];
    [self pushLeftController:leftController];
}
- (void)setRightController:(UIViewController *)rightController {
    [super setRightController:rightController];
    [self pushRightController:rightController];
}

#pragma mark - Private Methods

- (CGRect)adjustedFrameForPannedFrame:(CGRect)frame {
    CGRect ret = frame;
    if (frame.origin.x > 0 && fabsf(frame.origin.x) > self.leftController.view.frame.size.width) {
        ret.origin.x = self.leftController.view.frame.size.width;
    } else if (frame.origin.x < 0 && fabsf(frame.origin.x) > self.rightController.view.frame.size.width) {
        ret.origin.x = -(self.rightController.view.frame.size.width);
    }
    return ret;
}
- (void)snapBackToMiddle {
    if (_currentPosition == ControllerPositionRegular) {
        return;
    }
    void (^snap)() = ^{
        CGRect r = self.container.frame;
        r.origin.x = 0;
        self.container.frame = r;
        _currentPosition = ControllerPositionRegular;
    };
    [UIView animateWithDuration:.20 delay:0.0 
                        options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionBeginFromCurrentState animations:snap completion:^(BOOL finished) {
                            
                        }];
}

- (void)completePanWithPoint:(CGPoint)point andSpeed:(float)speed {

    void (^snap)() = nil;
    CGFloat distance = fabsf(point.x-_dragOriginPoint.x);
    __block BOOL draggingToRight = YES;
    if (point.x<_dragOriginPoint.x) {
        draggingToRight = NO;
    }

    CGFloat overShootDistance = ((speed/10000)*distance)*1;  // TODO factor in distance of travel still needed to make faux falloff
    if (self.bounceEnabled == NO) {
        overShootDistance = 0;
    }
    
    // Stop pans from snapping back to middle if pan is the direction we are already snapped
    if (_currentPosition == ControllerPositionRight && point.x>=CGRectGetMinX(self.transitionView.frame)) {
        return;
    } else if (_currentPosition == ControllerPositionLeft && point.x<=CGRectGetMinX(self.transitionView.frame)) {
        return;
    }
    
    if (distance > kPAN_DISTANCE_THRESHOLD) {
        if (_currentPosition == ControllerPositionRegular) {
            if (draggingToRight) {
                // pop controller to right exposing left controller
                snap = ^{
                    CGRect r = self.container.frame;
                    r.origin.x = self.leftController.view.frame.size.width+overShootDistance;
                    self.container.frame = r;
                    
                    _currentPosition = ControllerPositionRight;
                    
                };
            } else {
                // pop controller to left exposing right controller
                snap = ^{
                    CGRect r = self.container.frame;
                    r.origin.x = 0 - self.rightController.view.frame.size.width-overShootDistance;
                    self.container.frame = r;
                    
                    _currentPosition = ControllerPositionLeft;
                    
                };
            }
        } else if (_currentPosition == ControllerPositionLeft || _currentPosition == ControllerPositionRight) {
            // pop to middle
            snap = ^{
                CGRect r = self.container.frame;
                r.origin.x = 0 + ( draggingToRight ? overShootDistance : -overShootDistance );
                self.container.frame = r;
                
                _currentPosition = ControllerPositionRegular;
                
            };
        }
    } else {
        snap = ^{
            CGRect r = self.container.frame;
            r.origin.x = _dragOriginPoint.x;
            self.container.frame = r;
        };
    }
    
    

    float duration = .30 - (speed/10000);   // Magic!
    if (duration < .1) {
        duration = .1;
    }

    if (snap) {
        [UIView animateWithDuration:duration delay:0.0 
                            options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionBeginFromCurrentState animations:snap completion:^(BOOL finished) {
                                // if we have a speed value we have overshot our point so animate a snap back
                                if (speed > 0) {
                                    void (^snap)() = nil;
                                    switch (_currentPosition) {
                                        case ControllerPositionRegular:
                                        {
                                            snap = ^{
                                                CGRect r = self.container.frame;
                                                r.origin.x = 0;
                                                self.container.frame = r;
                                                
                                            }; 
                                        }   break;
                                        case ControllerPositionLeft:
                                        {
                                            snap = ^{
                                                CGRect r = self.container.frame;
                                                r.origin.x = 0 - self.rightController.view.frame.size.width;
                                                self.container.frame = r;
                                            };
                                        }   break;
                                        case ControllerPositionRight:
                                        {
                                            snap = ^{
                                                CGRect r = self.container.frame;
                                                r.origin.x = self.leftController.view.frame.size.width;
                                                self.container.frame = r;
                                            };
                                        }   break;
                                    }
                                    
                                    [UIView animateWithDuration:(.75*duration)+(distance/10000) delay:0.0 
                                                        options:UIViewAnimationOptionCurveEaseIn|UIViewAnimationOptionBeginFromCurrentState animations:snap completion:^(BOOL finished) {
                                                        }];
                                    
                                    
                                }
                            }];
    }
     
}

- (void)pushLeftController:(UIViewController *)controller {

    if (controller == nil && _nilSideControllersShouldPopCurrentControllers) {
        // pop this controller to nothing
    } else {
        [super setLeftController:controller];
        // add view and call vc methods and animate it on
        UIView *v = controller.view;
        CGRect r = v.frame;
        r.size.height = self.transitionView.frame.size.height;
        v.frame = r;
        v.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        [self.view insertSubview:v atIndex:0];
        
    }
}
- (void)pushRightController:(UIViewController *)controller {

    if (controller == nil && _nilSideControllersShouldPopCurrentControllers) {
        // pop this controller to nothing
    } else {
        [super setRightController:controller];
        // add view and call vc methods and animate it on
        UIView *v = controller.view;
        CGRect r = v.frame;
        r.origin.x = self.view.frame.size.width-r.size.width;
        r.size.height = self.transitionView.frame.size.height;
        v.frame = r;
        v.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
        [self.view insertSubview:v atIndex:0];
        
    }
}

@end
