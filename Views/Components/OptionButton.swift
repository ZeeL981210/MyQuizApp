import SwiftUI

struct OptionButton: View {
    let option: String
    let isSelected: Bool
    let isCorrect: Bool
    let isAnswered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(option)
                Spacer()
                if isAnswered {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "x.circle.fill")
                        .foregroundColor(isCorrect ? .green.opacity(0.8) : .red.opacity(0.8))
                }
            }
            .padding()
            .background(backgroundColor)
            .foregroundColor(isAnswered ? .black : .primary)
            .cornerRadius(8)
        }
        .disabled(isAnswered)
    }
    
    private var backgroundColor: Color {
        if isAnswered {
            return isCorrect ? .green.opacity(0.6) : (isSelected ? .red.opacity(0.6) : .gray.opacity(0.4))
        } else {
            return isSelected ? .gray.opacity(0.6) : .gray.opacity(0.4)
        }
    }
}