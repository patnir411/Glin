//
//  SettingsView.swift
//  Glin
//
//  Created by Niral Patel on 7/23/24.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var localUserPreferences: String
    @State private var currentBookIdString: String
    @State private var currentChunkNoString: String
    
    
    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
        self._localUserPreferences = State(initialValue: viewModel.userPreferences)
        self._currentBookIdString = State(initialValue: viewModel.currentBookId != nil ? String(viewModel.currentBookId!) : "")
        self._currentChunkNoString = State(initialValue: String(viewModel.currentChunkNo))
    }
    
    var body: some View {
        Form {
            Section(header: Text("User Preferences")) {
                TextEditor(text: $localUserPreferences)
                    .frame(height: 100)
                    .onChange(of: localUserPreferences) { _, newValue in
                        viewModel.updateUserPreferences(newValue)
                    }
            }
            Section(header: Text("Navigation")) {
                LabeledContent("Book Id:") {
                        TextField("Enter book id", text: $currentBookIdString)
                            .keyboardType(.numberPad)
                            .onChange(of: currentBookIdString) { _, newValue in
                                if let newId = Int64(newValue) {
                                    viewModel.updateCurrentBookId(newId)
                                }
                            }
                    }
                    LabeledContent("Chunk Id:") {
                        TextField("Enter chunk id", text: $currentChunkNoString)
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
