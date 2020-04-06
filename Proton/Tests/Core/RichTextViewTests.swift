//
//  RichTextViewTests.swift
//  ProtonTests
//
//  Created by Rajdeep Kwatra on 4/1/20.
//  Copyright © 2020 Rajdeep Kwatra. All rights reserved.
//

import Foundation
import XCTest
import UIKit

@testable import Proton

class RichTextViewTests: XCTestCase {
    func testGetsAttributeAtLocation() {
        let key = NSAttributedString.Key("test_key")
        let value = "value"
        let viewController = SnapshotTestViewController()
        let textView = RichTextView(frame: .zero, context: RichTextViewContext(), growsInfinitely: true)
        textView.translatesAutoresizingMaskIntoConstraints = false
        let attributedText = NSMutableAttributedString(string: "This is a test string")
        attributedText.addAttributes([key: value], range: NSRange(location: 0, length: 4))

        textView.attributedText = attributedText

        let view = viewController.view!
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ])

        viewController.render()

        // character at index 1
        let point1 = CGPoint(x: 20, y: 10)
        let attribute1 = textView.attributeValue(at: point1, for: key) as? String

        // character at index 8
        let point2 = CGPoint(x: 60, y: 10)
        let attribute2 = textView.attributeValue(at: point2, for: key) as? String

        XCTAssertEqual(attribute1, value)
        XCTAssertNil(attribute2)
    }

    func testResetsTypingAttributesOnDeleteBackwards() throws {
        let text = NSAttributedString(string: "a", attributes: [.foregroundColor: UIColor.blue])
        let textView = RichTextView(context: RichTextViewContext(), growsInfinitely: true)
        textView.attributedText = text
        let preColor = try XCTUnwrap(textView.typingAttributes[.foregroundColor] as? UIColor)
        XCTAssertEqual(preColor, UIColor.blue)
        textView.deleteBackward()
        let postColor = try XCTUnwrap(textView.typingAttributes[.foregroundColor] as? UIColor)
        let typingAttributeColor = try XCTUnwrap(textView.defaultTypingAttributes[.foregroundColor] as? UIColor)
        XCTAssertEqual(postColor, typingAttributeColor)
    }

    func testNotifiesDelegateOfSelectedRangeChanges() {
        let funcExpectation = functionExpectation()
        let textView = RichTextView(context: RichTextViewContext(), growsInfinitely: true)
        let richTextViewDelegate = MockRichTextViewDelegate()
        textView.richTextViewDelegate = richTextViewDelegate
        textView.attributedText = NSAttributedString(string: "This is a test string")
        let rangeToSet = NSRange(location: 5, length: 3)

        richTextViewDelegate.onSelectedRangeChanged = { _, old, new in
            XCTAssertEqual(old, textView.textEndRange)
            XCTAssertEqual(new, rangeToSet)
            funcExpectation.fulfill()
        }
        textView.selectedTextRange = rangeToSet.toTextRange(textInput: textView)
        waitForExpectations(timeout: 1.0)
    }

    func testSetsFocusBeforeForNonFocusableText() {
        let textView = RichTextView(context: RichTextViewContext(), growsInfinitely: true)
        let text = NSMutableAttributedString(string: "0123")
        text.append(NSAttributedString(string: "4567", attributes: [.noFocus: true]))
        text.append(NSAttributedString(string: "890"))
        textView.attributedText = text

        let range = NSRange(location: 5, length: 0).toTextRange(textInput: textView)
        textView.selectedTextRange = range
        XCTAssertEqual(textView.selectedRange, NSRange(location: 4, length: 0))
    }

    func testSetsFocusAfterForNonFocusableText() {
        let textView = RichTextView(context: RichTextViewContext(), growsInfinitely: true)
        let text = NSMutableAttributedString(string: "0123")
        text.append(NSAttributedString(string: "4567", attributes: [.noFocus: true]))
        text.append(NSAttributedString(string: "890"))
        textView.attributedText = text
        textView.selectedTextRange = NSRange(location: 3, length: 0).toTextRange(textInput: textView)
        let range = NSRange(location: 6, length: 0).toTextRange(textInput: textView)
        textView.selectedTextRange = range
        XCTAssertEqual(textView.selectedRange, NSRange(location: 8, length: 0))
    }

    func testInvokesDelegateOnShiftTab() {
        let assertions: ((EditorKey, UIKeyModifierFlags) -> Void) = { key, flags in
            XCTAssertEqual(key, .tab)
            XCTAssertEqual(flags, .shift)
        }
        assertKeyCommand(input: "\t", modifierFlags: .shift, assertions: assertions)
    }

    func testInvokesDelegateOnShiftEnter() {
        let assertions: ((EditorKey, UIKeyModifierFlags) -> Void) = { key, flags in
            XCTAssertEqual(key, .enter)
            XCTAssertEqual(flags, .shift)
        }
        assertKeyCommand(input: "\r", modifierFlags: .shift, assertions: assertions)
    }

    func testInvokesDelegateOnAltEnter() {
        let assertions: ((EditorKey, UIKeyModifierFlags) -> Void) = { key, flags in
            XCTAssertEqual(key, .enter)
            XCTAssertEqual(flags, .alternate)
        }
        assertKeyCommand(input: "\r", modifierFlags: .alternate, assertions: assertions)
    }

    func testInvokesDelegateOnControlEnter() {
        let assertions: ((EditorKey, UIKeyModifierFlags) -> Void) = { key, flags in
            XCTAssertEqual(key, .enter)
            XCTAssertEqual(flags, .control)
        }
        assertKeyCommand(input: "\r", modifierFlags: .control, assertions: assertions)
    }

    private func assertKeyCommand(input: String, modifierFlags: UIKeyModifierFlags, assertions: @escaping ((EditorKey, UIKeyModifierFlags) -> Void), file: StaticString = #file, line: UInt = #line) {
        let funcExpectation = functionExpectation()
        let textView = RichTextView(context: RichTextViewContext(), growsInfinitely: true)
        let richTextViewDelegate = MockRichTextViewDelegate()
        textView.richTextViewDelegate = richTextViewDelegate

        richTextViewDelegate.onKeyReceived = { _, key, flags, _, _  in
            assertions(key, flags)
            funcExpectation.fulfill()
        }

        let command = UIKeyCommand(input: input, modifierFlags: modifierFlags, action: #selector(dummySelector))
        textView.handleKeyCommand(command: command)

        waitForExpectations(timeout: 1.0)
    }

    @objc
    private func dummySelector() { }
}
