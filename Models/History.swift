
import Foundation

struct AttemptHistory: Identifiable, Codable {
    let id: UUID
    let examId: UUID
    let version: String
    let attemptId: Int
    var finishedQuestionAmount: Int
    var mode: String
    let score: Double

    init(id: UUID, examId: UUID, version: String, attemptId: Int = -1, finishedQuestionAmount: Int = 0, mode: String, score: Double = -1) {
        self.id = id
        self.examId = examId
        self.version = version
        self.attemptId = attemptId
        self.finishedQuestionAmount = finishedQuestionAmount
        self.mode = mode
        self.score = score
    }
}


struct QuestionHistory: Identifiable, Codable {
    let id: UUID
    let attemptHistoryId: UUID
    let questionId: UUID
    let isCorrect: Bool
    let userAnswer: [String]


    init(id: UUID, attemptHistoryId: UUID, questionId: UUID, isCorrect: Bool = false, userAnswer: [String]) {
        self.id = id
        self.attemptHistoryId = attemptHistoryId
        self.questionId = questionId
        self.isCorrect = isCorrect
        self.userAnswer = userAnswer
    }
}








