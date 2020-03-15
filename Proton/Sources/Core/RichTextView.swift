//
//  RichTextView.swift
//  Proton
//
//  Created by Rajdeep Kwatra on 4/1/20.
//  Copyright © 2020 Rajdeep Kwatra. All rights reserved.
//

import Foundation
import UIKit

class RichTextView: AutogrowingTextView {
    private let storage = TextStorage()

    weak var richTextViewDelegate: RichTextViewDelegate?

    weak var defaultTextFormattingProvider: DefaultTextFormattingProviding? {
        get { storage.defaultTextFormattingProvider }
        set { storage.defaultTextFormattingProvider = newValue }
    }

    private let placeholderLabel = UILabel()

    var placeholderText: NSAttributedString? {
        didSet {
            placeholderLabel.attributedText = placeholderText
        }
    }

    var defaultTypingAttributes: RichTextAttributes {
        [
            .font: defaultTextFormattingProvider?.font ?? storage.defaultFont,
            .paragraphStyle: defaultTextFormattingProvider?.paragraphStyle ?? storage.defaultParagraphStyle,
            .foregroundColor: defaultTextFormattingProvider?.textColor ?? storage.defaultTextColor,
        ]
    }

    init(frame: CGRect = .zero, context: RichTextViewContext) {
        let textContainer = TextContainer()
        let layoutManager = NSLayoutManager()

        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)

        super.init(frame: frame, textContainer: textContainer)
        layoutManager.delegate = self
        textContainer.textView = self
        delegate = context

        backgroundColor = .systemBackground
        textColor = .label

        setupPlaceholder()
    }

    var richTextStorage: TextStorage {
        storage
    }

    var contentLength: Int {
        storage.length
    }

    weak var textProcessor: TextProcessor? {
        didSet {
            storage.delegate = textProcessor
        }
    }

    var textEndRange: NSRange {
        storage.textEndRange
    }

    var currentLineRange: NSRange? {
        lineRange(from: selectedRange.location)
    }

    var visibleRange: NSRange {
        let textBounds = bounds.inset(by: textContainerInset)
        return layoutManager.glyphRange(forBoundingRect: textBounds, in: textContainer)
    }

    @available(*, unavailable, message: "init(coder:) unavailable, use init")
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if targetEnvironment(macCatalyst)
        @objc(_focusRingType)
        var focusRingType: UInt {
            1 // NSFocusRingTypeNone
        }
    #endif

    private func setupPlaceholder() {
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.numberOfLines = 0
        placeholderLabel.lineBreakMode = .byTruncatingTail

        addSubview(placeholderLabel)
        placeholderLabel.attributedText = placeholderText
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: textContainerInset.top),
            placeholderLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -textContainerInset.bottom),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textContainer.lineFragmentPadding),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -textContainer.lineFragmentPadding),
            placeholderLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -textContainer.lineFragmentPadding),
        ])
    }

    func wordAt(_ location: Int) -> NSAttributedString? {
        guard let position = self.position(from: beginningOfDocument, offset: location),
            let wordRange = tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)),
            let range = wordRange.toNSRange(in: self) else {
            return nil
        }
        return attributedText.attributedSubstring(from: range)
    }

    func lineRange(from location: Int) -> NSRange? {
        var currentLocation = location
        guard contentLength > 0 else { return .zero }
        var range = NSRange()
        // In case this is called before layout has completed, e.g. from TextProcessor, the last entered glyph
        // will not have been laid out by layoutManager but would be present in TextStorage. It can also happen
        // when deleting multiple characters where layout is pending in the same case. Following logic finds the
        // last valid glyph that is already laid out.
        while currentLocation > 0, layoutManager.isValidGlyphIndex(currentLocation) == false {
            currentLocation -= 1
        }
        guard layoutManager.isValidGlyphIndex(currentLocation) else { return NSRange(location: 0, length: 1) }
        layoutManager.lineFragmentUsedRect(forGlyphAt: currentLocation, effectiveRange: &range)
        guard range.location != NSNotFound else { return nil }
        // As mentioned above, in case of this getting called before layout is completed,
        // we need to account for the range that has been changed. storage.changeInLength provides
        // the change that might not have been laid already
        return NSRange(location: range.location, length: range.length + storage.changeInLength)
    }

    func invalidateLayout(for range: NSRange) {
        layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
    }

    func invalidateDisplay(for range: NSRange) {
        layoutManager.invalidateDisplay(forCharacterRange: range)
    }

    override func deleteBackward() {
        super.deleteBackward()
        guard contentLength == 0 else {
            return
        }
        typingAttributes = defaultTypingAttributes
    }

    func insertAttachment(in range: NSRange, attachment: Attachment) {
        richTextStorage.insertAttachment(in: range, attachment: attachment)
        if let rangeInContainer = attachment.rangeInContainer() {
            edited(range: rangeInContainer)
        }
        scrollRangeToVisible(NSRange(location: range.location, length: 1))
    }

    func edited(range: NSRange) {
        richTextStorage.beginEditing()
        richTextStorage.edited([.editedCharacters, .editedAttributes], range: range, changeInLength: 0)
        richTextStorage.endEditing()
    }

    func transformContents<T: EditorContentEncoding>(in range: NSRange? = nil, using transformer: T) -> [T.EncodedType] {
        contents(in: range).compactMap(transformer.encode)
    }

    func replaceCharacters(in range: NSRange, with attrString: NSAttributedString) {
        richTextStorage.replaceCharacters(in: range, with: attrString)
        updatePlaceholderVisibility()
    }

    func replaceCharacters(in range: NSRange, with string: String) {
        // Delegate to function with attrString so that default attributes are automatically applied
        richTextStorage.replaceCharacters(in: range, with: NSAttributedString(string: string))
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.attributedText = attributedText.length == 0 ? placeholderText : NSAttributedString()
    }

    func attributeValue(at location: CGPoint, for attribute: NSAttributedString.Key) -> Any? {
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        guard characterIndex < textStorage.length else {
            return nil
        }

        let attributes = textStorage.attributes(at: characterIndex, longestEffectiveRange: nil, in: textStorage.fullRange)
        return attributes[attribute]
    }

    func boundingRect(forGlyphRange range: NSRange) -> CGRect {
        layoutManager.boundingRect(forGlyphRange: range, in: textContainer)
    }

    func contents(in range: NSRange? = nil) -> AnySequence<EditorContent> {
        attributedText.enumerateContents(in: range)
    }

    func addAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange) {
        storage.addAttributes(attrs, range: range)
    }

    func removeAttributes(_ attrs: [NSAttributedString.Key], range: NSRange) {
        storage.removeAttributes(attrs, range: range)
    }

    func enumerateAttribute(_ attrName: NSAttributedString.Key, in enumerationRange: NSRange, options opts: NSAttributedString.EnumerationOptions = [], using block: (Any?, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void) {
        storage.enumerateAttribute(attrName, in: enumerationRange, options: opts, using: block)
    }

    func rangeOfCharacter(at point: CGPoint) -> NSRange? {
        characterRange(at: point)?.toNSRange(in: self)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        if let touch = touches.first {
            let position = touch.location(in: self)
            didTap(at: position)
        }
    }

    func didTap(at location: CGPoint) {
        let characterRange = rangeOfCharacter(at: location)
        richTextViewDelegate?.richTextView(self, didTapAtLocation: location, characterRange: characterRange)
    }
}

extension RichTextView: NSLayoutManagerDelegate {
    func layoutManager(_: NSLayoutManager, didCompleteLayoutFor _: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        updatePlaceholderVisibility()
        richTextViewDelegate?.richTextView(self, didFinishLayout: layoutFinishedFlag)
    }
}
