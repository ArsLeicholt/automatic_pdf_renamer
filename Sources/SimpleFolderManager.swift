import Foundation

struct SimpleMonitoredFolder: Codable {
    let id = UUID()
    let url: URL
    var namingPattern: NamingPattern
    var processedCount: Int = 0
    var isActive: Bool = true
    
    private enum CodingKeys: String, CodingKey {
        case id, url, namingPattern, processedCount, isActive
    }
}

class SimpleFolderManager {
    var monitoredFolders: [SimpleMonitoredFolder] = []
    var isMonitoring: Bool = false
    var totalProcessedFiles: Int = 0
    var lastStatusMessage: String?
    
    private var fileMonitors: [UUID: FileMonitor] = [:]
    private let userDefaultsKey = "MonitoredFolders"
    
    init() {
        loadSavedFolders()
    }
    
    func addFolder(url: URL, pattern: NamingPattern) {
        let folder = SimpleMonitoredFolder(url: url, namingPattern: pattern)
        monitoredFolders.append(folder)
        startMonitoring(folder: folder)
        updateMonitoringStatus()
        saveFolders()
    }
    
    func removeFolder(_ folder: SimpleMonitoredFolder) {
        if let monitor = fileMonitors[folder.id] {
            monitor.stopMonitoring()
            fileMonitors.removeValue(forKey: folder.id)
        }
        
        monitoredFolders.removeAll { $0.id == folder.id }
        updateMonitoringStatus()
        saveFolders()
    }
    
    private func startMonitoring(folder: SimpleMonitoredFolder) {
        let monitor = FileMonitor()
        fileMonitors[folder.id] = monitor
        
        monitor.onFileProcessed = { fileName in
            DispatchQueue.main.async {
                self.handleFileProcessed(folderId: folder.id, fileName: fileName)
            }
        }
        
        monitor.onError = { error in
            DispatchQueue.main.async {
                self.lastStatusMessage = error
            }
        }
        
        monitor.startMonitoring(folderURL: folder.url, namingPattern: folder.namingPattern)
    }
    
    private func handleFileProcessed(folderId: UUID, fileName: String) {
        if let index = monitoredFolders.firstIndex(where: { $0.id == folderId }) {
            monitoredFolders[index].processedCount += 1
            totalProcessedFiles += 1
            lastStatusMessage = "Processed: \(fileName)"
        }
    }
    
    private func updateMonitoringStatus() {
        isMonitoring = !fileMonitors.isEmpty
    }
    
    private func saveFolders() {
        do {
            let data = try JSONEncoder().encode(monitoredFolders)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save monitored folders: \(error)")
        }
    }
    
    private func loadSavedFolders() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            let savedFolders = try JSONDecoder().decode([SimpleMonitoredFolder].self, from: data)
            monitoredFolders = savedFolders
            
            // Start monitoring for each saved folder
            for folder in monitoredFolders {
                startMonitoring(folder: folder)
            }
            
            updateMonitoringStatus()
        } catch {
            print("Failed to load monitored folders: \(error)")
        }
    }
}