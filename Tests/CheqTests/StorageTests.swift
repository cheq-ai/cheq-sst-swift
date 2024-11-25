import XCTest
@testable import Cheq

final class StorageTests: XCTestCase {
    let standardFooValue = "{\"value\":\"bar\"}"
    
    override func setUp() {
        super.setUp()
        Sst.configure(Config("StorageTests"))
        Sst.cookies.clear()
        Sst.localStorage.clear()
        Sst.sessionStorage.clear()
    }
    
    func testContains() {
        XCTAssertFalse(Sst.cookies.contains("foo"))
        XCTAssertFalse(Sst.localStorage.contains("foo"))
        XCTAssertFalse(Sst.sessionStorage.contains("foo"))
    }
    
    func testCookiesAdd() {
        Sst.cookies.add(key: "foo", value: "bar10")
        XCTAssertEqual("bar10", Sst.cookies.get("foo"))
        XCTAssertEqual(standardFooValue, UserDefaults.standard.string(forKey: "foo")!)
        XCTAssertFalse(Sst.localStorage.contains("foo"))
        XCTAssertFalse(Sst.sessionStorage.contains("foo"))
    }
    
    func testlocalStorageAdd() {
        Sst.localStorage.add(key: "foo", value: "bar11")
        XCTAssertEqual("bar11", Sst.localStorage.get("foo"))
        XCTAssertEqual(standardFooValue, UserDefaults.standard.string(forKey: "foo")!)
        XCTAssertFalse(Sst.cookies.contains("foo"))
        XCTAssertFalse(Sst.sessionStorage.contains("foo"))
    }
    
    func testSessionStorageAdd() {
        Sst.sessionStorage.add(key: "foo", value: "bar12")
        XCTAssertEqual("bar12", Sst.sessionStorage.get("foo"))
        XCTAssertEqual(standardFooValue, UserDefaults.standard.string(forKey: "foo")!)
        XCTAssertFalse(Sst.localStorage.contains("foo"))
        XCTAssertFalse(Sst.cookies.contains("foo"))
    }
    
    func testEventData() {
        XCTAssertNil(Sst.cookies.eventData())
        XCTAssertNil(Sst.localStorage.eventData())
        XCTAssertNil(Sst.sessionStorage.eventData())
        
        Sst.cookies.add(key: "foo", value: "bar")
        let cookieEventData = Sst.cookies.eventData()
        XCTAssertEqual(1, cookieEventData?.count)
        XCTAssertEqual("foo", cookieEventData?[0]["name"])
        XCTAssertEqual("bar", cookieEventData?[0]["value"])
        
        Sst.localStorage.add(key: "foo2", value: "bar2")
        let localStorageEventData = Sst.localStorage.eventData()
        XCTAssertEqual(1, localStorageEventData?.count)
        XCTAssertEqual("foo2", localStorageEventData?[0]["key"])
        XCTAssertEqual("bar2", localStorageEventData?[0]["value"])
    }
}
