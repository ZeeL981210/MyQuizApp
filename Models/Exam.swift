import Foundation

struct Exam: Identifiable, Codable {

    let id: UUID
    let name: String
    let version: String
    let origin: String
    let description: String
    let lastUpdated: Date
    let fileName: String
    var questionAmount: Int // likely to changed after initialization, so var is used.
    
    enum CodingKeys: String, CodingKey {
        // case that parameter name exact match the ones from json file
        case id, name, version, origin, description
        // case that parameter named with underline instead of Caps.
        case lastUpdated = "last_updated"
        case fileName = "file_name"
        case questionAmount = "question_amount"
    }
    
    init(id: UUID, name: String, version: String, origin: String, description: String, lastUpdated: Date, fileName: String, questionAmount: Int) {
        self.id = id
        self.name = name
        self.version = version
        self.origin = origin
        self.description = description
        self.lastUpdated = lastUpdated
        self.fileName = fileName
        self.questionAmount = questionAmount
    }
}
