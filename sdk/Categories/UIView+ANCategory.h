/*   Copyright 2013 APPNEXUS INC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <UIKit/UIKit.h>

@interface UIView (ANCategory)

- (void)presentView:(UIView *)view animated:(BOOL)animated;
- (void)presentView:(UIView *)view animated:(BOOL)animated completion:(void (^)(BOOL))completion;

- (void)dismissFromPresentingViewAnimated:(BOOL)animated;

- (void)removeSubviews;
- (void)removeSubviewsWithException:(UIView *)exception;

- (BOOL)an_isViewable;
- (BOOL)an_isAtLeastHalfViewable;

#pragma mark - Autolayout

- (void)constrainWithSize:(CGSize)size;
- (void)constrainWithFrameSize;
- (void)removeSizeConstraint;
- (void)extractWidthConstraint:(NSLayoutConstraint **)widthConstraint
              heightConstraint:(NSLayoutConstraint **)heightConstraint;

- (void)constrainToSizeOfSuperview;
- (void)removeSizeConstraintToSuperview;

- (void)alignToSuperviewWithXAttribute:(NSLayoutAttribute)xAttribute
                            yAttribute:(NSLayoutAttribute)yAttribute;
- (void)alignToSuperviewWithXAttribute:(NSLayoutAttribute)xAttribute
                            yAttribute:(NSLayoutAttribute)yAttribute
                               offsetX:(CGFloat)offsetX
                               offsetY:(CGFloat)offsetY;
- (void)removeAlignmentConstraintsToSuperview;

@end