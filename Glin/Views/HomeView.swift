//
//  HomeView.swift
//  Glin
//
//  Created by Niral Patel on 7/23/24.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack {
            if viewModel.books.isEmpty {
                Text("Upload a PDF to start")
                    .font(.title)
                    .padding()
            } else {
                List(viewModel.books, id: \.id) { book in
                    Button(action: {
                        viewModel.currentBookId = book.id
                    }) {
                        Text(book.title)
                    }
                }
                .navigationTitle("Uploaded Glinskys")
            }
            
            Button(action: { viewModel.isShowingFilePicker = true }) {
                Text("Upload PDF")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}
