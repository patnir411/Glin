//
//  Models.swift
//  Glin
//
//  Created by Niral Patel on 8/2/24.
//

import Foundation

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        let message: Message
    }
    let choices: [Choice]
}

struct Book {
    let id: Int64
    let title: String
    let gist: String
    let totalChunks: Int
    let pdfFilePath: String?
}

struct Question: Identifiable {
    let id: Int64
    let text: String
    let answer: String
}
struct Message: Codable, Identifiable {
    let id = UUID()
    var role: String
    var content: String
    
    var dictionary: [String: String] {
        ["role": role, "content": content]
    }
}
