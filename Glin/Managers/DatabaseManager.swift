//
//  DatabaseManager.swift
//  Glin
//
//  Created by Niral Patel on 7/21/24.
//

import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?
    
    private let books = Table("books")
    private let bookId = Expression<Int64>("id")
    private let bookTitle = Expression<String>("title")
    private let bookGist = Expression<String>("book_gist")
    private let totalChunks = Expression<Int>("total_chunks")
    
    private let contents = Table("contents")
    private let contentId = Expression<Int64>("id")
    private let contentBookId = Expression<Int64>("book_id")
    private let chunkNo = Expression<Int>("chunk_no")
    private let chunkContent = Expression<String>("chunk_content")
    private let chunkSummary = Expression<String?>("chunk_summary")
    
    private init() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            db = try Connection("\(path)/glin.sqlite3")
            createTables()
        } catch {
            print("Unable to establish database connection: \(error)")
        }
    }
    
    private func createTables() {
        guard let db = db else { return }
        
        do {
            try db.run(books.create(ifNotExists: true) { t in
                t.column(bookId, primaryKey: .autoincrement)
                t.column(bookTitle)
                t.column(bookGist)
                t.column(totalChunks)
            })
            
            try db.run(contents.create(ifNotExists: true) { t in
                t.column(contentId, primaryKey: .autoincrement)
                t.column(contentBookId)
                t.column(chunkNo)
                t.column(chunkContent)
                t.column(chunkSummary)
                t.foreignKey(contentBookId, references: books, bookId)
            })
        } catch {
            print("Error creating tables: \(error)")
        }
    }
    
    func saveBook(title: String, gist: String, chunks: [String]) -> Int64? {
        guard let db = db else { return nil }
        
        do {
            let bookId = try db.run(books.insert(
                bookTitle <- title,
                bookGist <- gist,
                totalChunks <- chunks.count
            ))
            
            for (index, chunk) in chunks.enumerated() {
                try db.run(contents.insert(
                    contentBookId <- bookId,
                    chunkNo <- index,
                    chunkContent <- chunk
                ))
            }
            
            return bookId
        } catch {
            print("Error saving book: \(error)")
            return nil
        }
    }
    
    func getChunkContent(bookId: Int64, chunkNo: Int) -> String? {
        guard let db = db else { return nil }
        
        do {
            print("(dbService:getChunkContent) Getting chunk number \(chunkNo) of bookId \(bookId)")
            let query = contents.filter(contentBookId == bookId && self.chunkNo == chunkNo)
            if let content = try db.pluck(query) {
                return content[chunkContent]
            }
        } catch {
            print("Error fetching chunk content: \(error)")
        }
        
        return nil
    }
    
    func getBooks() -> [Book] {
        guard let db = db else { return [] }
        do {
            let query = books.order(bookId.desc)
            return try db.prepare(query).map { row in
                Book(
                    id: row[bookId],
                    title: row[bookTitle],
                    gist: row[bookGist],
                    totalChunks: row[totalChunks]
                )
            }
        } catch {
            print("Error fetching books: \(error)")
            return []
        }
    }
    
    func getBook(bookId: Int64) -> Book? {
        guard let db = db else { return nil }
        
        do {
            print("(dbService:getBook) Getting book number \(bookId)")
            let query = books.filter(self.bookId == bookId)
            if let book = try db.pluck(query) {
                return Book(
                    id: book[self.bookId],
                    title: book[bookTitle],
                    gist: book[bookGist],
                    totalChunks: book[totalChunks]
                )
            }
        } catch {
            print("Error fetching book: \(error)")
        }
        
        return nil
    }
    
    func getChunkSummary(bookId: Int64, chunkNo: Int) -> String? {
        guard let db = db else { return nil }
        
        do {
            print("(dbService:getChunkSummary) Getting summary for chunk number \(chunkNo) of bookId \(bookId)")
            let query = contents.filter(contentBookId == bookId && self.chunkNo == chunkNo)
            if let content = try db.pluck(query) {
                return content[chunkSummary]
            }
        } catch {
            print("Error fetching chunk summary: \(error)")
        }
        
        return nil
    }
    
    func updateChunkSummary(bookId: Int64, chunkNo: Int, summary: String) {
        guard let db = db else { return }
        
        do {
            let query = contents.filter(contentBookId == bookId && self.chunkNo == chunkNo)
            try db.run(query.update(chunkSummary <- summary))
            print("(dbService:updateChunkSummary) Updated chunk summary for chunkNo \(chunkNo)")
        } catch {
            print("Error updating chunk summary: \(error)")
        }
    }
}

struct Book {
    let id: Int64
    let title: String
    let gist: String
    let totalChunks: Int
}
