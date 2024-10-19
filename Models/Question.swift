import Foundation

struct Question: Identifiable, Codable {
    let id: UUID
    let topicId: UUID
    let index: Int
    let body: String
    var options: [String]
    let correctAnswers: [String]
    var marked: Bool
    var offset: Float
    var userAnswers: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, topicId, body, options, index, marked, offset
        case correctAnswers = "correct_answers"
        case userAnswers = "user_answers"
    }
    
    init(id: UUID, topicId: UUID, body: String, index: Int, options: [String], correctAnswers: [String], marked: Bool = false, offset: Float = 0, userAnswers: [String]? = nil) {
        self.id = id
        self.topicId = topicId
        self.body = body
        self.index = index
        self.options = options
        self.correctAnswers = correctAnswers
        self.marked = marked
        self.offset = offset
        self.userAnswers = userAnswers
    }

    mutating func randomize() {
        options.shuffle()
    }

    func isCorrect() -> Bool {
        guard let userAnswers = userAnswers else {
            return false // or handle unanswered questions differently if needed
        }
        return Set(userAnswers) == Set(correctAnswers)
    }

    mutating func setMarked(_ marked: Bool) {
        self.marked = marked
    }
}
