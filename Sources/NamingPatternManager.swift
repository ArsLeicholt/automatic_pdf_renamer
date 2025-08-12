import Foundation

enum NamingPattern: CaseIterable, Codable {
    case authorTitleJournalYear
    case titleAuthorYear
    case authorYearTitle
    case yearAuthorTitle
    case authorTitleYear
    
    var description: String {
        switch self {
        case .authorTitleJournalYear:
            return "firstauthor_title_journal_year.pdf"
        case .titleAuthorYear:
            return "title_firstauthor_year.pdf"
        case .authorYearTitle:
            return "firstauthor_year_title.pdf"
        case .yearAuthorTitle:
            return "year_firstauthor_title.pdf"
        case .authorTitleYear:
            return "firstauthor_title_year.pdf"
        }
    }
    
    var exampleOutput: String {
        switch self {
        case .authorTitleJournalYear:
            return "Smith_Machine_Learning_in_Biology_Nature_2023.pdf"
        case .titleAuthorYear:
            return "Machine_Learning_in_Biology_Smith_2023.pdf"
        case .authorYearTitle:
            return "Smith_2023_Machine_Learning_in_Biology.pdf"
        case .yearAuthorTitle:
            return "2023_Smith_Machine_Learning_in_Biology.pdf"
        case .authorTitleYear:
            return "Smith_Machine_Learning_in_Biology_2023.pdf"
        }
    }
    
    func generateFileName(from metadata: PDFMetadata) -> String {
        let author = sanitizeForFilename(metadata.firstAuthor ?? "Unknown_Author")
        let title = sanitizeForFilename(metadata.title ?? "Unknown_Title")
        let year = metadata.year ?? "Unknown_Year"
        let journal = extractJournal(from: metadata)
        
        var fileName: String
        
        switch self {
        case .authorTitleJournalYear:
            fileName = "\(author)_\(title)_\(journal)_\(year)"
        case .titleAuthorYear:
            fileName = "\(title)_\(author)_\(year)"
        case .authorYearTitle:
            fileName = "\(author)_\(year)_\(title)"
        case .yearAuthorTitle:
            fileName = "\(year)_\(author)_\(title)"
        case .authorTitleYear:
            fileName = "\(author)_\(title)_\(year)"
        }
        
        return fileName + ".pdf"
    }
    
    private func sanitizeForFilename(_ string: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/<>:\"|\\?*")
        let sanitized = string.components(separatedBy: invalidChars).joined(separator: "_")
        
        let words = sanitized.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        
        let result = words.joined(separator: "_")
        
        return result.isEmpty ? "Unknown" : String(result.prefix(100))
    }
    
    private func extractJournal(from metadata: PDFMetadata) -> String {
        if let subject = metadata.subject, !subject.isEmpty {
            return sanitizeForFilename(subject)
        }
        
        if let producer = metadata.producer, !producer.isEmpty {
            let journalHints = ["IEEE", "ACM", "Nature", "Science", "Cell", "PLOS", "Elsevier", "Springer", "Wiley"]
            for hint in journalHints {
                if producer.localizedCaseInsensitiveContains(hint) {
                    return sanitizeForFilename(hint)
                }
            }
        }
        
        if let title = metadata.title {
            let journalKeywords = ["journal", "proceedings", "transactions", "letters", "review"]
            for keyword in journalKeywords {
                if title.localizedCaseInsensitiveContains(keyword) {
                    let words = title.components(separatedBy: .whitespacesAndNewlines)
                    if let keywordIndex = words.firstIndex(where: { $0.localizedCaseInsensitiveContains(keyword) }) {
                        let journalWords = Array(words[max(0, keywordIndex-1)...min(words.count-1, keywordIndex+1)])
                        return sanitizeForFilename(journalWords.joined(separator: " "))
                    }
                }
            }
        }
        
        return "Unknown_Journal"
    }
}

class NamingPatternManager: ObservableObject {
    @Published var currentPattern: NamingPattern = .authorTitleJournalYear {
        didSet {
            savePattern()
        }
    }
    
    @Published var lastSelectedFolderPath: String? {
        didSet {
            saveLastSelectedFolder()
        }
    }
    
    private let patternUserDefaultsKey = "SelectedNamingPattern"
    private let folderUserDefaultsKey = "LastSelectedFolder"
    
    init() {
        loadSavedSettings()
    }
    
    private func loadSavedSettings() {
        if let savedPatternIndex = UserDefaults.standard.object(forKey: patternUserDefaultsKey) as? Int,
           savedPatternIndex < NamingPattern.allCases.count {
            currentPattern = NamingPattern.allCases[savedPatternIndex]
        }
        
        lastSelectedFolderPath = UserDefaults.standard.string(forKey: folderUserDefaultsKey)
    }
    
    private func savePattern() {
        if let index = NamingPattern.allCases.firstIndex(of: currentPattern) {
            UserDefaults.standard.set(index, forKey: patternUserDefaultsKey)
        }
    }
    
    private func saveLastSelectedFolder() {
        UserDefaults.standard.set(lastSelectedFolderPath, forKey: folderUserDefaultsKey)
    }
    
    func setPattern(_ pattern: NamingPattern) {
        currentPattern = pattern
    }
    
    func setLastSelectedFolder(_ path: String?) {
        lastSelectedFolderPath = path
    }
}