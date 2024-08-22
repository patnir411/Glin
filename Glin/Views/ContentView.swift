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
                if viewModel.currentView == .home {
                    HomeView(viewModel: viewModel)
                } else if viewModel.currentView == .chat {
                    ChatView(viewModel: viewModel)
                } else if viewModel.currentView == .loading {
                    ProgressView("Loading...")
                } else if viewModel.currentView == .card {
                    CardView(
                        viewModel: viewModel,
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
            ) {
                result in
                if viewModel.currentView == .card {
                    viewModel.handleFileImport(result, context: .existingUpload)
                } else {
                    viewModel.handleFileImport(result, context: .newUpload)
                }
            }
            .navigationBarItems(leading:
                Button(action: {
                viewModel.currentView = .home
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




#Preview("ContentView") {
    ContentView()
}

#Preview("Settings") {
    SettingsView(viewModel: ContentViewModel())
}
