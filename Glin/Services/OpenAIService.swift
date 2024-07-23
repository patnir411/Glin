//
//  OpenAIService.swift
//  Glin
//
//  Created by Niral Patel on 7/21/24.
//


import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private var session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration)
    }
    
    func generateSearchTerms(from query: String) async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Given the following user query, generate a list of relevant search terms that would be effective for a full-text search. Return as a JSON object containing a list of strings

        Choose the least possible amount of required search terms.

        ### Example 1
        User query: "Who is the main character in 'To Kill a Mockingbird'?"
        Output: {"terms": ["main", "character", "To Kill a Mockingbird", "Harper Lee"]}

        ### Example 2
        User query: "Themes of love and betrayal in 'Wuthering Heights'"
        Output: {"terms": ["themes", "love", "betrayal", "Wuthering Heights", "Emily Bronte"]}

        ### Example 3
        User query: "Setting of '1984' by George Orwell"
        Output: {"terms": ["setting", "1984", "George Orwell", "dystopian", "London"]}

        ### Example 4
        User query: "Historical context of 'War and Peace'"
        Output: {"terms": ["historical", "context", "War and Peace", "Leo Tolstoy", "Napoleonic Wars"]}

        ### Example 5
        User query: "Magic system in 'Harry Potter' series"
        Output: {"terms": ["magic", "system", "Harry Potter", "J.K. Rowling", "Hogwarts"]}

        User query: \(query)
        """
        
        let messages = [
            ["role": "system", "content": "You are an expert at generating relevant terms for searching about a book based on user queries and returning an object into JSON format."],
            ["role": "user", "content": prompt]
        ]
        
        let parameters: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "response_format": ["type": "json_object"],
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = response.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }
        
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let jsonDictionary = jsonObject as? [String: Any],
              let terms = jsonDictionary["terms"] as? [String] else {
            throw NSError(domain: "InvalidJSONFormat", code: 0, userInfo: nil)
        }
        
        return terms
    }
    
    func generateElaboration(for chunk: String, question: String, relevantChunks: [(String, String)], bookTitle: String, userPreferences: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        The user is interested in \(userPreferences).
        
        Relevant context:
        \(relevantChunks)
        
        Text chunk from \(bookTitle) to which user is asking question:
        \(chunk)
        
        User question: \(question)
        
        
        Provide a detailed answer to the user's question based on the given text chunk and relevant context.
        """
        
        let messages = [
            ["role": "system", "content": "You are an expert in answering questions about document content catered to a user's personal preferences. Take the relevant context and succinctly answer the users question."],
            ["role": "user", "content": prompt]
        ]
        
        let parameters: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 750
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        print("OpenAIService: generating elaboration...")
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "Failed to generate elaboration"
    }
    
    func generateBookInfo(from chunk: String) async throws -> (title: String, gist: String) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Given the following text chunk from a book, generate a suitable title for the book and a brief gist (summary) of its content. Return the result in JSON format with keys "title" and "gist".

        Text chunk:
        \(chunk)
        """
        
        let messages = [
            ["role": "system", "content": "You are an expert at analyzing text and generating concise book titles and summaries in JSON format."],
            ["role": "user", "content": prompt]
        ]
        
        let parameters: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "max_tokens": 200,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = response.choices.first?.message.content,
              let jsonData = content.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let title = json["title"],
              let gist = json["gist"] else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }
        
        return (title: title, gist: gist)
    }
    
    func generateCardSummary(for chunk: String, bookContext: String, userPreferences: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        The following text chunk comes from \(bookContext).
        
        The user is interested in \(userPreferences).
        
        Summarize the following and provide a condensed summary of information that is short enough to fit on a swipable iPhone card:
        
        \(chunk)
        """
        
        let messages = [
            ["role": "system", "content": "You are an expert summarizer and storyteller. For the provided text chunk take the user's preferences, the context of the overall book to which the chunk belongs, and turn it into a comprehensive information card, remaining accurate to the text but emphasizing relevant aspects based on user preferences. Simply go over content, do not mention the title or author again."],
            ["role": "user", "content": prompt]
        ]
        
        let parameters: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        print("OpenAIService: generating card summary...")
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "Failed to generate summary"
    }
    
    func elaborate() async { // TODO: implement
        // Implement the elaborate functionality here
        // This could involve generating a more detailed explanation or allowing for a chat-like interaction
    }
}

struct Message: Codable, Identifiable {
    var id: Int64? = nil
    var role: Role
    var content: String
    var timestamp: String? = "x"
    
    var dictionary: [String: String] {
        ["role": role.rawValue, "content": content]
    }
}

//struct Context: Codable, Hashable {
//    var niralMessage: String
//    var krishnaResponse: String
//    var timestamp: String
//    var rank: Double?
//    
//    var dictionary: [String: String] {
//        ["niralMessage": niralMessage, "krishnaResponse": krishnaResponse, "timestamp": timestamp]
//    }
//}

enum Role: String, Codable {
    case system
    case user
    case assistant
}


struct OpenAIResponse: Codable {
    struct Choice: Codable {
        let message: Message
    }
    let choices: [Choice]
}
