//
//  PDFProcessor.swift
//  Glin
//
//  Created by Niral Patel on 7/21/24.
//

import Foundation
import PDFKit

class PDFProcessor: ObservableObject {
    @Published var chunks: [String] = []
    private let openAIService: OpenAIService
    
    init(openAIService: OpenAIService) {
        self.openAIService = openAIService
    }
    
    func processPDF(_ pdf: PDFDocument) async -> Int64? {
        let pageCount = pdf.pageCount
        var fullText = ""
        for i in 0..<pageCount {
            if let page = pdf.page(at: i),
               let pageContent = page.string {
                fullText += pageContent
            }
        }
        
        chunks = chunkText(fullText)
        return await saveChunksToBook(chunks)
    }
    
    private func chunkText(_ text: String) -> [String] {
        let chunkSize = 10000 // Adjust as needed
        var chunks: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[currentIndex..<endIndex])
            chunks.append(chunk)
            currentIndex = endIndex
        }
        
        return chunks
    }
    
    private func saveChunksToBook(_ chunks: [String]) async -> Int64? {
        guard let firstChunk = chunks.first else {
            print("No chunks to process")
            return nil
        }
        
        do {
            let (bookTitle, gist) = try await openAIService.generateBookInfo(from: firstChunk)
            
            if let bookId = DatabaseManager.shared.saveBook(title: bookTitle, gist: gist, chunks: chunks) {
                print("saveChunksToBook complete for book ID: \(bookId)")
                self.chunks = chunks
                return bookId
            } else {
                print("Failed to save book")
            }
        } catch {
            print("Error generating book info: \(error)")
        }
        return nil
    }
}

