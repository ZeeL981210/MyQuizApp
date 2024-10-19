import SwiftUI

struct QuestionView: View {
    let question: Question?
    let isActive: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var selectedOptions: Set<String> = []
    
    var body: some View {
        if let question = question {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Question \(question.index + 1)")
                        .font(.headline)
                    
                    if question.correctAnswers.count > 1 {
                        Text("Multiple choice: \(question.correctAnswers.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(question.body)
                        .padding()
                    
                    ForEach(question.options, id: \.self) { option in
                        OptionButton(
                            option: option,
                            isSelected: isSelected(option),
                            isCorrect: question.correctAnswers.contains(option),
                            isAnswered: question.userAnswers != nil,
                            action: { selectOption(option) }
                        )
                    }
                }
                .padding()
            }
            .opacity(isActive ? 1 : 0.5)
        } else {
            Color.clear
        }
    }
    
    private func isSelected(_ option: String) -> Bool {
        question?.userAnswers?.contains(option) ?? selectedOptions.contains(option)
    }
    
    private func selectOption(_ option: String) {
        guard isActive, question?.userAnswers == nil else { return }
        
        if question?.correctAnswers.count == 1 {
            selectedOptions = [option]
            appState.submitAnswer(answers: [option])
            appState.saveAnswerToDatabase()
        } else {
            if selectedOptions.contains(option) {
                selectedOptions.remove(option)
            } else {
                selectedOptions.insert(option)
            }
            
            if selectedOptions.count == question?.correctAnswers.count {
                appState.submitAnswer(answers: Array(selectedOptions))
                appState.saveAnswerToDatabase()
            }
        }
    }
}
