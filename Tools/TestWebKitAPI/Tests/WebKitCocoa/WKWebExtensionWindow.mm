/*
 * Copyright (C) 2023-2024 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"

#if ENABLE(WK_WEB_EXTENSIONS)

#import "TestCocoa.h"
#import "TestWebExtensionsDelegate.h"
#import "WebExtensionUtilities.h"
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionContextPrivate.h>
#import <WebKit/WKWebExtensionControllerPrivate.h>
#import <WebKit/WKWebExtensionMatchPatternPrivate.h>
#import <WebKit/WKWebExtensionPermission.h>
#import <WebKit/WKWebExtensionPrivate.h>
#import <WebKit/WKWebExtensionWindow.h>

namespace TestWebKitAPI {

TEST(WKWebExtensionWindow, OpenWindows)
{
    auto testExtensionOne = adoptNS([[WKWebExtension alloc] _initWithManifestDictionary:@{ @"manifest_version": @3 }]);
    auto testContextOne = adoptNS([[WKWebExtensionContext alloc] initForExtension:testExtensionOne.get()]);

    auto testExtensionTwo = adoptNS([[WKWebExtension alloc] _initWithManifestDictionary:@{ @"manifest_version": @3 }]);
    auto testContextTwo = adoptNS([[WKWebExtensionContext alloc] initForExtension:testExtensionTwo.get()]);

    auto testWindowOne = adoptNS([[TestWebExtensionWindow alloc] init]);
    auto testWindowTwo = adoptNS([[TestWebExtensionWindow alloc] init]);

    auto *openWindows = @[ testWindowOne.get(), testWindowTwo.get() ];
    auto *reversedOpenWindows = @[ testWindowTwo.get(), testWindowOne.get() ];

    auto controllerDelegate = adoptNS([[TestWebExtensionsDelegate alloc] init]);

    controllerDelegate.get().openWindows = ^NSArray<id<WKWebExtensionWindow>> *(WKWebExtensionContext *context) {
        return context == testContextOne ? openWindows : reversedOpenWindows;
    };

    auto testController = adoptNS([[WKWebExtensionController alloc] init]);
    testController.get().delegate = controllerDelegate.get();

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, @[ ]);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, @[ ]);

    [testController loadExtensionContext:testContextOne.get() error:nullptr];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, openWindows);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, @[ ]);

    [testController loadExtensionContext:testContextTwo.get() error:nullptr];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, openWindows);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, reversedOpenWindows);

    [testContextOne didFocusWindow:testWindowTwo.get()];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, reversedOpenWindows);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, reversedOpenWindows);

    [testContextOne didFocusWindow:testWindowOne.get()];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, openWindows);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, reversedOpenWindows);

    [testController didFocusWindow:testWindowOne.get()];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, openWindows);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, openWindows);

    [testController unloadExtensionContext:testContextOne.get() error:nullptr];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, @[ ]);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, openWindows);

    [testController didFocusWindow:testWindowTwo.get()];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, @[ ]);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, reversedOpenWindows);

    [testController didCloseWindow:testWindowTwo.get()];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, @[ ]);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, @[ testWindowOne.get() ]);

    [testController didOpenWindow:testWindowTwo.get()];

    EXPECT_NS_EQUAL(testContextOne.get().openWindows, @[ ]);
    EXPECT_NS_EQUAL(testContextTwo.get().openWindows, reversedOpenWindows);
}

TEST(WKWebExtensionWindow, FocusedWindow)
{
    auto testExtensionOne = adoptNS([[WKWebExtension alloc] _initWithManifestDictionary:@{ @"manifest_version": @3 }]);
    auto testContextOne = adoptNS([[WKWebExtensionContext alloc] initForExtension:testExtensionOne.get()]);

    auto testExtensionTwo = adoptNS([[WKWebExtension alloc] _initWithManifestDictionary:@{ @"manifest_version": @3 }]);
    auto testContextTwo = adoptNS([[WKWebExtensionContext alloc] initForExtension:testExtensionTwo.get()]);

    auto testWindowOne = adoptNS([[TestWebExtensionWindow alloc] init]);
    auto testWindowTwo = adoptNS([[TestWebExtensionWindow alloc] init]);

    auto controllerDelegate = adoptNS([[TestWebExtensionsDelegate alloc] init]);

    controllerDelegate.get().openWindows = ^NSArray<id<WKWebExtensionWindow>> *(WKWebExtensionContext *context) {
        return @[ testWindowOne.get(), testWindowTwo.get() ];
    };

    controllerDelegate.get().focusedWindow = ^id<WKWebExtensionWindow> (WKWebExtensionContext *context) {
        return context == testContextOne ? testWindowTwo.get() : nil;
    };

    auto testController = adoptNS([[WKWebExtensionController alloc] init]);
    testController.get().delegate = controllerDelegate.get();

    EXPECT_NULL(testContextOne.get().focusedWindow);
    EXPECT_NULL(testContextTwo.get().focusedWindow);

    [testController loadExtensionContext:testContextOne.get() error:nullptr];

    EXPECT_NS_EQUAL(testContextOne.get().focusedWindow, testWindowTwo.get());
    EXPECT_NULL(testContextTwo.get().focusedWindow);

    [testController loadExtensionContext:testContextTwo.get() error:nullptr];

    EXPECT_NS_EQUAL(testContextOne.get().focusedWindow, testWindowTwo.get());
    EXPECT_NULL(testContextTwo.get().focusedWindow);

    [testContextOne didFocusWindow:testWindowOne.get()];

    EXPECT_NS_EQUAL(testContextOne.get().focusedWindow, testWindowOne.get());
    EXPECT_NULL(testContextTwo.get().focusedWindow);

    [testContextOne didFocusWindow:nil];

    EXPECT_NULL(testContextOne.get().focusedWindow);
    EXPECT_NULL(testContextTwo.get().focusedWindow);

    [testController didFocusWindow:testWindowOne.get()];

    EXPECT_NS_EQUAL(testContextOne.get().focusedWindow, testWindowOne.get());
    EXPECT_NS_EQUAL(testContextTwo.get().focusedWindow, testWindowOne.get());

    [testController unloadExtensionContext:testContextOne.get() error:nullptr];

    EXPECT_NULL(testContextOne.get().focusedWindow);
    EXPECT_NS_EQUAL(testContextTwo.get().focusedWindow, testWindowOne.get());

    [testController didFocusWindow:testWindowTwo.get()];

    EXPECT_NULL(testContextOne.get().focusedWindow);
    EXPECT_NS_EQUAL(testContextTwo.get().focusedWindow, testWindowTwo.get());

    [testController didCloseWindow:testWindowTwo.get()];

    EXPECT_NULL(testContextOne.get().focusedWindow);
    EXPECT_NULL(testContextTwo.get().focusedWindow);
}

} // namespace TestWebKitAPI

#endif // ENABLE(WK_WEB_EXTENSIONS)
