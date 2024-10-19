import Foundation

class AppState: ObservableObject {
    static let shared = AppState()

    private let fileManagerService = FileManagerService.shared
    private let databaseService = DatabaseService.shared
    
    @Published var exams: [Exam] = []
    @Published var currentExam: Exam?
    @Published var prevQuestion: Question?
    @Published var currentQuestion: Question?
    @Published var nextQuestion: Question?
    @Published var currrentQuestionList: [Int: (marked: Bool, answered: Bool, id: UUID)] = [:]
    @Published var currentAttemptHistory: AttemptHistory?
    @Published var currentAttemptFinished: Bool = false
    @Published var currentIndex: Int = 0

    private init() {
        initializeApp()
    }

    private func initializeApp() {
        // exclude template.json after testing phase
        let jsonPaths = fileManagerService.getJSONFilePaths()
        for jsonPath in jsonPaths {
            processJsonFile(path: jsonPath)
        }

        // load exam from database
        exams = databaseService.getExamList()
        print("    Exams: \(exams)")
        if let exam = exams.first {
            currentExam = exam
        }
    }

    /// load data from json file into database
    /// if the exam exists, check for update
    private func processJsonFile(path: String) {
        guard fileManagerService.setJSONData(path: path),
            fileManagerService.validateJSONData() else {
            print("    Invalid JSON data for file: \(path)")
            return
        }

        do {
            var exam: Exam
            var topics: [Topic]
            var questions: [Question]
            
            do { (exam, topics, questions) = try fileManagerService.decodeJSONData() } 
            catch {
                print("    Error decoding JSON data: \(error.localizedDescription)")
                return
            }

            /// if updateListDatabase() return true, it updates the database
            /// Otherwise, it creates a new row for current exam
            if databaseService.updateListDatabase(exam: exam) {
                print("    Updated exam: \(exam.fileName)")
            } else {
                if databaseService.insertToListDatabase(exam: exam) {
                    databaseService.initExamDatabase(fileName: exam.fileName)
                    print("    Inserted exam: \(exam.fileName)")
                    guard topics.allSatisfy({ databaseService.insertTopic(topic: $0) }) &&
                          questions.allSatisfy({ databaseService.insertQuestion(question: $0) }) else {
                        print("    Error inserting topics or questions for exam: \(exam.fileName)")
                        return
                    }
                    print("    Successfully inserted all topics and questions for exam: \(exam.fileName)")
                } else {
                    print("    Failed to insert exam: \(exam.fileName)")
                }
            }
        }
    }

    /// To select an exam(due to the design, only one exam can be attempted at the same time).
    /// - Note: This function will update:
    ///     - currentExam: Exam
    ///     - currentQuestionList: [Int: (marked: Bool, answered: Bool, id: UUID)]
    ///     - currentQuestion: Question?
    ///     - currentAttemptHistory: AttemptHistory? - if there's no unfinished attempt, it will create a new one.
    func selectExam(exam: Exam) {
        currentExam = exam
        databaseService.setCurrentExamDb(filename: exam.fileName)
        currentAttemptHistory = databaseService.getLatestAttemptHistory(exam: exam)
        currrentQuestionList = databaseService.getQuestionListMap()
        currentIndex = currrentQuestionList.filter { $0.value.answered }.max(by: { $0.key < $1.key })?.key ?? 0
        print("    Current question list: \(currrentQuestionList)")
        updateQuestions()
        print("    Current attempt history: \(String(describing: currentAttemptHistory?.id))")
    }

    /// switch marked status for current question
    func setMarked() {
        currentQuestion?.marked = !currentQuestion!.marked
        if !databaseService.setMarked(question: currentQuestion!) {
            print("    Error setting marked for question: \(currentQuestion!.id)")
            return
        }
        currrentQuestionList[currentQuestion!.index]?.marked = ((currentQuestion?.marked) != nil)
    }

    /// randomize the order of the options
    func randomize() {
        currentQuestion?.randomize()
    }

    /// check if the answer is correct
    func isCorrect() -> Bool {
        return currentQuestion?.isCorrect() ?? false
    }
    
    /// set answer for current question.
    func submitAnswer(answers: [String]) {
        currentQuestion?.userAnswers = answers
        currrentQuestionList[currentIndex]?.answered = true
    }

    func discardAnswer() {
        currentQuestion?.userAnswers = nil
        currentAttemptHistory?.finishedQuestionAmount -= 1
        currrentQuestionList[currentIndex]?.answered = false
        if !databaseService.updateAttemptHistory(attemptHistory: currentAttemptHistory!) {
            print("    Error updating attempt history for question: \(currentQuestion!.id)")
            return
        }
        if !databaseService.removeQuestionHistory(questionId: currentQuestion!.id, attemptHistoryId: currentAttemptHistory!.id) {
            print("    Error removing question history for question: \(currentQuestion!.id)")
            return
        }   
    }

    /// set current question by index
    func setCurrentQuestion(index: Int) {
        guard index >= 0 && index < currrentQuestionList.count else {
            print("    Error setting current question: invalid index")
            return
        }
        currentIndex = index
        updateQuestions()
        print("    Current question: \(String(describing: currentQuestion))")
    }

    /// save answer to database, because only current question instance is stored in memory.
    func saveAnswerToDatabase() {
        guard let currentAttemptId = currentAttemptHistory?.id else { print("    Error saving answer for question: invalid attempt id"); return }
        let question_history = QuestionHistory(
            id: UUID(),
            attemptHistoryId: currentAttemptId,
            questionId: currentQuestion!.id,
            isCorrect: isCorrect(),
            userAnswer: (currentQuestion?.userAnswers)!
        )
        if !databaseService.insertQuestionHistory(questionHistory: question_history) {
            print("    Error saving answer for question: \(currentQuestion!.id)")
            return
        }

        currentAttemptHistory?.finishedQuestionAmount += 1
        if currentAttemptHistory?.finishedQuestionAmount == currentExam?.questionAmount {
            currentAttemptFinished = true
        }

        if !databaseService.updateAttemptHistory(attemptHistory: currentAttemptHistory!) {
            print("    Error updating attempt history for question: \(currentQuestion!.id)")
            return
       }
    }

    /// start a new attempt upon request
    /// - Note: This function allows user to drop their current attempt even it is unfinished.
    func startNewAttempt() {
        let new_attempt = AttemptHistory(
            id: UUID(),
            examId: currentExam!.id,
            version: currentExam!.version,
            attemptId: currentAttemptHistory!.attemptId + 1,
            finishedQuestionAmount: 0,
            mode: "",
            score: -1
        )

        currentAttemptHistory = new_attempt
        currentAttemptFinished = false
        if !databaseService.insertAttemptHistory(attemptHistory: new_attempt){
            print(" Fail to insert attempt history")
        }
    }

    /// get current progress percentage of an exam
    func getProgressPercentage(exam: Exam) -> Double {
        let attemptHistory = databaseService.getLatestAttemptHistory(exam: exam)
        let questionAmount = exam.questionAmount
        let finishedQuestionAmount = attemptHistory!.finishedQuestionAmount
        return Double(finishedQuestionAmount) / Double(questionAmount)
    }

    private func updateQuestions() {
        guard let exam_version = currentExam?.version else {
            print("    Error updating questions: invalid exam version")
            return
        }

        prevQuestion = currentIndex > 0 ? getQuestionByIndex(currentIndex - 1, version: exam_version) : nil
        currentQuestion = getQuestionByIndex(currentIndex, version: exam_version)
        nextQuestion = currentIndex < currrentQuestionList.count - 1 ? getQuestionByIndex(currentIndex + 1, version: exam_version) : nil

        if currentQuestion?.userAnswers != nil && currentAttemptHistory?.version != exam_version {
            currentQuestion?.userAnswers = nil
        }
    }

    private func getQuestionByIndex(_ index: Int, version: String) -> Question? {
        guard let q_id = currrentQuestionList[index]?.id else { return nil }
        return databaseService.getQuestionById(id: q_id, version: version)
    }

    func moveToNextQuestion() {
        if currentIndex < currrentQuestionList.count - 1 {
            setCurrentQuestion(index: currentIndex + 1)
        }
    }

    func moveToPreviousQuestion() {
        if currentIndex > 0 {
            setCurrentQuestion(index: currentIndex - 1)
        }
    }
}
