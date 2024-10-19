import SwiftUI

struct ToolBar: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showQuestionList = false

    var body: some View {
        ZStack {
            HStack {
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .overlay(
                        HStack(spacing: 60) {
                            Button(action: {
                                showQuestionList.toggle()
                            }) {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.yellow)
                            }
                            
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "house")
                                    .foregroundColor(.blue)
                            }

                            Button(action: {
                                appState.setMarked()
                            }) {
                                Image(systemName: appState.currentQuestion?.marked == true ? "star.fill" : "star")
                                    .foregroundColor(.red)
                            }
                            
                            Button(action: {
                                appState.discardAnswer()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(appState.currentQuestion?.userAnswers == nil ? .gray : .green)
                            }.disabled(appState.currentQuestion?.userAnswers == nil)
                        }
                    )
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showQuestionList) {
            QuestionListView(showQuestionList: $showQuestionList)
        }
    }
}

struct QuestionListView: View {
    @ObservedObject private var appState = AppState.shared
    @Binding var showQuestionList: Bool

    var body: some View {
        List {
            ForEach(appState.currrentQuestionList.sorted(by: { $0.key < $1.key }), id: \.key) { index, questionInfo in
                Button(action: {
                    appState.setCurrentQuestion(index: index)
                    showQuestionList = false
                }) {
                    HStack {
                        Text("Question \(index + 1)")
                        Spacer()
                        if questionInfo.marked {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                        if questionInfo.answered {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
    }
}
