import Foundation
import SQLite3


class DatabaseService {
    static let shared = DatabaseService()
    private var listDB: OpaquePointer? // point to `list.db`
    private var examDB: OpaquePointer? // point to `{fileName}.db`
    
    private init() {
        initListDatabase()
    }

    
    /// Initializes the list database: creates a database file named "list.db" in the app's document directory, also an exams table that keep the record of exams.
    /// - Note: Assosiate with `list.db`
    func initListDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("list.db")

        print("\nDatabaseService.initListDatabase(): \n    File URL: \(fileURL.path)")
        
        if sqlite3_open(fileURL.path, &listDB) != SQLITE_OK {
            print("    Error opening list database")
            return
        }

        let createTableString = """
            CREATE TABLE IF NOT EXISTS exams(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            version TEXT,
            origin TEXT,
            description TEXT,
            last_updated TEXT,
            question_amount INT NOT NULL,
            file_name TEXT,
            UNIQUE(name, version, last_updated)
            );
        """

        if sqlite3_exec(listDB, createTableString, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(listDB)!)
            print("    Error creating exams table: \(errmsg)")
        }
    }
    
    
    /// Inserts an exam into the list database.
    /// - Parameter exam: The Exam object to be inserted.
    /// - Returns: A boolean indicating whether the insertion was successful.
    /// - Note: Assosiate with `list.db`
    /// Example usage:
    /// ```
    /// let exam = Exam( ...data )
    /// let success = insertToListDatabase(exam: exam)
    /// ```
    func insertToListDatabase(exam: Exam) -> Bool {
        let id = exam.id.uuidString // cast string when inserting to sqlite3
        let name = exam.name
        let version = exam.version
        let origin = exam.origin
        let description = exam.description
        let lastUpdated = exam.lastUpdated.ISO8601Format()
        let fileName = exam.fileName
        let questionAmount = exam.questionAmount
        
        let insertQuery = """
        INSERT OR IGNORE INTO exams (id, name, version, origin, description, last_updated, question_amount, file_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        print("\nDatabaseService.insertToListDatabase(): Inserting exam: \(name)")
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(listDB, insertQuery, -1, &statement, nil) != SQLITE_OK {
           let errmsg = String(cString: sqlite3_errmsg(listDB)!)
           print("    Error preparing insert: \(errmsg)")
           return false
        }

        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (version as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (origin as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (description as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (lastUpdated as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 7, Int32(questionAmount))
        sqlite3_bind_text(statement, 8, (fileName as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)

        return result == SQLITE_DONE
    }

    
    /// Updates an existing exam in the list database.
    /// - Parameter exam: The Exam object with updated information.
    /// - Returns: A boolean indicating whether the update was successful.
    /// - Note:
    ///     - Assosicate with `list.db`
    ///     - This function only updates the exam if the new version is higher or if the version is the same but the last updated date is more recent. It will use the fileName as reference. Id will not updated.
    ///
    /// Example usage:
    /// ```
    /// let updatedExam = Exam( ...newExamData )
    /// let success = updateListDatabase(exam: updatedExam)
    /// ```
    func updateListDatabase(exam: Exam) -> Bool {
        let name = exam.name
        let version = exam.version
        let origin = exam.origin
        let description = exam.description
        let lastUpdated = exam.lastUpdated.ISO8601Format()
        let fileName = exam.fileName
        let questionAmount = exam.questionAmount

        let updateQuery = """
        UPDATE exams 
        SET name = ?, version = ?, origin = ?, description = ?, last_updated = ?, question_amount = ?
        WHERE file_name = ? 
        AND (version < ? OR (version = ? AND last_updated < ?));
        """
        
        print("\nDatabaseService.updateListDatabase(): Updating exam \(name) with version \(version)")
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(listDB, updateQuery, -1, &statement, nil) != SQLITE_OK {
           let errmsg = String(cString: sqlite3_errmsg(listDB)!)
           print("    Error preparing update: \(errmsg)")
           return false
        }

        sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (version as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (origin as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (description as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (lastUpdated as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 6, Int32(questionAmount))
        sqlite3_bind_text(statement, 7, (fileName as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 8, (version as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 9, (version as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 10, (lastUpdated as NSString).utf8String, -1, nil)

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)
           
        /// - Note: even if the update failed because of the requied row does not exist, SQLITE_DONE will still be returned true. So we need to make sure the process actually "Succeed"
        let rowsAffected = sqlite3_changes(listDB)
        return result == SQLITE_DONE && rowsAffected > 0
    }
    
    /// Retrieves all exams from the list database.
    /// - Returns: An array of Exam objects.
    /// - Note: Assosiate with `list.db`
    ///
    /// Example usage:
    /// ```
    /// let exams = getExamList()
    /// for exam in exams {
    ///     print(exam.name)
    /// }
    /// ```
    func getExamList() -> [Exam] {
        let query = "SELECT id, name, version, origin, description, last_updated, question_amount, file_name FROM exams;"
        print("\nDatabaseService.getExamList(): retrieving exam list")
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(listDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(listDB)!)
            print("    Error preparing query: \(errmsg)")
            return []
        }

        var exams: [Exam] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
            let name = String(cString: sqlite3_column_text(statement, 1))
            let version = String(cString: sqlite3_column_text(statement, 2))
            let origin = String(cString: sqlite3_column_text(statement, 3))
            let description = String(cString: sqlite3_column_text(statement, 4))
            let lastUpdated = ISO8601DateFormatter().date(from: String(cString: sqlite3_column_text(statement, 5))) ?? Date()
            let questionAmount = Int(sqlite3_column_int64(statement, 6))
            let fileName = String(cString: sqlite3_column_text(statement, 7))
            let exam = Exam(id: id, name: name, version: version, origin: origin, description: description, lastUpdated: lastUpdated, fileName: fileName, questionAmount: questionAmount)
            exams.append(exam)
            print("    found exam: \(name)")
        }
        sqlite3_finalize(statement)
        return exams
    }


    /// Initializes the question database for a specific exam.
    /// - Parameter fileName: The name of the file for the exam database.
    /// - Note: This function creates a file `{fileName}.db` and two tables: 'topics' and 'questions'.
    ///
    /// Example usage:
    /// ```
    /// initQuestionDatabase(fileName: "math101")
    /// ```
    func initExamDatabase(fileName: String) {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(fileName).db")
        print("\nInitializing \(fileName).db:")
        if sqlite3_open(fileURL.path, &examDB) != SQLITE_OK {
            print("    Error opening question database")
            return
        }

        let createTopicTableString = """
        CREATE TABLE IF NOT EXISTS topics(
            id TEXT PRIMARY KEY,
            name TEXT,
            UNIQUE(name)
        );
        """

        if sqlite3_exec(examDB, createTopicTableString, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error creating topics table: \(errmsg)")
        }

        let createQuestionTableString = """
        CREATE TABLE IF NOT EXISTS questions(
            id TEXT PRIMARY KEY,
            topic_id TEXT,
            "index" INT,
            body TEXT,
            options TEXT,
            correct_answers TEXT,
            marked BOOLEAN,
            offset REAL,
            FOREIGN KEY (topic_id) REFERENCES topics(id)
            UNIQUE(body, options, "index")
        );
        """

        if sqlite3_exec(examDB, createQuestionTableString, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error creating table: \(errmsg)")
        }
        
        let createAttemptHistoryTableString = """
        CREATE TABLE IF NOT EXISTS attempt_history(
            id TEXT PRIMARY KEY,
            exam_id TEXT,
            version TEXT,
            attempt_id INTEGER,
            mode TEXT,
            score REAL,
            finished_question_amount INTEGER
        );
        """

        if sqlite3_exec(examDB, createAttemptHistoryTableString, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error creating attempt_history table: \(errmsg)")
        }

        let createQuestionHistoryTableString = """
        CREATE TABLE IF NOT EXISTS question_history(
            id TEXT PRIMARY KEY,
            attempt_history_id TEXT,
            question_id TEXT,
            is_correct INTEGER,
            user_answer TEXT,
            FOREIGN KEY (attempt_history_id) REFERENCES attempt_history(id),
            FOREIGN KEY (question_id) REFERENCES questions(id)
            UNIQUE(attempt_history_id, question_id)
        );
        """

        if sqlite3_exec(examDB, createQuestionHistoryTableString, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error creating question_history table: \(errmsg)")
        }
    }
    
    /// insert topic into current exam database
    /// - Note: please make sure the pointer `examDB` is pointing to your desired database.
    func insertTopic (topic: Topic) -> Bool {
        // print("\nInserting topic: \(topic.name)")
        let id = topic.id.uuidString
        let name = topic.name

        let insertQuery = """
        INSERT OR IGNORE INTO topics (id, name)
        VALUES (?, ?);
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing insert: \(errmsg)")
            return false
        }

        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, nil)

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)

        return result == SQLITE_DONE
    }
    
    /// insert question into current exam database
    /// - Note: please make sure the pointer `examDB` is pointing to your desired database.
    func insertQuestion (question: Question) -> Bool {
        // print("\nInserting question: \(question.body)")
        let id = question.id.uuidString
        let topicId = question.topicId.uuidString
        let index = question.index
        let body = question.body
        let options = escapeAndJoin(question.options)
        let correctAnswers = escapeAndJoin(question.correctAnswers)
        let marked = question.marked
        let offset = question.offset

        let insertQuery = """
        INSERT OR IGNORE INTO questions (id, topic_id, "index", body, options, correct_answers, marked, offset)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing insert: \(errmsg)")
            return false
        }

        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (topicId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 3, Int32(index))
        sqlite3_bind_text(statement, 4, (body as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (options as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (correctAnswers as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 7, marked ? 1 : 0)
        sqlite3_bind_double(statement, 8, Double(offset))

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)

        return result == SQLITE_DONE
    }
    
    /// insert attempt history into current exam database
    /// - Note: please make sure the pointer `examDB` is pointing to your desired database.
    func insertAttemptHistory (attemptHistory: AttemptHistory) -> Bool {
        print("\nInserting attempt history: \(attemptHistory.id)")
        let id = attemptHistory.id.uuidString
        let examId = attemptHistory.examId.uuidString
        let version = attemptHistory.version
        let attemptId = attemptHistory.attemptId
        let mode = attemptHistory.mode
        let score = attemptHistory.score
        let finishedQuestionAmount = attemptHistory.finishedQuestionAmount

        let insertQuery = """
        INSERT OR REPLACE INTO attempt_history (id, exam_id, version, attempt_id, mode, score, finished_question_amount)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing insert: \(errmsg)")
            return false
        }

        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (examId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (version as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 4, Int32(attemptId))
        sqlite3_bind_text(statement, 5, (mode as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 6, Double(score))
        sqlite3_bind_int(statement, 7, Int32(finishedQuestionAmount))

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement) 

        return result == SQLITE_DONE
    }


    /// update attempt history in current exam database
    func updateAttemptHistory(attemptHistory: AttemptHistory) -> Bool {
        let query = "UPDATE attempt_history SET score = ?, finished_question_amount = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing update: \(errmsg)")
            return false
        }

        sqlite3_bind_double(statement, 1, Double(attemptHistory.score))
        sqlite3_bind_int(statement, 2, Int32(attemptHistory.finishedQuestionAmount))
        sqlite3_bind_text(statement, 3, (attemptHistory.id.uuidString as NSString).utf8String, -1, nil)

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)

        return result == SQLITE_DONE
    }   
    
    /// insert question history into current exam database
    /// - Note: please make sure the pointer `examDB` is pointing to your desired database.
    func insertQuestionHistory (questionHistory: QuestionHistory) -> Bool {
        print("\nInserting question history: \(questionHistory.id)")
        let id = questionHistory.id.uuidString
        let attemptHistoryId = questionHistory.attemptHistoryId.uuidString
        let questionId = questionHistory.questionId.uuidString
        let isCorrect = questionHistory.isCorrect
        let userAnswer = escapeAndJoin(questionHistory.userAnswer)

        let insertQuery = """
        INSERT OR REPLACE INTO question_history (id, attempt_history_id, question_id, is_correct, user_answer)
        VALUES (?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing insert: \(errmsg)")
            return false
        }

        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (attemptHistoryId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (questionId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 4, isCorrect ? 1 : 0)
        sqlite3_bind_text(statement, 5, (userAnswer as NSString).utf8String, -1, nil)

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)

        return result == SQLITE_DONE
    }


    /// remove question history from current exam database
    func removeQuestionHistory(questionId: UUID, attemptHistoryId: UUID) -> Bool {
        let query = "DELETE FROM question_history WHERE question_id = ? AND attempt_history_id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing delete: \(errmsg)")
            return false
        }

        sqlite3_bind_text(statement, 1, (questionId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (attemptHistoryId.uuidString as NSString).utf8String, -1, nil)

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)

        return result == SQLITE_DONE
    }


    /// get the finished question amount of an attempt history, used in displaying exam attempt progress.
    /// - Note: please make sure the pointer `examDB` is pointing to your desired database. 
    /// - Returns: the finished question amount of an attempt history
    /// - Returns: 0 if the attempt history is not found
    ///
    /// Example usage:
    /// ```
    /// let finishedQuestionAmount = getFinishedQuestionAmount(attemptHistoryId: attemptHistory.id)
    /// ```
    func getFinishedQuestionAmount(attemptHistoryId: UUID) -> Int {
        let query = "SELECT finished_question_amount FROM attempt_history WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing query: \(errmsg)")
            return 0
        }

        sqlite3_bind_text(statement, 1, (attemptHistoryId.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            let finishedQuestionAmount = Int(sqlite3_column_int(statement, 0))
            sqlite3_finalize(statement)
            return finishedQuestionAmount
        }
        sqlite3_finalize(statement)
        return 0
    }


    /// Retrieves a dictionary representing the status of questions in an exam attempt.
    /// - Returns: A dictionary where the key is the question index and the value is a tuple (marked: Bool, answered: Bool, id: UUID).
    /// - Note: This function is useful for ListView navigation and real-time progress tracking, which trades off less content for better performance.
    ///
    /// Example usage:
    /// ```
    /// let listView = getQuestionListMap()
    /// ```
    func getQuestionListMap() -> [Int: (marked: Bool, answered: Bool, id: UUID)] {
        print("\nGetting question list map")
        /// Understand this query:
        /// 1. selecting the index, marked, and answered status of each question.
        /// 2. using a subquery to get the most recent attempt_id.
        /// 3. using a left join to get the question_history_id for each question.
        /// 4. using a case statement to determine if the question has been answered.
        /// 5. ordering the questions by index.
        let query = """
            SELECT q."index", q.marked, CASE WHEN qh.id IS NULL THEN 0 ELSE 1 END as answered, q.id
            FROM questions q
            LEFT JOIN (
                SELECT qh.question_id, qh.id
                FROM question_history qh
                JOIN attempt_history ah ON qh.attempt_history_id = ah.id
                WHERE ah.id = (SELECT id FROM attempt_history ORDER BY attempt_id DESC LIMIT 1)
            ) qh ON q.id = qh.question_id
            ORDER BY q."index";
        """
        
        var statement: OpaquePointer?
        var listView: [Int: (marked: Bool, answered: Bool, id: UUID)] = [:]
        
        if sqlite3_prepare_v2(examDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing query: \(errmsg)")
            return listView
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let index = Int(sqlite3_column_int(statement, 0))
            let marked = sqlite3_column_int(statement, 1) != 0
            let answered = sqlite3_column_int(statement, 2) != 0
            let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 3)))!
            
            listView[index] = (marked: marked, answered: answered, id: id)
        }
        
        sqlite3_finalize(statement)
        return listView
    }


    /// Simply get the question by id, used in question detail page.
    /// - Note: if there's a version conflict, the user answer will be null.

    func getQuestionById(id: UUID, version: String) -> Question? {
        let query = """
            SELECT q.*, qh.user_answer, ah.version as attempt_version
            FROM questions q
            LEFT JOIN (
                SELECT qh.question_id, qh.user_answer, ah.version, ah.id as attempt_id
                FROM question_history qh
                JOIN attempt_history ah ON qh.attempt_history_id = ah.id
                WHERE ah.id = (SELECT id FROM attempt_history ORDER BY attempt_id DESC LIMIT 1)
            ) qh ON q.id = qh.question_id
            LEFT JOIN attempt_history ah ON qh.attempt_id = ah.id
            WHERE q.id = ?;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing query: \(errmsg)")
            return nil
        }

        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
            let topicId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))!
            let index = Int(sqlite3_column_int(statement, 2))
            let body = String(cString: sqlite3_column_text(statement, 3))
            let options = escapeAndSplit(String(cString: sqlite3_column_text(statement, 4)))
            let correctAnswers = escapeAndSplit(String(cString: sqlite3_column_text(statement, 5)))
            let marked = sqlite3_column_int(statement, 6) != 0
            let offset = Float(sqlite3_column_double(statement, 7))
            let userAnswers = sqlite3_column_text(statement, 8) != nil ? escapeAndSplit(String(cString: sqlite3_column_text(statement, 8))) : nil
            let attemptVersion = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)) : nil

            // Only use userAnswers if the attempt version matches the current version
            let finalUserAnswers = (attemptVersion == version) ? userAnswers : nil

            let question = Question(id: id, topicId: topicId, body: body, index: index, options: options, correctAnswers: correctAnswers, marked: marked, offset: offset, userAnswers: finalUserAnswers)
            sqlite3_finalize(statement)
            return question
        }
        sqlite3_finalize(statement)
        return nil  
    }   


    /// Get the latest attempt history of an exam.
    /// - Note: if the version is different, or previous attempt is finished, return empty history.
    /// - Returns: the latest attempt history, or an empty attempt history if not found
    func getLatestAttemptHistory(exam: Exam) -> AttemptHistory? {
        let query = "SELECT * FROM attempt_history WHERE exam_id = ? ORDER BY attempt_id DESC LIMIT 1;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing query: \(errmsg)")
            return nil
        }

        sqlite3_bind_text(statement, 1, (exam.id.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
            let examId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))!
            let version = String(cString: sqlite3_column_text(statement, 2))
            let attemptId = Int(sqlite3_column_int(statement, 3))
            let mode = String(cString: sqlite3_column_text(statement, 4))
            let score = Double(sqlite3_column_double(statement, 5))
            let finishedQuestionAmount = Int(sqlite3_column_int(statement, 6))

            guard finishedQuestionAmount == exam.questionAmount || version == exam.version else {
                return returnEmptyAttemptHistory(exam: exam)
            }

            let attemptHistory = AttemptHistory(id: id, examId: examId, version: version, attemptId: attemptId, finishedQuestionAmount: finishedQuestionAmount, mode: mode, score: score)
            sqlite3_finalize(statement)
            return attemptHistory
        }
        sqlite3_finalize(statement)

        return returnEmptyAttemptHistory(exam: exam)
    }   

    /// Return an empty attempt history with the given exam. also insert it into the database.
    private func returnEmptyAttemptHistory(exam: Exam) -> AttemptHistory {
        let emptyAttemptHistory = AttemptHistory( 
            id: UUID(), 
            examId: exam.id, 
            version: exam.version, 
            attemptId: 1, 
            finishedQuestionAmount: 0, 
            mode: "", 
            score: -1
        )

        print("    Inserting empty attempt history: \(emptyAttemptHistory.id)")
        if !insertAttemptHistory(attemptHistory: emptyAttemptHistory){
            print("    Error inserting empty attempt history: \(emptyAttemptHistory.id)")
        }
        return emptyAttemptHistory
    }

    /// Set the marked status of a question.
    func setMarked(question: Question) -> Bool {
        let query = "UPDATE questions SET marked = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(examDB, query, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(examDB)!)
            print("    Error preparing query: \(errmsg)")
            return false
        }

        sqlite3_bind_int(statement, 1, question.marked ? 1 : 0)
        sqlite3_bind_text(statement, 2, (question.id.uuidString as NSString).utf8String, -1, nil)

        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)

        return result == SQLITE_DONE
    }   

    /// Set the pointer `examDB` to the database with the given filename.
    func setCurrentExamDb(filename: String) {
        print("\nSetting current exam database to: \(filename)")
        if let db = examDB {
            sqlite3_close(db)
            examDB = nil
        }
        
        let fileURL = try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(filename).db")
        
        guard let url = fileURL else {
            print("    Error reaching file URL")
            return
        }
        
        if sqlite3_open(url.path, &examDB) != SQLITE_OK {
            print("    Error opening exam database")
            return
        }
    }   
    /// Helper function for inserting array into sqlite database.
    /// The reason for this function is to avoid the issue where the string contains '||' which will be treated as a delimiter. In this case, we are trading off some performance for safety.
    /// - Parameter strings: An array of strings to be joined with '||'
    /// - Returns: A string that is the joined array, with each element escaped by replacing '||' with '\\|'
    /// - Example:
    ///     - Input: ["hello", "world"]
    ///     - Output: "hello||world"
    ///     - Input: ["hello||world", "hello|world"]
    ///     - Output: "hello\\|\\|world||hello\\|world"
    private func escapeAndJoin(_ strings: [String]) -> String {
        return strings.map { $0.replacingOccurrences(of: "||", with: "\\||") }.joined(separator: "||")
    }

    /// Helper function for splitting a string into an array of strings.
    /// - Parameter string: A string that is the joined array, with each element escaped by replacing '||' with '\\|'
    /// - Returns: An array of strings
    /// - Note: This function is used to reverse the process of `escapeAndJoin`.
    /// - Example:
    ///     - Input: "hello||world||hello\\|world"
    ///     - Output: ["hello", "world", "hello|world"] (Note: "|" is not escaped)
    private func escapeAndSplit(_ string: String) -> [String] {
        return string.split(separator: "||").map { $0.replacingOccurrences(of: "\\|", with: "||") }
    }
}
