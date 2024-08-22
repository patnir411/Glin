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
    
    func savePDFToFile(_ pdf: PDFDocument) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileName = UUID().uuidString + ".pdf"
        let pdfFilePath = documentsURL.appendingPathComponent(fileName)
        
        if let data = pdf.dataRepresentation() {
            do {
                try data.write(to: pdfFilePath)
                print("PDF saved to: \(pdfFilePath.path)")
                return fileName // Return only the file name
            } catch {
                print("Error saving PDF to file: \(error)")
            }
        }
        
        return nil
    }
    
    func processPDF(_ pdf: PDFDocument) async -> (Int64?, String?) {
        let pageCount = pdf.pageCount
        var fullText = ""
        for i in 0..<pageCount {
            if let page = pdf.page(at: i),

               let pageContent = page.string {
                fullText += pageContent
            }
        }
        chunks = chunkText(fullText)
        if !chunks.isEmpty, let pdfFileName = savePDFToFile(pdf) {
            let bookId = await saveChunksToBook(chunks, pdfFilePath: pdfFileName)
            return (bookId, pdfFileName)
        } else {
            return (nil, nil)
        }
        
    }
    
    private func chunkText(_ text: String, chunkSize: Int = 10000) -> [String] {
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
    
    private func saveChunksToBook(_ chunks: [String], pdfFilePath: String) async -> Int64? {
        print("(saveChunksToBook): have a total of \(chunks.count) chunks to save, as well as file path \(pdfFilePath)")
        guard let firstChunk = chunks.first else {
            print("No chunks to process")
            return nil
        }
        
        do {
            let (bookTitle, gist) = try await openAIService.generateBookInfo(from: firstChunk)
            
            if let bookId = DatabaseManager.shared.saveBook(title: bookTitle, gist: gist, chunks: chunks, pdfFilePath: pdfFilePath) {
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

