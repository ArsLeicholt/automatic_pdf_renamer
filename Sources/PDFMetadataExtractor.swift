import Foundation
import PDFKit

struct PDFMetadata {
    let title: String?
    let author: String?
    let subject: String?
    let creator: String?
    let producer: String?
    let creationDate: Date?
    let modificationDate: Date?
    let keywords: [String]
    
    var firstAuthor: String? {
        guard let author = author, !author.isEmpty else { return nil }
        
        let cleanedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let separators = [",", ";", " and ", " & ", "\n"]
        for separator in separators {
            if cleanedAuthor.contains(separator) {
                let authors = cleanedAuthor.components(separatedBy: separator)
                if let firstAuthor = authors.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !firstAuthor.isEmpty {
                    return extractLastName(from: firstAuthor)
                }
            }
        }
        
        return extractLastName(from: cleanedAuthor)
    }
    
    var year: String? {
        guard let date = creationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    private func extractLastName(from fullName: String) -> String {
        let components = fullName.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if components.count >= 2 {
            return components.last ?? fullName
        }
        
        return fullName
    }
}

class PDFMetadataExtractor {
    
    func extractMetadata(from fileURL: URL) throws -> PDFMetadata {
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            throw PDFMetadataError.unableToOpenPDF
        }
        
        let documentAttributes = pdfDocument.documentAttributes
        
        var title = documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        var author = documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String
        let subject = documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String
        let creator = documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String
        let producer = documentAttributes?[PDFDocumentAttribute.producerAttribute] as? String
        let creationDate = documentAttributes?[PDFDocumentAttribute.creationDateAttribute] as? Date
        let modificationDate = documentAttributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date
        
        var keywords: [String] = []
        if let keywordsString = documentAttributes?[PDFDocumentAttribute.keywordsAttribute] as? String {
            keywords = keywordsString.components(separatedBy: CharacterSet(charactersIn: ",;")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        
        // If metadata is missing, try to extract from text content
        if title == nil || author == nil {
            let extractedText = try extractTextFromFirstPages(from: fileURL, pageLimit: 2)
            
            if title == nil {
                title = extractTitleFromText(extractedText)
            }
            
            if author == nil {
                author = extractAuthorFromText(extractedText)
            }
        }
        
        let metadata = PDFMetadata(
            title: title,
            author: author,
            subject: subject,
            creator: creator,
            producer: producer,
            creationDate: creationDate,
            modificationDate: modificationDate,
            keywords: keywords
        )
        
        return metadata
    }
    
    private func extractTitleFromText(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Look for the first substantial line that could be a title
        for line in lines.prefix(10) {
            if line.count > 10 && line.count < 200 && !line.contains("@") && !line.contains("http") {
                // Clean up common title patterns
                let cleanedLine = line
                    .replacingOccurrences(of: "^\\d+\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if cleanedLine.count > 10 {
                    return cleanedLine
                }
            }
        }
        
        return nil
    }
    
    private func extractAuthorFromText(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Look for author patterns
        for (index, line) in lines.enumerated() {
            // Skip very short lines and lines that look like headers
            if line.count < 5 || line.count > 100 {
                continue
            }
            
            // Look for common author patterns
            if line.range(of: "^[A-Z][a-z]+ [A-Z][a-z]+", options: .regularExpression) != nil ||
               line.range(of: "^[A-Z]\\. [A-Z][a-z]+", options: .regularExpression) != nil ||
               line.range(of: "and ", options: .caseInsensitive) != nil {
                
                // Make sure it's not a title (usually comes after title)
                if index > 0 && index < 15 {
                    return line
                }
            }
        }
        
        return nil
    }
    
    func extractTextFromFirstPages(from fileURL: URL, pageLimit: Int = 3) throws -> String {
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            throw PDFMetadataError.unableToOpenPDF
        }
        
        var extractedText = ""
        let maxPages = min(pageLimit, pdfDocument.pageCount)
        
        for pageIndex in 0..<maxPages {
            if let page = pdfDocument.page(at: pageIndex) {
                if let pageText = page.string {
                    extractedText += pageText + "\n"
                }
            }
        }
        
        return extractedText
    }
}

enum PDFMetadataError: LocalizedError {
    case unableToOpenPDF
    case noMetadataFound
    
    var errorDescription: String? {
        switch self {
        case .unableToOpenPDF:
            return "Unable to open PDF file"
        case .noMetadataFound:
            return "No metadata found in PDF"
        }
    }
}