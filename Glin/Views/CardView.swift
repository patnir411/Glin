//
//  CardView.swift
//  Glin
//
//  Created by Niral Patel on 7/23/24.
//

import SwiftUI
import MarkdownUI

struct CardView: View {
    let content: String
    let onRetry: () -> Void
    let onElaborate: (String) -> Void
    let onSwipe: (SwipeDirection) -> Void
    
    @State private var showingElaborateAlert = false
    @State private var userQuestion = ""
    
    var body: some View {
        VStack {
            ScrollView {
                Markdown(content)
                    .markdownTextStyle(\.text){
                        ForegroundColor(Color(.systemBackground))
                        BackgroundColor(Color(.label))
                    }
                    .padding(30)
                    
            }
            HStack {
                Button("Elaborate") {
                    showingElaborateAlert = true
                }
                .padding(10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise.circle")
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                .padding(10)
                .background(.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
        .alert("What's on your mind?", isPresented: $showingElaborateAlert) {
            TextField("", text: $userQuestion)
            Button("Submit") {
                onElaborate(userQuestion)
                userQuestion = ""
            }
            Button("Cancel", role: .cancel) {}
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < 0 {
                        onSwipe(.left)
                    } else if value.translation.width > 0 {
                        onSwipe(.right)
                    }
                }
        )
    }
}
