//
//  ExamCard.swift
//  MyQuizApp
//
//  Created by ZEE LU on 2024-10-17.
//

import SwiftUI

struct ExamCard: View {
    let exam: Exam
    let isExpanded: Bool
    @State private var learningProgress: Double = 0.0
    @State private var practiceProgress: Double = 0.0
    @State private var examProgress: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Text(exam.name)
                    .font(.title2)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                    Text("Last update: \(exam.lastUpdated, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue)
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text(exam.description)
                    .font(.body)
                    .foregroundColor(.gray)
                
                if isExpanded {
                    VStack(spacing: 20) {
                        NavigationLink(destination: LearningView(exam: exam)) {
                            HStack {
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white)
                                Text("Learn")
                                Spacer()
                                ProgressCircleView(progress: learningProgress)
                                    .frame(width: 25, height: 25)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .animation(.spring(), value: isExpanded)
        .onAppear(perform: loadProgress)
    }
    
    private func loadProgress() {
        learningProgress = AppState.shared.getProgressPercentage(exam: exam)
    }
    
    
}
