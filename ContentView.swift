//
//  ContentView.swift
//  MyQuizApp
//
//  Created by ZEE LU on 2024-10-15.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @State private var expandedExam: UUID?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .leading) {
                    Text("Exams")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(appState.exams) { exam in
                                ExamCard(exam: exam, isExpanded: expandedExam == exam.id)
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            if expandedExam == exam.id {
                                                expandedExam = nil
                                            } else {
                                                expandedExam = exam.id
                                            }
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring()) {
                    expandedExam = nil
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ContentView()
}
