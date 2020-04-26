//
//  NSAttributedStringContentTypeTests.swift
//  ProtonTests
//
//  Created by Rajdeep Kwatra on 26/4/20.
//  Copyright © 2020 Rajdeep Kwatra. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest

import Proton

class NSAttributedStringContentTypeTests: XCTestCase {
    
    func testEnumerateBlockContent() {
        let text = NSMutableAttributedString()
        let blockText = "[This is a block content1] "
        let panel = PanelView()
        panel.editor.attributedText = NSAttributedString(string: "Text inside panel")
        let attachment = Attachment(panel, size: .fullWidth)
        text.append(NSAttributedString(string: blockText, attributes: [.blockContentType: "block1"]))
        text.append(attachment.string)
        let textField = AutogrowingTextField()
        let inlineAttachment = Attachment(textField, size: .matchContent)
        let inlineString = NSMutableAttributedString(attributedString: inlineAttachment.string)
        inlineString.replaceCharacters(in: .zero, with: NSAttributedString(string: " Inline text ", attributes: [.inlineContentType: "inline1"]))
        inlineString.append(NSAttributedString(string: " Next text ", attributes: [.inlineContentType: "inline2"]))
        text.append(inlineString)

        let contents = Array(text.enumerateContents())
        XCTAssertEqual(contents.count, 3)

        if case let .text(name, attributedString) = contents[0].type {
            XCTAssertEqual(name, EditorContent.Name.paragraph)
            XCTAssertEqual(attributedString.string, blockText)
        } else {
            XCTFail("Expected [text] but found [\(contents[0].type)]")
        }

        if case let .attachment(name, _, view, _) = contents[1].type {
            XCTAssertEqual(name, panel.name)
            XCTAssertTrue(view is PanelView)
        } else {
            XCTFail("Expected [text] but found \(contents[1].type)")
        }

        if case let .text(name, attributedString) = contents[2].type {
            XCTAssertEqual(name, EditorContent.Name.paragraph)
            XCTAssertEqual(attributedString, inlineString)
        } else {
            XCTFail("Expected [text] but found [\(contents[2].type)]")
        }

    }

}
