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
    private let contentsFTS = VirtualTable("contents_fts")
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
            populateFTSTable()
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
            try db.run("CREATE VIRTUAL TABLE IF NOT EXISTS contents_fts USING fts5(content_id, book_id, chunk_no, chunk_content)")
        } catch {
            print("Error creating tables: \(error)")
        }
    }
    
    func populateFTSTable() {
        guard let db = db else { return }
        
        do {
            
            // Check if the FTS table is empty
            let count = try db.scalar("SELECT COUNT(*) FROM contents_fts") as! Int64
            if count > 0 {
                print("FTS table is already populated. Skipping...")
                return
            }
            
            // Begin a transaction for better performance
            try db.transaction {
                // Fetch all contents
                let query = contents.select(contentId, contentBookId, chunkNo, chunkContent)
                for row in try db.prepare(query) {
                    let contentId = row[self.contentId]
                    let bookId = row[self.contentBookId]
                    let chunkNo = row[self.chunkNo]
                    let content = row[self.chunkContent]
                    
                    // Insert into FTS table
                    try db.run("INSERT INTO contents_fts (content_id, book_id, chunk_no, chunk_content) VALUES (?, ?, ?, ?)",
                               contentId, bookId, chunkNo, content)
                }
            }
            
            print("Successfully populated FTS table")
        } catch {
            print("Error populating FTS table: \(error)")
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
                let contentId = try db.run(contents.insert(
                    contentBookId <- bookId,
                    chunkNo <- index,
                    chunkContent <- chunk
                ))
                
                try db.run("INSERT INTO contents_fts (content_id, book_id, chunk_no, chunk_content) VALUES (?, ?, ?, ?)",
                           contentId, bookId, index, chunk)
            }
            
            return bookId
        } catch {
            print("Error saving book: \(error)")
            return nil
        }
    }
    
    func searchContent(searchTerms: [String], bookId: Int64, limit: Int = 25) -> [(String, String)] {
        guard let db = db else { return [] }
        
        do {
            print("Searching book id \(bookId) with terms: \(searchTerms)")
            var sqlQuery = """
                SELECT book_id, chunk_no, chunk_content, rank
                FROM contents_fts
                WHERE contents_fts MATCH :search
            """
            let searchExpression = searchTerms.map { "\"\($0)*\"" }.joined(separator: " OR ")
            var arguments: [String: Binding] = [":search": searchExpression]

            sqlQuery += " AND book_id = :bookId"
            arguments[":bookId"] = bookId

            sqlQuery += " ORDER BY rank LIMIT :limit"
            arguments[":limit"] = limit
            
            print("sqlQuery: \(sqlQuery)")
            let statement = try db.prepare(sqlQuery)
            statement.bind(arguments)

            
            let results = try statement.run()
            var searchResults: [(String, String)] = []
                    
            for row in results {
                let bookId = row[0] as! Int64
                if let bookContext = getBookContext(bookId: bookId) {
                    searchResults.append((
                        bookContext,
                        row[2] as! String
                    ))
                    if searchResults.count >= limit {
                        break
                    }
                }
            }
            
            print("Obtained search results: \(searchResults)")
            print("A total of \(searchResults.count) results")
            
            return searchResults
        } catch {
            print("Error searching content: \(error)")
        }
        return []
    }
    
    func getBookContext(bookId: Int64) -> String? {
        guard let db = db else { return nil }
        do {
            let query = books.select(bookTitle, bookGist).filter(self.bookId == bookId)
            if let book = try db.pluck(query) {
                return book[bookTitle] + ":" + book[bookGist]
            }
        } catch {
            print("Error fetching book context: \(error)")
        }
        return nil
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
