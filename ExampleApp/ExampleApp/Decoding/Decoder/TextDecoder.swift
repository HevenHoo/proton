//
//  TextDecoder.swift
//  ExampleApp
//
//  Created by Rajdeep Kwatra on 17/1/20.
//  Copyright © 2020 Rajdeep Kwatra. All rights reserved.
//

import Foundation
import Proton
import UIKit

struct TextDecoder: EditorContentDecoding {
    func decode(mode: EditorContentMode, maxSize: CGSize, value: JSON) -> NSAttributedString {
        let text = value["text"] as? String ?? ""
        let string = NSMutableAttributedString(string: text)
        if let font = value["font"] as? JSON,
            let decoder = EditorContentJSONDecoder.attributeDecoders["font"]
        {
            let attr = decoder.decode(font)
            string.addAttributes(attr, range: string.fullRange)
        }
        return string
    }
}
