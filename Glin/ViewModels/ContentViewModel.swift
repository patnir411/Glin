//
//  ContentViewModel.swift
//  Glin
//
//  Created by Niral Patel on 7/23/24.
//

import SwiftUI
import PDFKit

enum ImportContext {
    case existingUpload
    case newUpload
}

class ContentViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var messages: [Message] = []
    @Published var currentBookId: Int64? = nil {
        didSet {
            if let bookId = currentBookId {
                loadPDF(for: bookId)
                loadCardView(for: bookId, chunkNo: currentChunkNo)
            }
        }
    }
    @Published var currentSessionId: Int64? = nil
    @Published var currentChunkNo: Int = 0
    @Published var currentCardContent: String?
    @Published var summarizerPrompt: String = "You are an expert text condenser. Your task is to extract the key points, important takeaways, and relevant passages from the text below, considering the user’s background. Provide a concise, comprehensive summary using markdown text formatting to format the text. Do not include any introductory phrases like ‘this text is about’ or ‘this is relevant because.’ Present the summary as if it were speaking directly from the book, maintaining the tone, structure, style, and wisdom of the book itself, as if the book is speaking directly to the user. The point of view is that of the book speaking to the user. Then add one final section of notable passages and include them in blockquotes."
    @Published var userPreferences: String = "Technical software engineer coder."
    @Published var currentView: ViewType = .home
    @Published var isShowingFilePicker = false
    @Published var currentPDFFilePath: String? = nil
    
    
    enum ViewType {
        case home, card, chat, loading
    }
    
    let openAIService: OpenAIService
    let pdfProcessor: PDFProcessor
    
    let databaseManager = DatabaseManager.shared
    
    init() {
        self.openAIService = OpenAIService(apiKey: APIKeys.openAIKey)
        self.pdfProcessor = PDFProcessor(openAIService: openAIService)
        self.books = self.databaseManager.getBooks()
    }
    
    func loadInitialState() {
        loadUserPreferences()
        print("Initial state book id is \(String(describing: currentBookId))")
    }

    func loadPDF(for bookId: Int64) {
        if let book = databaseManager.getBook(bookId: bookId),
           let pdfFileName = book.pdfFilePath {
        print("loadPDF retrieved file name: \(pdfFileName)")
        self.currentPDFFilePath = pdfFileName
        }
    }
    
    func loadChatView(for sessionId: Int64) {
        self.currentView = .loading
        Task {
            let messages = databaseManager.getMessagesFromSession(sessionId: sessionId)
            await MainActor.run {
                self.messages = messages
                self.currentView = .chat
            }
        }
    }
    
    func loadUserPreferences() {
        if let savedPreferences = UserDefaults.standard.string(forKey: "userPreferences") {
            self.userPreferences = savedPreferences
        }
    }
    
    func handleSwipe(_ direction: SwipeDirection) {
        switch direction {
        case .left:
            self.currentChunkNo += 1
        case .right:
            self.currentChunkNo = max(0, currentChunkNo - 1)
        }
        if let bookId = currentBookId {
            loadCardView(for: bookId, chunkNo: currentChunkNo)
        }
    }

    func updatePDFFileName(for bookId: Int64?, with filePath: String) {
        guard let bookId = bookId else {
            print("No current book ID available to update PDF file path")
            return
        }
        print("updating file path for bookid: \(bookId). File path is \(filePath)")
        databaseManager.updatePDFFileName(for: bookId, fileName: filePath)
        self.currentPDFFilePath = filePath
    }
    
    func handleFileImport(_ result: Result<[URL], Error>, context: ImportContext) {
        switch result {
        case .success(let files):
            if let file = files.first, file.startAccessingSecurityScopedResource() {
                defer { file.stopAccessingSecurityScopedResource() }
                if let pdfDocument = PDFDocument(url: file) {
                    self.currentView = .loading
                    Task {
                        if context == .existingUpload {
                            print("(handleFileImport): in cardview context!")
                            if let savedFileName = pdfProcessor.savePDFToFile(pdfDocument) {
                                updatePDFFileName(for: currentBookId, with: savedFileName)
                            }
                        } else if context == .newUpload {
                            print("(handleFileImport): in newbook context!")
                            let (newBookId, newBookFilePath) = await pdfProcessor.processPDF(pdfDocument)
                            if let id = newBookId, let filePath = newBookFilePath {
                                print("(handleFileImport): created bookId \(id) with filePath \(filePath)")
                                self.currentChunkNo = 0
                                self.currentBookId = id
                                self.currentPDFFilePath = filePath
                            }
                        }
                        await MainActor.run {
                            self.books = self.databaseManager.getBooks() // reload books
                            self.currentView = .card
                        }
                    }
                }
            }
        case .failure(let error):
            print("Error selecting file: \(error.localizedDescription)")
        }
    }

    private func savePDFToNewFile(_ url: URL) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let pdfFilePath = documentsURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        do {
            try fileManager.copyItem(at: url, to: pdfFilePath)
            return pdfFilePath.path
        } catch {
            print("Error saving PDF to file: \(error)")
            return nil
        }
    }
    
    func updateSummarizerPrompt(_ newPrompt: String) {
        self.summarizerPrompt = newPrompt
    }
    
    func updateUserPreferences(_ newPreferences: String) {
        self.userPreferences = newPreferences
        UserDefaults.standard.set(userPreferences, forKey: "userPreferences")
    }
    
    func updateCurrentChunkNo(_ newChunkNo: Int) {
        self.currentChunkNo = newChunkNo
    }
    
    func retryCardGeneration() {
        if let bookId = currentBookId {
            loadCardView(for: bookId, chunkNo: currentChunkNo, forceRegenerate: true)
        }
    }
    
    func saveUserPreferences() {
        // Save preferences to UserDefaults or your preferred storage method
        UserDefaults.standard.set(userPreferences, forKey: "userPreferences")
    }
    

    func loadCardView(for bookId: Int64, chunkNo: Int, forceRegenerate: Bool = false) {
        self.currentView = .loading
        Task {
            print("ContentView loading card for bookId: \(bookId) and chunkNo: \(chunkNo)")
            
            guard let chunk = databaseManager.getChunkContent(bookId: bookId, chunkNo: chunkNo),
                  let book = databaseManager.getBook(bookId: bookId) else {
                print("Failed to retrieve chunk or book data")
                return
            }
            
            if !forceRegenerate, let existingSummary = databaseManager.getChunkSummary(bookId: bookId, chunkNo: chunkNo) {
                print("Existing summary exists: \(existingSummary)")
                await MainActor.run {
                    self.currentCardContent = existingSummary
                    self.currentView = .card
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
                    userPreferences: userPreferences,
                    summarizerPrompt: summarizerPrompt
                )
                
                await MainActor.run {
                    self.currentView = .loading
                    databaseManager.updateChunkSummary(bookId: bookId, chunkNo: chunkNo, summary: summary)
                    self.currentCardContent = summary
                    self.currentView = .card
                }
            } catch {
                print("Error generating card summary: \(error)")
                await MainActor.run {
                    self.currentCardContent = chunk
                }
            }
        }
    }

}
