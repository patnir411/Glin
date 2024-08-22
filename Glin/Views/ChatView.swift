//
//  ChatView.swift
//  Glin
//
//  Created by Niral Patel on 8/2/24.
//

import Foundation
import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var newMessage: String = ""
    
    var body: some View {
        VStack {
            List(viewModel.messages) { message in
                HStack {
                    if message.role == "user" {
                        Spacer()
                        Text(message.content)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    } else {
                        Text(message.content)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Chat")
            
            HStack {
                TextField("Enter your message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 30)
                    .cornerRadius(10)
                
                Button(action: sendMessage) {
                    Text("Send")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
    
    private func sendMessage() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())

        let userMessage = Message(role: "user", content: newMessage)
        viewModel.messages.append(userMessage)
        newMessage = ""

        Task {
            do {
                let seshId = viewModel.currentSessionId!
                // Save the user's message in the session
                viewModel.databaseManager.saveMessage(sessionId: seshId, role: "user", content: userMessage.content, timestamp: timestamp)

                // Generate and save assistant's response
                let terms = try await viewModel.openAIService.generateSearchTerms(from: userMessage.content)
                let contextChunks = viewModel.databaseManager.searchContent(searchTerms: terms, bookId: viewModel.currentBookId)
                let responseTime = dateFormatter.string(from: Date())
                let response = try await viewModel.openAIService.generateResponse(for: userMessage.content, context: contextChunks)
                let botMessage = Message(role: "assistant", content: response)

                viewModel.databaseManager.saveMessage(sessionId: seshId, role: "assistant", content: botMessage.content, timestamp: responseTime)

                await MainActor.run {
                    viewModel.messages.append(botMessage)
                }
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
}
