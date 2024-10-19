import SwiftUI

struct ExamFinishedView: View {
    let goBack: () -> Void
    let startNewAttempt: () -> Void
    let dismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Exam Finished!")
                .font(.largeTitle)
                .padding()
            
            Button("Go Back", action: goBack)
                .buttonStyle(PrimaryButtonStyle(color: .gray))
            
            Button("Start New Attempt", action: startNewAttempt)
                .buttonStyle(PrimaryButtonStyle(color: .blue))
            
            Button("Main Menu", action: dismiss)
                .buttonStyle(PrimaryButtonStyle(color: .green))
        }
        .padding()
    }
}


struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: 200, maxHeight: 60)
            .padding(.horizontal)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(22)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}