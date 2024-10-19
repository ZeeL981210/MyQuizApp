import Foundation

class FileManagerService {
    /// Allow outside access
    static let shared = FileManagerService()
    private var currentJSONData: [String: Any]?
    private var currentFileName: String?
    /// In  our case, Service class only needs minimal initialization.
    private init() {
        print("\nFileManagerService initialized.")
    }

    /// Get the paths of all JSON files in the app's resource bundle
    /// - Parameter exclude: Optional. The file name that you want to exclude
    /// - Returns: An array of strings representing the paths of the JSON files, excluding "template.json"
    func getJSONFilePaths(exclude: [String]? = nil) -> [String] {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("\nFileManagerService.getJSONFilePaths(): Error: Unable to access resource path")
            return []
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: resourcePath), includingPropertiesForKeys: nil)
            /// explain !exclude!.contains($0.lastPathComponent)):
            /// 1. exclude!: unwrap the exclude array
            /// 2. .contains($0.lastPathComponent): Check if current url contains the file name that need to be excluded
            /// 3. ! mark at the very beginning: negates the result
            /// In conclusion, it means "if current file name is not in the excluded list, pass"
            let jsonURLs = fileURLs.filter {
                    $0.pathExtension == "json" &&
                    (exclude == nil || !exclude!.contains($0.lastPathComponent))
                }
            print("\nFileManagerService.getJSONPaths(): - Found JSON files:")
            jsonURLs.enumerated().forEach { print("   \($0 + 1). \($1.path)") }
            return jsonURLs.map { $0.path }
        } catch {
            print("\nFileManagerService.getJSONPaths(): Error scanning directory: \(error.localizedDescription)")
            return []
        }
    }

    /// Set the JSON data from the given path
    /// - Parameter path: The path to the JSON data
    /// - Returns: A boolean indicating whether the JSON data was set successfully
    func setJSONData(path: String) -> Bool {
        currentFileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let data = FileManager.default.contents(atPath: path) else {
            print("\nsetJSONData(): Error: Unable to read data from path: \(path)")
            return false
        }
        do {
            currentJSONData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print("\nsetJSONData(): Error: Invalid JSON data: \(error.localizedDescription)")
            return false
        }
        return true
    }

    /// Validate the JSON data at the given path
    /// - Parameter path: The path to the JSON data
    /// - Returns: A boolean indicating whether the JSON data is valid
    func validateJSONData() -> Bool {
        guard let jsonDict = currentJSONData else {
            print("\nvalidateJsonData(): Error: No JSON data loaded")
            return false
        }
        
        if !validateExam(jsonDict) {
            return false
        }
        
        return true
    }
    
    /// Validate the exam data
    /// - Parameter exam: The exam data
    /// - Returns: A boolean indicating whether the exam data is valid
    func validateExam(_ exam: [String: Any]) -> Bool {
        let requiredFields = ["version", "origin", "name", "description", "last_updated", "topics"]
        
        for field in requiredFields {
            guard exam[field] != nil else {
                print("\nvalidateExam(): Error: Missing required exam field: \(field)")
                return false
            }
        }
        
        guard let topics = exam["topics"] as? [[String: Any]] else {
            print("\nvalidateExam(): Error: Invalid or missing 'topics' array")
            return false
        }
        
        return topics.allSatisfy(validateTopic)
    }
    
    /// Validate the topic data
    /// - Parameter topic: The topic data
    /// - Returns: A boolean indicating whether the topic data is valid
    private func validateTopic(_ topic: [String: Any]) -> Bool {
        let requiredFields = ["name", "questions"]
        
        for field in requiredFields {
            guard topic[field] != nil else {
                print("\nvalidateTopic(): Error: Missing required topic field: \(field)")
                return false
            }
        }
        
        guard let questions = topic["questions"] as? [[String: Any]] else {
            print("\nvalidateTopic(): Error: Invalid or missing 'questions' array in topic")
            return false
        }
        
        return questions.allSatisfy(validateQuestion)
    }
    
    /// Validate the question data
    /// - Parameter question: The question data
    /// - Returns: A boolean indicating whether the question data is valid
    private func validateQuestion(_ question: [String: Any]) -> Bool {
        let requiredFields = ["text", "options", "correct_answer"]
        
        for field in requiredFields {
            guard question[field] != nil else {
                print("\nvalidateQuestion(): Error: Missing required question field: \(field)")
                return false
            }
        }
        
        return true
    }

    /// decode JSON data into objects
    /// - Returns: a set of current exam data, including Exam, Topics and Questions.
    func decodeJSONData() throws -> (Exam, [Topic], [Question]) {
        guard let jsonData = currentJSONData else {
            throw NSError(domain: "FileManagerService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No JSON data loaded"])
        }
        
        var topics: [Topic] = []
        var questions: [Question] = []
        var questionIndex = 0
        
        if let topicsData = jsonData["topics"] as? [[String: Any]] {
            for topicData in topicsData {
                let topic = Topic(
                    id: UUID(),
                    name: topicData["name"] as? String ?? ""
                )
                topics.append(topic)
                
                if let questionsData = topicData["questions"] as? [[String: Any]] {
                    for questionData in questionsData {
                        let question = Question(
                            id: UUID(),
                            topicId: topic.id,
                            body: questionData["text"] as? String ?? "",
                            index: questionIndex,
                            options: questionData["options"] as? [String] ?? [],
                            correctAnswers: questionData["correct_answer"] as? [String] ?? []
                        )
                        questions.append(question)
                        questionIndex += 1
                        
                        /// we are returning all questions at once, so better set a limit for the size of questions.
                        if (questionIndex >= 1500){
                            throw NSError(domain: "FileManagerService", code: 1, userInfo: [NSLocalizedDescriptionKey: "exam exceed size limit of 1500 questions."])
                        }
                    }
                }
            }
        }
        
        let exam = Exam(
            id: UUID(),
            name: jsonData["name"] as? String ?? "",
            version: jsonData["version"] as? String ?? "",
            origin: jsonData["origin"] as? String ?? "",
            description: jsonData["description"] as? String ?? "",
            lastUpdated: ISO8601DateFormatter().date(from: jsonData["last_updated"] as? String ?? "") ?? Date(),
            fileName: currentFileName ?? "",
            questionAmount: questionIndex
        )
        return (exam, topics, questions)
    }
}

