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
    private let pdfFilePath = Expression<String?>("pdf_file_path")

    private let contentsFTS = VirtualTable("contents_fts")
    
    private let contents = Table("contents")
    private let contentId = Expression<Int64>("id")
    private let contentBookId = Expression<Int64>("book_id")
    private let chunkNo = Expression<Int>("chunk_no")
    private let chunkContent = Expression<String>("chunk_content")
    private let chunkSummary = Expression<String?>("chunk_summary")
    
    private let sessions = Table("sessions")
    private let sessionId = Expression<Int64>("session_id")
    private let sessionBookId = Expression<Int64?>("book_id")
    private let createdAt = Expression<String>("created_at")
    
    private let messages = Table("messages")
    private let messageId = Expression<Int64>("message_id")
    private let messageSessionId = Expression<Int64>("session_id")
    private let role = Expression<String>("role")
    private let content = Expression<String>("content")
    private let timestamp = Expression<String>("timestamp")
    
    private init() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            db = try Connection("\(path)/glin.sqlite3")
            createTables()
            populateFTSTable()
            addPDFFilePathColumn()
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
                t.column(pdfFilePath)
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
            
            try db.run(sessions.create(ifNotExists: true) { t in
                t.column(sessionId, primaryKey: .autoincrement)
                t.column(sessionBookId)
                t.column(createdAt)
                t.foreignKey(sessionBookId, references: books, bookId)
            })

            try db.run(messages.create(ifNotExists: true) { t in
                t.column(messageId, primaryKey: .autoincrement)
                t.column(messageSessionId)
                t.column(role)
                t.column(content)
                t.column(timestamp)
                t.foreignKey(messageSessionId, references: sessions, sessionId)
            })

            
        } catch {
            print("Error creating tables: \(error)")
        }
    }

    func addPDFFilePathColumn() {
        guard let db = db else { return }
        
        do {
            // Check if the column already exists
            let columns = try db.prepare("PRAGMA table_info(books)").map { row in
                row[1] as! String
            }
            
            if !columns.contains("pdf_file_path") {
                try db.run(books.addColumn(pdfFilePath))
                print("Successfully added pdfFilePath column to books table")
            } else {
                print("pdfFilePath column already exists in books table")
            }
        } catch {
            print("Error adding pdfFilePath column: \(error)")
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
    
    func saveBook(title: String, gist: String, chunks: [String], pdfFilePath: String) -> Int64? {
        guard let db = db else { return nil }
        
        do {
            let bookId = try db.run(books.insert(
                self.bookTitle <- title,
                self.bookGist <- gist,
                self.totalChunks <- chunks.count,
                self.pdfFilePath <- pdfFilePath
            ))
            
            for (index, chunk) in chunks.enumerated() {
                let contentId = try db.run(contents.insert(
                    self.contentBookId <- bookId,
                    self.chunkNo <- index,
                    self.chunkContent <- chunk
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
    
    func getTotalLengthOfResults(_ results: [(String, String)]) -> Int {
        return results.reduce(0) { $0 + $1.1.count }
    }
    
    func searchContent(searchTerms: [String], bookId: Int64? = nil, limit: Int = 25) -> [(String, String)] {
        guard let db = db else { return [] }
        
        do {
            print("Searching book id \(String(describing: bookId)) with terms: \(searchTerms)")
            var sqlQuery = """
                SELECT book_id, chunk_no, chunk_content, rank
                FROM contents_fts
                WHERE contents_fts MATCH :search
            """
            let searchExpression = searchTerms.map { "\"\($0)*\"" }.joined(separator: " OR ")
            var arguments: [String: Binding] = [":search": searchExpression]
            
            if bookId != nil {
                sqlQuery += " AND book_id = :bookId"
                arguments[":bookId"] = bookId
            }


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
//                    if getTotalLengthOfResults(searchResults) + bookContext.count > 127000 { TODO: account for this or toks
//                        break
//                    }
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
    
    func getCardTextForBook(bookId: Int64, cardNumber: Int, totalCards: Int) -> String? {
        guard let db = db else { return nil }

        do {
            // Step 1: Retrieve the totalChunks value directly
            if let totalChunks = try db.pluck(books.select(self.totalChunks).filter(self.bookId == bookId))?[self.totalChunks] {
                
                // Calculate the offset and chunks per card
                let chunksPerCard = (totalChunks + totalCards - 1) / totalCards // Ceiling division
                let offset = cardNumber * chunksPerCard

                // Step 2: Retrieve the relevant chunks
                let query = contents
                    .filter(contentBookId == bookId)
                    .order(chunkNo.asc)
                    .limit(chunksPerCard, offset: offset)

                var combinedText = ""
                for row in try db.prepare(query) {
                    combinedText += row[chunkContent]
                }

                return combinedText.isEmpty ? nil : combinedText
            } else {
                print("Could not retrieve totalChunks for book ID \(bookId)")
                return nil
            }
        } catch {
            print("Error fetching card text for book ID \(bookId): \(error)")
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
                    id: row[self.bookId],
                    title: row[self.bookTitle],
                    gist: row[self.bookGist],
                    totalChunks: row[self.totalChunks],
                    pdfFilePath: row[self.pdfFilePath]
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
                    title: book[self.bookTitle],
                    gist: book[self.bookGist],
                    totalChunks: book[self.totalChunks],
                    pdfFilePath: book[self.pdfFilePath]
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

    func updatePDFFileName(for bookId: Int64, fileName: String) {
        guard let db = db else { return }
        
        do {
            let book = books.filter(self.bookId == bookId)
            try db.run(book.update(self.pdfFilePath <- fileName))
            print("Successfully updated PDF file name \(fileName) for book ID \(bookId)")
        } catch {
            print("Error updating PDF file path: \(error)")
        }
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
    
    func createSession(bookId: Int64?) -> Int64? {
        guard let db = db else { return nil }

        do {
            let sessionId = try db.run(sessions.insert(
                self.sessionBookId <- bookId,
                self.createdAt <- DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            ))
            return sessionId
        } catch {
            print("Error creating session: \(error)")
            return nil
        }
    }

    func getSessionId(for bookId: Int64?) -> Int64? {
        guard let db = db else { return nil }

        do {
            let query = sessions
                .select(sessionId)
                .filter(sessionBookId == bookId || (bookId == nil && sessionBookId == nil))
                .order(createdAt.desc)
                .limit(1)
            
            if let session = try db.pluck(query) {
                return session[sessionId]
            }
        } catch {
            print("Error fetching session: \(error)")
        }
        
        return nil
    }
    
    func saveMessage(sessionId: Int64, role: String, content: String, timestamp: String) {
        guard let db = db else { return }
        
        do {
            try db.run(messages.insert(
                self.messageSessionId <- sessionId,
                self.role <- role,
                self.content <- content,
                self.timestamp <- timestamp
            ))
            print("Inserted message for sessionId \(sessionId)")
        } catch {
            print("Error inserting message: \(error)")
        }
    }

    func getMessagesFromSession(sessionId: Int64) -> [Message] {
        guard let db = db else { return [] }
        
        do {
            let query = messages.filter(self.messageSessionId == sessionId)
            return try db.prepare(query).map { row in
                Message(
                    role: row[self.role],
                    content: row[self.content]
                )
            }
        } catch {
            print("Error fetching messages: \(error)")
            return []
        }
    }
}
