//
//  PDFViewerView.swift
//  Glin
//
//  Created by Niral Patel on 8/4/24.
//

import SwiftUI
import PDFKit

struct PDFViewerView: View {
    let fileName: String
    @State private var currentPage: Int = 0
    @State private var pageNumberInput: String = ""

    var body: some View {
        VStack {
            if let pdfDocument = loadPDF(from: fileName) {
                PDFKitRepresentedView(pdfDocument: pdfDocument, currentPage: $currentPage)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Failed to load PDF")
                    .foregroundColor(.red)
            }

            HStack {
                Button(action: {
                    changePage(by: -1)
                }) {
                    Image(systemName: "arrow.left.circle")
                        .font(.largeTitle)
                }

                Button(action: {
                    changePage(by: 1)
                }) {
                    Image(systemName: "arrow.right.circle")
                        .font(.largeTitle)
                }
            }
            .padding()

            HStack {
                TextField("Enter page number", text: $pageNumberInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 150)

                Button(action: {
                    goToPage()
                }) {
                    Text("Go to Page")
                }
            }
            .padding()
        }
    }

    private func loadPDF(from fileName: String) -> PDFDocument? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            return PDFDocument(url: fileURL)
        } else {
            print("File does not exist at path: \(fileURL.path)")
            return nil
        }
    }

    private func changePage(by offset: Int) {
        guard let pdfDocument = loadPDF(from: fileName) else { return }
        let newPageNumber = currentPage + offset
        if newPageNumber >= 0 && newPageNumber < pdfDocument.pageCount {
            currentPage = newPageNumber
        }
    }

    private func goToPage() {
        guard let pdfDocument = loadPDF(from: fileName),
              let pageNumber = Int(pageNumberInput.trimmingCharacters(in: .whitespacesAndNewlines)),
              pageNumber > 0,
              pageNumber <= pdfDocument.pageCount else {
            print("Invalid page number")
            return
        }
        currentPage = pageNumber - 1 // PDFKit uses 0-based index
    }
}

struct PDFKitRepresentedView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    @Binding var currentPage: Int

    class Coordinator: NSObject {
        var pdfView: PDFView?

        func goToPage(_ page: Int) {
            guard let pdfView = pdfView, let page = pdfView.document?.page(at: page) else { return }
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if let page = uiView.document?.page(at: currentPage) {
            uiView.go(to: page)
        }
    }
}
