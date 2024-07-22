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
    
    private let databaseManager = DatabaseManager.shared

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration)
    }
    
    func sendMessage(_ content: String) async {
        do { // TODO: set up for the elaborate functionality
//            let userMessage = Message(role: .user, content: content)
//            await MainActor.run {
//                messages.append(userMessage)
//            }
//            
//            let compiledContext = compileContext(from: searchTerms)
//            let contextString = compiledContext.map { "Time: \($0.timestamp)\nUser: \($0.niralMessage)\nKRISHNA: \($0.krishnaResponse)" }.joined(separator: "\n")
//            
//            guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
//                throw NSError(domain: "InvalidURL", code: 0, userInfo: nil)
//            }
//            
//            var request = URLRequest(url: url)
//            request.httpMethod = "POST"
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//            
//            let promptWithContext = """
//            Relevant context snippets from previous conversations:
//            \(contextString)
//            
//            
//            Niral's current message:
//            \(content)
//            """
//            
//            var allMessages = [Prompts.systemPrompt] + messages
//            allMessages[allMessages.count - 1] = Message(role: .user, content: promptWithContext)
//            
//            let parameters: [String: Any] = [
//                "model": "gpt-4o",
//                "messages": allMessages.map { $0.dictionary },
//                "stream": true
//            ]
//
//            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
//            
//
//            let (asyncBytes, _) = try await session.bytes(for: request)
//            for try await line in asyncBytes.lines {
//                await processStreamLine(line)
//            }
//            
//
//            await MainActor.run {
//                if let lastMessage = self.messages.last {
//                    DatabaseService.shared.saveMessage(niral: userMessage, krishna: lastMessage)
//                }
//            }

        } catch {
            print("Error sending message: \(error)")
        }
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
