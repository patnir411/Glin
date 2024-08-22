//
//  SettingsView.swift
//  Glin
//
//  Created by Niral Patel on 7/23/24.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var summarizerPrompt: String
    @State private var localUserPreferences: String
    @State private var currentChunkNoString: String
    
    
    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
        self._summarizerPrompt = State(initialValue: viewModel.summarizerPrompt)
        self._localUserPreferences = State(initialValue: viewModel.userPreferences)
        self._currentChunkNoString = State(initialValue: String(viewModel.currentChunkNo))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Summarizer Prompt")) {
                TextEditor(text: $summarizerPrompt)
                    .frame(height: 100)
                    .onChange(of: summarizerPrompt) { _, newValue in
                        viewModel.updateSummarizerPrompt(newValue)
                    }
            }
            Section(header: Text("User Preferences")) {
                TextEditor(text: $localUserPreferences)
                    .frame(height: 100)
                    .onChange(of: localUserPreferences) { _, newValue in
                        viewModel.updateUserPreferences(newValue)
                    }
            }
            Section(header: Text("Navigation")) {
                    LabeledContent("Card:") {
                        TextField("Enter card number...", text: $currentChunkNoString)
                            .keyboardType(.numberPad)
                            .onChange(of: currentChunkNoString) { _, newValue in
                                if let newChunkNo = Int(newValue) {
                                    viewModel.updateCurrentChunkNo(newChunkNo)
                                }
                            }
                    }
            }
        }
        .navigationTitle("Settings")
        .onDisappear {
            viewModel.saveUserPreferences()
        }
    }
}
