//
//  ContentViewModel.swift
//  Glin
//
//  Created by Niral Patel on 7/23/24.
//

import SwiftUI
import PDFKit

class ContentViewModel: ObservableObject {
    @Published var isShowingFilePicker = false
    @Published var books: [Book] = []
    @Published var currentBookId: Int64? = nil {
        didSet {
            if let bookId = currentBookId {
                loadCard(for: bookId, chunkNo: currentChunkNo)
            }
        }
    }
    @Published var currentChunkNo: Int = 0
    @Published var currentCardContent: String?
    @Published var isLoading = true
    @Published var userPreferences: String = "Technical software engineer with a passion for coding. Love learning history and how empires and human civilization rised and fell. The user desires to use his acquired knowledge to change the world for the better."
    
    private let openAIService: OpenAIService
    private let pdfProcessor: PDFProcessor
    
    private let databaseManager = DatabaseManager.shared
    
    init() {
        self.openAIService = OpenAIService(apiKey: APIKeys.openAIKey)
        self.pdfProcessor = PDFProcessor(openAIService: openAIService)
    }
    
    func loadInitialState() {
        loadBooks()
        loadUserPreferences()
        print("Initial state book id is \(String(describing: currentBookId))")
        
        if !books.isEmpty && currentBookId != nil {
            if let bookId = currentBookId {
                loadCard(for: bookId, chunkNo: currentChunkNo)
            }
        } else {
            isLoading = false
        }
    }
    
    func loadBooks() {
        books = databaseManager.getBooks()
    }
    
    func loadUserPreferences() {
        if let savedPreferences = UserDefaults.standard.string(forKey: "userPreferences") {
            userPreferences = savedPreferences
        }
    }
    
    func handleSwipe(_ direction: SwipeDirection) {
        switch direction {
        case .left:
            currentChunkNo += 1
        case .right:
            currentChunkNo = max(0, currentChunkNo - 1)
        }
        if let bookId = currentBookId {
            loadCard(for: bookId, chunkNo: currentChunkNo)
        }
    }
    
    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let files):
            if let file = files.first, file.startAccessingSecurityScopedResource() {
                defer { file.stopAccessingSecurityScopedResource() }
                if let pdfDocument = PDFDocument(url: file) {
                    Task {
                        if let newBookId = await pdfProcessor.processPDF(pdfDocument) {
                            await MainActor.run {
                                self.currentBookId = newBookId
                                self.currentChunkNo = 0
                            }
                        }
                    }
                }
            }
        case .failure(let error):
            print("Error selecting file: \(error.localizedDescription)")
        }
    }
    
    func updateUserPreferences(_ newPreferences: String) {
        self.userPreferences = newPreferences
        UserDefaults.standard.set(userPreferences, forKey: "userPreferences")
    }
    
    func updateCurrentBookId(_ newId: Int64) {
        self.currentBookId = newId
    }
    
    func updateCurrentChunkNo(_ newChunkNo: Int) {
        self.currentChunkNo = newChunkNo
    }
    
    func retryCardGeneration() {
        if let bookId = currentBookId {
            loadCard(for: bookId, chunkNo: currentChunkNo, forceRegenerate: true)
        }
    }
    
    func saveUserPreferences() {
        // Save preferences to UserDefaults or your preferred storage method
        UserDefaults.standard.set(userPreferences, forKey: "userPreferences")
    }
    
    func elaborateContent(question: String) {
        Task {
            do {
                guard currentBookId != nil, let chunk = databaseManager.getChunkContent(bookId: currentBookId!, chunkNo: currentChunkNo),
                      let book = databaseManager.getBook(bookId: currentBookId!) else {
                    print("Failed to retrieve chunk or book data")
                    return
                }
                await MainActor.run {
                    self.isLoading = true
                }
                
                let terms = try await openAIService.generateSearchTerms(from: question)
                let contextChunks = databaseManager.searchContent(searchTerms: terms, bookId: currentBookId!)
                
                let elaboration = try await openAIService.generateElaboration(
                    for: chunk,
                    question: question,
                    relevantChunks: contextChunks,
                    bookTitle: book.title,
                    userPreferences: userPreferences
                )
                
                await MainActor.run {
                    let updatedContent = (currentCardContent ?? "") + "\n\n**Q: " + question + "**\n\n" + elaboration
                    currentCardContent = updatedContent
                    databaseManager.updateChunkSummary(bookId: currentBookId!, chunkNo: currentChunkNo, summary: updatedContent)
                }
            } catch {
                print("Error elaborating content: \(error)")
            }
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func loadCard(for bookId: Int64, chunkNo: Int, forceRegenerate: Bool = false) {
        isLoading = true
        Task {
            print("ContentView loading card for bookId: \(bookId) and chunkNo: \(chunkNo)")
            
            guard let chunk = databaseManager.getChunkContent(bookId: bookId, chunkNo: chunkNo),
                  let book = databaseManager.getBook(bookId: bookId) else {
                print("Failed to retrieve chunk or book data")
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            if !forceRegenerate, let existingSummary = databaseManager.getChunkSummary(bookId: bookId, chunkNo: chunkNo) {
                print("Existing summary exists: \(existingSummary)")
                await MainActor.run {
                    self.currentCardContent = existingSummary
                    self.isLoading = false
                }
                return
            }
            
            if forceRegenerate {
                print("Regenerating card summary...")
            }
            
            do {
                let summary = try await openAIService.generateCardSummary(
                    for: chunk,
                    bookContext: book.title + ": " + book.gist,
                    userPreferences: userPreferences
                )
                
                await MainActor.run {
                    databaseManager.updateChunkSummary(bookId: bookId, chunkNo: chunkNo, summary: summary)
                    self.currentCardContent = summary
                    self.isLoading = false
                }
            } catch {
                print("Error generating card summary: \(error)")
                await MainActor.run {
                    self.currentCardContent = chunk
                    self.isLoading = false
                }
            }
        }
    }
}
