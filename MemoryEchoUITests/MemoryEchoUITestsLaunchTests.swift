//
//  MemoryEchoUITestsLaunchTests.swift
//  MemoryEchoUITests
//
//  Created by Matt Nitzken on 6/24/26.
//

import XCTest

final class MemoryEchoUITestsLaunchTests: XCTestCase {
    // An override must stay `class` (can't be `static`), so silence the rule here.
    // swiftlint:disable:next static_over_final_class
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
