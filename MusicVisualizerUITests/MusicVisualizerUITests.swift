//
//  MusicVisualizerUITests.swift
//  MusicVisualizerUITests
//
//  Created by Matvey Kostukovsky on 7/19/25.
//

import XCTest

final class MusicVisualizerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Simple test to verify app launches successfully
        XCTAssertTrue(app.exists)
    }

}
