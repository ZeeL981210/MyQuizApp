import SwiftUI

struct LearningView: View {
    @ObservedObject private var appState = AppState.shared
    let exam: Exam
    @State private var dragOffset: CGSize = .zero
    @State private var selectedOptions: Set<String> = []
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if appState.currentAttemptFinished {
                ExamFinishedView(
                    goBack: goBack,
                    startNewAttempt: {
                        appState.startNewAttempt()
                        appState.setCurrentQuestion(index: 0)
                        selectedOptions.removeAll()
                        dragOffset = .zero
                    },
                    dismiss: { presentationMode.wrappedValue.dismiss() }
                )
            } else {
                GeometryReader { geometry in
                    VStack {
                        HStack(spacing: 0) {
                            QuestionView(question: appState.prevQuestion, isActive: false)
                                .frame(width: geometry.size.width)
                            QuestionView(question: appState.currentQuestion, isActive: true)
                                .frame(width: geometry.size.width)
                            QuestionView(question: appState.nextQuestion, isActive: false)
                                .frame(width: geometry.size.width)
                        }
                        .offset(x: -geometry.size.width + dragOffset.width)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if (appState.prevQuestion != nil && gesture.translation.width > 0) ||
                                       (appState.nextQuestion != nil && gesture.translation.width < 0) {
                                        self.dragOffset = gesture.translation
                                    }
                                }
                                .onEnded { gesture in
                                    let threshold = geometry.size.width / 3
                                    if gesture.translation.width < -threshold && appState.nextQuestion != nil {
                                        appState.moveToNextQuestion()
                                    } else if gesture.translation.width > threshold && appState.prevQuestion != nil {
                                        appState.moveToPreviousQuestion()
                                    }
                                    self.dragOffset = .zero
                                }
                        )
                    }
                    if !appState.currentAttemptFinished {
                        ToolBar()
                            .frame(width: geometry.size.width)
                        .position(x: geometry.size.width / 2, y: geometry.size.height - 25)
                    }
                }
            }
        }
        .navigationBarTitle("Learning - \(appState.currentExam?.fileName ?? "")", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            appState.selectExam(exam: exam)
        }
    }

    private func goBack() {
        appState.currentAttemptFinished = false
        appState.setCurrentQuestion(index: appState.currrentQuestionList.count - 1)
    }
}
