// Copyright 2016-2017 Cisco Systems Inc
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import XCTest
@testable import SparkSDK

class MessageTests: XCTestCase {
    
    private let text = "test text"
    private let fileUrl = "https://developer.ciscospark.com/index.html"
    private var fixture: SparkTestFixture! = SparkTestFixture.sharedInstance
    private var other: TestUser!
    private var messages: MessageClient!
    private var roomId: String!
    
    private func getISO8601Date() -> String {
        
        return getISO8601DateWithDate(Date())
    }
    
    private func getISO8601DateWithDate(_ date:Date) -> String {
        let formatter = DateFormatter()
        let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
        formatter.locale = enUSPosixLocale
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
        return formatter.string(from: date)
    }

    
    private func validate(message: Message?) {
        XCTAssertNotNil(message)
        XCTAssertNotNil(message?.messageId)
        XCTAssertNotNil(message?.actor)
        XCTAssertNotNil(message?.conversationId)
        XCTAssertNotNil(message?.publishedDate)
    }
    
    override func setUp() {
        continueAfterFailure = false
        XCTAssertNotNil(fixture)
        if other == nil {
            other = fixture.createUser()
        }
        XCTAssertTrue(registerPhone())
        self.messages = self.fixture.spark.messages
        let room = self.fixture.createRoom(testCase: self, title: "test room")
        XCTAssertNotNil(room?.id)
        self.roomId = room?.conversationId
    }

    override func tearDown() {
        XCTAssertTrue(deregisterPhone())
        if let roomId = roomId {
            fixture.deleteRoom(testCase: self, roomId: roomId)
        }
        
    }
    
    override static func tearDown() {
        Thread.sleep(forTimeInterval: Config.TestcaseInterval)
        super.tearDown()
    }
    
    private func registerPhone() -> Bool {
        let phone = fixture.spark.phone
        var success = false
        let expect = expectation(description: "Phone registration")
        phone.register() { error in
            success = (error == nil)
            expect.fulfill()
        }
        waitForExpectations(timeout: 30) { error in
            XCTAssertNil(error, "Phone registration timed out")
        }
        return success
    }
    
    private func deregisterPhone() -> Bool {
        let phone = fixture.spark.phone
        var success = false
        
        let expect = expectation(description: "Phone deregistration")
        phone.deregister() { error in
            success = (error == nil)
            expect.fulfill()
        }
        waitForExpectations(timeout: 30) { error in
            XCTAssertNil(error, "Phone deregistration timed out")
        }
        
        return success
    }
    
    func testPostingMessageToRoomWithTextReturnsMessage() {
        let message = postMessage(conversationId: roomId, text: text, files:nil)
        validate(message: message)
        XCTAssertEqual(message?.plainText, text)
    }
    
    func testPostingMessageToRoomWithFileReturnsMessage() {
        let file = FileObjectModel(name: "sample.png", localFileUrl: self.generateLocalFile()!)
        let message = postMessage(conversationId: roomId,files: [file])
        validate(message: message)
        XCTAssertNotNil(message?.files)
    }

    func testPostingMessageToRoomWithTextAndFileReturnsMessage() {
        let file = FileObjectModel(name: "sample.png", localFileUrl: self.generateLocalFile()!)
        let message = postMessage(conversationId: roomId, text: text, files: [file])
        validate(message: message)
        XCTAssertEqual(message?.plainText, text)
        XCTAssertNotNil(message?.files)
    }

    func testPostingMessageToInvalidRoomDoesNotReturnMessage() {
        let message = postMessage(conversationId: Config.InvalidId, text: text, files: nil)
        XCTAssertNil(message)
    }

    func testPostingMessageUsingPersonEmailWithTextReturnsMessage() {
        let message = postMessage(personEmail: other.email, text: text, files: nil)
        validate(message: message)
        XCTAssertEqual(message?.plainText, text)
    }

    func testPostingMessageUsingPersonEmailWithFileReturnsMessage() {
        let file = FileObjectModel(name: "sample.png", localFileUrl: self.generateLocalFile()!)
        let message = postMessage(personEmail: other.email, text: "", files: [file])
        validate(message: message)
        XCTAssertNotNil(message?.files)
    }

    func testPostingMessageUsingPersonEmailWithTextAndFileReturnsMessage() {
        let file = FileObjectModel(name: "sample.png", localFileUrl: self.generateLocalFile()!)
        let message = postMessage(personEmail: other.email, text: text, files: [file])
        validate(message: message)
        XCTAssertEqual(message?.plainText, text)
        XCTAssertNotNil(message?.files)
    }
    
    func testPostingMessageUsingInvalidPersonEmailReturnsMessage() {
        if let message = postMessage(personEmail: Config.InvalidEmail, text: text, files: nil){
            XCTAssertNotNil(message)
        }else{
            XCTAssertNil(nil)
        }
        
    }
    
    func testListingMessagesReturnsMessages() {
        let messageArray = listMessages(conversationId: roomId, sinceDate: nil, maxDate: nil, midDate: nil, limit: nil, personRefresh: nil)
        XCTAssertEqual(messageArray?.isEmpty, false)
    }
    
    func testListingMessagesWithMaxValueOf2ReturnsOnly2Messages() {
        _ = postMessage(conversationId: roomId, text: text, files: nil)
        _ = postMessage(conversationId: roomId, text: text, files: nil)
        _ = postMessage(conversationId: roomId, text: text, files: nil)
        let messageArray = listMessages(conversationId: roomId, sinceDate: nil, maxDate: nil, midDate: nil, limit: 2, personRefresh: false)
        XCTAssertEqual(messageArray?.count, 2)
    }
    
    func testListingMessagesBeforeADateReturnsMessagesPostedBeforeThatDate() {
        let message1 = postMessage(conversationId: roomId, text: text, files: nil)
        Thread.sleep(forTimeInterval: 5)
        var nowDate = Date()
        if let createDate = message1?.publishedDate,nowDate > createDate.addingTimeInterval(Config.TestcaseInterval){
                nowDate = createDate.addingTimeInterval(Config.TestcaseInterval)
        }
        let now = getISO8601DateWithDate(nowDate)
        
        let message2 = postMessage(conversationId: roomId, text: text, files: nil)
        let messageArray = listMessages(conversationId: roomId, sinceDate: nil, maxDate: now, midDate: nil, limit: nil, personRefresh: nil)
        XCTAssertEqual(messageArray?.contains() {$0.messageId == message1?.messageId}, true)
        XCTAssertEqual(messageArray?.contains() {$0.messageId == message2?.messageId}, false)
    }
    
    func testListingMessagesBeforeADateAndAMessageIdDoesNotReturnMessageWithThatId() {
        let message = postMessage(conversationId: roomId, text: text, files: nil)
        let now = self.getISO8601Date()
        let messageArray = listMessages(conversationId: roomId, sinceDate: now, maxDate: nil, midDate: nil, limit: nil, personRefresh: nil)
        XCTAssertEqual(messageArray?.contains() {$0.messageId == message?.messageId}, false)
    }
    
    func testListingMessageWithInvalidRoomIdDoesNotReturnMessage() {
        let messageArray = listMessages(conversationId: Config.InvalidId, sinceDate: nil, maxDate: nil, midDate: nil, limit: nil, personRefresh: nil)
        XCTAssertNil(messageArray)
    }
    
    func testGettingMessageReturnsMessage() {
        let messageFromCreate = postMessage(conversationId: roomId, text: text, files: nil)
        validate(message: messageFromCreate)
        if let messageFromCreateId = messageFromCreate?.messageId {
            let messageFromGet = getMessage(messageId: messageFromCreateId)
            validate(message: messageFromGet)
            XCTAssertEqual(messageFromGet?.messageId, messageFromCreate?.messageId)
            XCTAssertEqual(messageFromGet?.plainText, messageFromCreate?.plainText)
        } else {
            XCTFail("Failed to get message")
        }
    }
    
    func testGettingMessageWithInvalidMessageIdFails() {
        let message = getMessage(messageId: Config.InvalidId)
        XCTAssertNil(message)
    }
    
    func testDeletingMessageRemovesMessageAndItCanNoLongerBeRetrieved() {
        let message = postMessage(conversationId: roomId, text: text, files: nil)
        XCTAssertNotNil(message?.messageId)
        let messageId = message?.messageId
        XCTAssertTrue(deleteMessage(messageId: messageId!))
        XCTAssertEqual(getMessage(messageId: messageId!)?.action, MessageAction.tombstone)
    }
    
    func testDeletingMessageWithBadIdFails() {
        XCTAssertFalse(deleteMessage(messageId: Config.InvalidId))
    }
    
    func testSendListDeleteMessage() {
        let message1 = postMessage(conversationId: roomId, text: text, files: nil)
        let message2 = postMessage(conversationId: roomId, text: text, files: nil)
        let message3 = postMessage(conversationId: roomId, text: text, files: nil)
        XCTAssertEqual(message1?.plainText, text)
        XCTAssertEqual(message2?.plainText, text)
        XCTAssertEqual(message3?.plainText, text)
        XCTAssertNil(message3?.files)
        
        let messageArray = listMessages(conversationId: roomId, sinceDate: nil, maxDate: nil, midDate: nil, limit: 3, personRefresh: nil)
        XCTAssertEqual(messageArray?.count, 3)
        
        
        XCTAssertTrue(deleteMessage(messageId: message2!.messageId!))
        let messageArray1 = listMessages(conversationId: roomId, sinceDate: nil, maxDate: nil, midDate: nil, limit: 3, personRefresh: nil)
        XCTAssertEqual(messageArray1?.filter({$0.action != MessageAction.tombstone}).count, 2)
        
        XCTAssertTrue(deleteMessage(messageId: message3!.messageId!))
        let messageArray2 = listMessages(conversationId: roomId, sinceDate: nil, maxDate: nil, midDate: nil, limit: nil, personRefresh: nil)
        XCTAssertEqual(messageArray2?.filter({$0.action == MessageAction.tombstone}).count, 2)
    }
    
    
    private func deleteMessage(messageId: String) -> Bool {
        let request = { (completionHandler: @escaping (ServiceResponse<Message>) -> Void) in
            self.messages.delete(conversationId: self.roomId, messageId: messageId, completionHandler: completionHandler)
        }
        return fixture.getResponse(testCase: self, request: request) != nil
    }
    
    private func postMessage(conversationId: String, text: String, files: [FileObjectModel]?) -> Message? {
        let request = { (completionHandler: @escaping (ServiceResponse<Message>) -> Void) in
            self.messages.post(conversationId: conversationId, content: text, mentions: nil, files: files, queue: nil, uploadProgressHandler: nil, completionHandler: completionHandler)
        }
        return fixture.getResponse(testCase: self, request: request)
    }
    
    private func postMessage(conversationId: String, files: [FileObjectModel]?) -> Message? {
        let request = { (completionHandler: @escaping (ServiceResponse<Message>) -> Void) in
            self.messages.post(conversationId: conversationId, content: nil, mentions: nil, files: files, queue: nil, uploadProgressHandler: nil, completionHandler: completionHandler)
        }
        return fixture.getResponse(testCase: self, request: request)
    }
    
    private func postMessage(personEmail: EmailAddress, text: String, files: [FileObjectModel]?) -> Message? {
        let request = { (completionHandler: @escaping (ServiceResponse<Message>) -> Void) in
            self.messages.post(email: personEmail.toString(), content: text, mentions: nil, files: files, queue: nil, uploadProgressHandler: nil, completionHandler: completionHandler)
        }
        return fixture.getResponse(testCase: self, request: request)
    }
    
    private func postMessage(personEmail: EmailAddress, files: [FileObjectModel]) -> Message? {
        let request = { (completionHandler: @escaping (ServiceResponse<Message>) -> Void) in
            self.messages.post(email: personEmail.toString(), content: nil, mentions: nil, files: files, queue: nil, uploadProgressHandler: nil, completionHandler: completionHandler)
            
        }
        return fixture.getResponse(testCase: self, request: request)
    }
    
    private func listMessages(conversationId: String, sinceDate: String?, maxDate: String?,midDate: String?, limit: Int?,personRefresh: Bool?) -> [Message]? {
        let request = { (completionHandler: @escaping (ServiceResponse<[Message]>) -> Void) in
            self.messages.list(conversationId: conversationId,
                               sinceDate: sinceDate,
                               maxDate: maxDate,
                               midDate: midDate,
                               limit: limit,
                               personRefresh:personRefresh,
                               completionHandler: completionHandler)
        }
        return fixture.getResponse(testCase: self, request: request)
    }
    
    private func getMessage(messageId: String) -> Message? {
        let request = { (completionHandler: @escaping (ServiceResponse<Message>) -> Void) in
            self.messages.get(messageID: messageId, completionHandler: completionHandler)
        }
        return fixture.getResponse(testCase: self, request: request)
    }
    
    private func generateLocalFile() -> String?{
        do {
            let rect = CGRect(x: 0, y: 0, width: 30, height: 30)
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
            UIColor.black.setFill()
            UIRectFill(rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let cgImage = image?.cgImage else{
                return nil
            }
            let resultImg = UIImage(cgImage: cgImage)
            var docURL = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)).last
            docURL = docURL?.appendingPathComponent("sample1.png")
            try UIImagePNGRepresentation(resultImg)?.write(to: docURL!)
            return docURL?.absoluteString
        }catch{
            return nil
        }
    }
}


