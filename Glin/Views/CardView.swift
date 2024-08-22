import SwiftUI
import MarkdownUI
import PDFKit

struct CardView: View {
    @ObservedObject var viewModel: ContentViewModel
    let onSwipe: (SwipeDirection) -> Void
    @State private var offset = CGSize.zero
    
    var body: some View {
        VStack {
            ScrollView {
                if let content = viewModel.currentCardContent {
                    Markdown(content)
                        .markdownTextStyle(\.text){
                            ForegroundColor(Color(.systemBackground))
                            BackgroundColor(Color(.label))
                        }
                        .markdownBlockStyle(\.heading1) { configuration in
                            configuration.label
                                .padding(.vertical)
                                .markdownTextStyle {
                                    FontSize(.em(2.5))
                                    FontWeight(.bold)
                                }
                        }
                        .markdownBlockStyle(\.blockquote) { configuration in
                          configuration.label
                            .padding()
                            .markdownTextStyle {
                              FontCapsVariant(.lowercaseSmallCaps)
                              FontWeight(.semibold)
                              BackgroundColor(nil)
                            }
                            .overlay(alignment: .leading) {
                              Rectangle()
                                .fill(Color.teal)
                                .frame(width: 4)
                            }
                            .background(Color.teal.opacity(0.5))
                        }
                        .padding(40)
                } else {
                    Text("No content available")
                        .foregroundColor(.gray)
                        .padding(30)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding(7)
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(Double(offset.width / 10)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = CGSize(width: gesture.translation.width, height: 0) // Ignore vertical movement
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        if abs(offset.width) > 100 {
                            offset = CGSize(width: value.translation.width > 0 ? 1000 : -1000, height: 0)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipe(value.translation.width > 0 ? .right : .left)
                                offset = .zero
                            }
                        } else {
                            offset = .zero
                        }
                    }
                }
        )
        
        HStack {
            Button("Chat") {
                if let bookId = viewModel.currentBookId,
                   let sessionId = viewModel.databaseManager.getSessionId(for: bookId) {
                    viewModel.currentSessionId = sessionId
                    viewModel.loadChatView(for: sessionId)
                } else {
                    print("creating a new sesh...")
                    let newSesh = viewModel.databaseManager.createSession(bookId: viewModel.currentBookId) ?? -1
                    viewModel.currentSessionId = newSesh
                    viewModel.loadChatView(for: newSesh)
                }
            }
            .padding(10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            if let fileName = viewModel.currentPDFFilePath {
                NavigationLink(destination: PDFViewerView(fileName: fileName)) {
                    Text("PDF")
                        .padding(10)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                Button(action: {
                    viewModel.isShowingFilePicker = true
                }) {
                    Text("PDF")
                        .padding(10)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            Button(action: { viewModel.retryCardGeneration() }) {
                Image(systemName: "arrow.clockwise.circle")
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            .padding(10)
            .background(.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(5)
    }
}

#Preview("Card") {
    let viewModel = ContentViewModel()
    viewModel.currentCardContent = """
    # Welcome to Markdown Testing

    ## This is a Subheading

    ### Smaller Subheading

    Markdown allows you to format text easily using simple symbols. Below are some examples:

    **Bold Text** - Use `**` or `__` to make text bold.

    *Italic Text* - Use `*` or `_` to italicize text.

    **_Bold and Italic Text_** - Combine both.

    ~~Strikethrough~~ - Use `~~` to strike through text.

    ### Lists

    #### Unordered List:
    - Item 1
    - Item 2
      - Subitem 2.1
      - Subitem 2.2
    - Item 3

    #### Ordered List:
    1. First item
    2. Second item
       1. Subitem 2.1
       2. Subitem 2.2
    3. Third item

    ### Links and Images

    [Click here to visit Google](https://www.google.com)

    ![Sample Image](https://via.placeholder.com/150)

    ### Code Snippets

    Inline code: `print("Hello, World!")`

    Block of code:
    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, SwiftUI!")
        }
    }
    ```
    
    Blockquotes

    > "This is a blockquote. You can use it to highlight a quote or message."

    Horizontal Rule

    ---

    Tables

    | Header 1 | Header 2 | Header 3 |
    |----------|----------|----------|
    | Row 1    | Data 1   | Data 2   |
    | Row 2    | Data 3   | Data 4   |

    Task List

    - [x] Task 1 completed
    - [ ] Task 2 pending
    - [ ] Task 3 pending
    """
    return CardView(viewModel: viewModel) { SwipeDirection in
        return
    }
}
