#import <XCTest/XCTest.h>

#include "../../Ring/Bridging/VideoRendererSynchronization.hpp"

namespace {

struct TestRenderer : video_renderer::State {
    TestRenderer(int width, int height, bool hasListeners)
        : State(width, height, hasListeners) {}
};

} // namespace

@interface VideoRendererSynchronizationTests : XCTestCase
@end

@implementation VideoRendererSynchronizationTests

- (void)testStateUpdatesSizeAndStopsAcceptingFramesAfterDeactivation {
    TestRenderer renderer(640, 480, false);

    XCTAssertFalse(renderer.shouldRender());

    renderer.setHasListeners(true);
    renderer.updateSize(1280, 720);

    auto size = renderer.size();
    XCTAssertEqual(size.first, 1280);
    XCTAssertEqual(size.second, 720);
    XCTAssertTrue(renderer.shouldRender());

    renderer.deactivate();
    renderer.setHasListeners(true);

    XCTAssertFalse(renderer.shouldRender());
}

- (void)testRegistryRemovalReturnsAnOwnerUntilCleanupCompletes {
    video_renderer::Registry<TestRenderer> registry;
    auto renderer = std::make_shared<TestRenderer>(640, 480, true);
    std::weak_ptr<TestRenderer> weakRenderer = renderer;

    auto insertion = registry.insertIfAbsent("sink", renderer);
    XCTAssertTrue(insertion.second);
    XCTAssertTrue(insertion.first.get() == renderer.get());

    renderer.reset();
    insertion.first.reset();

    auto removedRenderer = registry.remove("sink");
    XCTAssertTrue(removedRenderer != nullptr);
    XCTAssertTrue(registry.find("sink") == nullptr);
    XCTAssertFalse(weakRenderer.expired());

    removedRenderer.reset();
    XCTAssertTrue(weakRenderer.expired());
}

- (void)testWeakCallbackDoesNothingAfterOwnerIsDestroyed {
    auto renderer = std::make_shared<TestRenderer>(640, 480, true);
    int callbackCount = 0;
    auto callback = video_renderer::makeWeakCallback(
        renderer,
        [&callbackCount](TestRenderer&) { ++callbackCount; });

    callback();
    XCTAssertEqual(callbackCount, 1);

    renderer.reset();
    callback();

    XCTAssertEqual(callbackCount, 1);
}

@end
