import SwiftUI

struct NavigationButtons: View {
    let currentIndex: Int
    let totalQuestions: Int
    let previousAction: () -> Void
    let nextAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: previousAction) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .disabled(currentIndex == 0)
            
            Spacer()
            
            Button(action: nextAction) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .disabled(currentIndex == totalQuestions - 1)
        }
        .padding()
    }
}