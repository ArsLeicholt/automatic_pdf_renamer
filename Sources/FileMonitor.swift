import Foundation

class FileMonitor: ObservableObject {
    var onFileProcessed: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    private var eventStream: FSEventStreamRef?
    private var folderURL: URL?
    private var namingPattern: NamingPattern?
    private let metadataExtractor = PDFMetadataExtractor()
    
    func startMonitoring(folderURL: URL, namingPattern: NamingPattern) {
        stopMonitoring()
        
        self.folderURL = folderURL
        self.namingPattern = namingPattern
        
        processExistingPDFs(in: folderURL)
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            let fileMonitor = Unmanaged<FileMonitor>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()
            fileMonitor.handleFSEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
        }
        
        let pathsToWatch = [folderURL.path] as CFArray
        
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )
        
        if let eventStream = eventStream {
            FSEventStreamSetDispatchQueue(eventStream, DispatchQueue.main)
            FSEventStreamStart(eventStream)
        }
    }
    
    private func processExistingPDFs(in folderURL: URL) {
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
                let pdfFiles = fileURLs.filter { $0.pathExtension.lowercased() == "pdf" }
                
                DispatchQueue.main.async {
                    self.onError?("Found \(pdfFiles.count) PDF files to process")
                }
                
                for pdfFile in pdfFiles {
                    self.processPDFFile(at: pdfFile)
                    Thread.sleep(forTimeInterval: 0.5)
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?("Error scanning folder: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopMonitoring() {
        if let eventStream = eventStream {
            FSEventStreamStop(eventStream)
            FSEventStreamInvalidate(eventStream)
            FSEventStreamRelease(eventStream)
            self.eventStream = nil
        }
    }
    
    private func handleFSEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        guard numEvents > 0 else { return }
        
        let pathsPointer = eventPaths.bindMemory(to: UnsafePointer<CChar>.self, capacity: numEvents)
        let pathsBuffer = UnsafeBufferPointer(start: pathsPointer, count: numEvents)
        let paths = pathsBuffer.map { pathPtr in
            String(cString: pathPtr)
        }
        let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
        
        for (index, path) in paths.enumerated() {
            guard index < flags.count else { continue }
            let flag = flags[index]
            
            if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
                let fileURL = URL(fileURLWithPath: path)
                
                if fileURL.pathExtension.lowercased() == "pdf" {
                    DispatchQueue.global(qos: .background).async {
                        self.processPDFFile(at: fileURL)
                    }
                }
            }
        }
    }
    
    private func processPDFFile(at fileURL: URL) {
        guard let pattern = namingPattern else { 
            self.onError?("No naming pattern set")
            return 
        }
        
        do {
            let metadata = try metadataExtractor.extractMetadata(from: fileURL)
            let newFileName = pattern.generateFileName(from: metadata)
            
            let newFileURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFileName)
            
            if newFileURL != fileURL {
                if FileManager.default.fileExists(atPath: newFileURL.path) {
                    self.onError?("File \(newFileName) already exists")
                    return
                }
                
                try FileManager.default.moveItem(at: fileURL, to: newFileURL)
                self.onFileProcessed?(newFileName)
            } else {
                self.onError?("File \(fileURL.lastPathComponent) already has correct name")
            }
            
        } catch {
            self.onError?("Failed to process \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
