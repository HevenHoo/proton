//
//  RichTextViewContext.swift
//  Proton
//
//  Created by Rajdeep Kwatra on 7/1/20.
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
import UIKit
import CoreServices

class RichTextEditorContext: RichTextViewContext {
    static let `default` = RichTextEditorContext()

    func textViewDidBeginEditing(_ textView: UITextView) {
        activeTextView = textView as? RichTextView
        guard let richTextView = activeTextView else { return }
        activeTextView?.richTextViewDelegate?.richTextView(richTextView, didReceiveFocusAt: textView.selectedRange)

        let range = textView.selectedRange
        var attributes = richTextView.typingAttributes
        let contentType = attributes[.blockContentType] as? EditorContent.Name ?? .unknown
        attributes[.blockContentType] = nil
        richTextView.richTextViewDelegate?.richTextView(richTextView, didChangeSelection: range, attributes: attributes, contentType: contentType)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        defer {
            activeTextView = nil
        }
        guard let richTextView = activeTextView else { return }
        activeTextView?.richTextViewDelegate?.richTextView(richTextView, didLoseFocusFrom: textView.selectedRange)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let richTextView = activeTextView else { return true }

        // if backspace
        var handled = false
        if text.isEmpty {
            richTextView.richTextViewDelegate?.richTextView(richTextView, didReceiveKey: .backspace, modifierFlags: [], at: range, handled: &handled)

            guard handled == false else {
                return false
            }

            let substring = textView.attributedText.attributedSubstring(from: range)
            guard substring.length > 0,
                let attachment = substring.attribute(.attachment, at: 0, effectiveRange: nil) as? Attachment,
                attachment.selectBeforeDelete else {
                    return true
            }

            if attachment.isSelected {
                return true
            } else {
                attachment.isSelected = true
                return false
            }
        }

        if text == "\n" {
            richTextView.richTextViewDelegate?.richTextView(richTextView, didReceiveKey: .enter, modifierFlags: [], at: range, handled: &handled)

            guard handled == false else {
                return false
            }
        }

        if text == "\t" {
            richTextView.richTextViewDelegate?.richTextView(richTextView, didReceiveKey: .tab, modifierFlags: [], at: range, handled: &handled)

            guard handled == false else {
                return false
            }
        }

        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let richTextView = activeTextView else { return }
        richTextView.richTextViewDelegate?.richTextView(richTextView, didChangeTextAtRange: textView.selectedRange)
    }
}
