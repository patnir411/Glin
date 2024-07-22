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
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.books.isEmpty {
                    EmptyStateView(onUploadTapped: { viewModel.isShowingFilePicker = true })
                } else if let content = viewModel.currentCardContent {
                    CardView(content: content, onRetry: {viewModel.retryCardGeneration()})
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width < 0 {
                                        viewModel.handleSwipe(.left)
                                    } else if value.translation.width > 0 {
                                        viewModel.handleSwipe(.right)
                                    }
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
                    // Action here
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

class ContentViewModel: ObservableObject {
    @Published var isShowingFilePicker = false
    @Published var books: [Book] = []
    @Published var currentBookId: Int64 = 1
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
        
        if !books.isEmpty {
            print("Current book id is \(currentBookId)")
            if currentBookId == 0 {
                currentBookId = books.last?.id ?? 1
            }
            loadCard(for: currentBookId, chunkNo: currentChunkNo)
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
        
        loadCard(for: currentBookId, chunkNo: currentChunkNo)
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
                                loadInitialState()
                            }
                        }
                        await MainActor.run {
                            loadInitialState()
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
        loadCard(for: currentBookId, chunkNo: currentChunkNo)
    }
    
    func updateCurrentChunkNo(_ newChunkNo: Int) {
        self.currentChunkNo = newChunkNo
        loadCard(for: currentBookId, chunkNo: currentChunkNo)
    }
    
    func retryCardGeneration() {
        loadCard(for: currentBookId, chunkNo: currentChunkNo, forceRegenerate: true)
    }
    
    func saveUserPreferences() {
        // Save preferences to UserDefaults or your preferred storage method
        UserDefaults.standard.set(userPreferences, forKey: "userPreferences")
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

struct EmptyStateView: View {
    let onUploadTapped: () -> Void
    
    var body: some View {
        VStack {
            Text("Upload a PDF to start")
                .font(.title)
                .padding()
            
            Button(action: onUploadTapped) {
                Text("Upload PDF")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var localUserPreferences: String
    @State private var currentBookIdString: String
    @State private var currentChunkNoString: String
    
    
    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
        self._localUserPreferences = State(initialValue: viewModel.userPreferences)
        self._currentBookIdString = State(initialValue: String(viewModel.currentBookId))
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

struct CardView: View {
    let content: String
    let onRetry: () -> Void
    
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
            VStack {
//                Button("Elaborate") {
//                }
//                .padding(10)
//                .background(Color.blue)
//                .foregroundColor(.white)
//                .cornerRadius(10)
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
    }
}

#Preview {
//    ContentView()
    SettingsView(viewModel: ContentViewModel())
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

