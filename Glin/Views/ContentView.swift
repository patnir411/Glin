//
//  ContentView.swift
//  Glin
//
//  Created by Niral Patel on 7/21/24.
//

import SwiftUI
import MarkdownUI
import PDFKit

enum SwipeDirection {
    case left, right
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.currentBookId == nil {
                    HomeView(viewModel: viewModel)
                } else if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let content = viewModel.currentCardContent {
                    CardView(
                        content: content,
                        onRetry: { viewModel.retryCardGeneration() },
                        onElaborate: { question in
                            viewModel.elaborateContent(question: question)
                        },
                        onSwipe: { direction in
                            viewModel.handleSwipe(direction)
                        }
                    )
                } else {
                    Text("No card available")
                }
            }
            .navigationTitle("Glin")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $viewModel.isShowingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileImport(result)
            }
            .onAppear(perform: viewModel.loadInitialState)
            .navigationBarItems(leading:
                Button(action: {
                viewModel.currentBookId = nil
            }) {
                    Image(systemName: "house")
                },
                trailing:
                HStack {
                    Button(action: {
                        viewModel.isShowingFilePicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                    NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                        Image(systemName: "gear")
                    }
                }
            )
        }
    }
}




#Preview {
    ContentView()
//    SettingsView(viewModel: ContentViewModel())
//    CardView(content: """
//### MASTERY by Robert Greene
//
//**Overview:**
//"Mastery" explores the paths to success by examining influential figures like Charles Darwin and contemporary leaders, emphasizing the significance of learning from the greats to achieve mastery in your own life.
//
//**Key Concepts:**
//1. **Definition of Mastery:** Mastery is a form of higher intelligence developed through dedicated learning and practice.
//2. **Three Phases of Mastery:**
//   - **Discover Your Calling:** Understand your inner inclinations and find your Life’s Task, aligning your career with your true self.
//   - **Ideal Apprenticeship:** Undergo a second education where you learn practical skills and discipline through observation, practice, and experimentation.
//   - **Mentor Dynamic:** Seek out mentors who resonate with your path, leverage their knowledge, and eventually surpass them.
//
//**Strategies for Mastery:**
//- **Discover Your Calling:**
//  - Know your unique inclinations and vocational goals.
//  - Return to your origins for insights into your true passions.
//  
//- **Ideal Apprenticeship:**
//  - Value learning over financial gain.
//  - Expand your horizons and embrace challenges.
//
//- **Mentor Dynamic:**
//  - Choose mentors aligned with your goals.
//  - Engage in deep, reciprocal relationships for maximum growth.
//
//**Social Intelligence:**
//Understand the emotional dynamics in relationships to navigate challenges effectively, freeing up energy for your mastery pursuits.
//
//**Creative Mindset:**
//Develop a "Dimensional Mind" that seeks cross-disciplinary knowledge, enabling unique creative expressions and innovations.
//
//**Relevance for Technical Engineers:**
//The lessons from "Mastery" suggest that by studying and emulating the paths of historic figures, engineers can enhance their technical skills and cultivate a mindset conducive to innovation and excellence.
//""")
}

