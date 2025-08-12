import AppKit
import Foundation

class PDFRenamerMenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var folderManager = SimpleFolderManager()
    private var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupMenuBar()
        setupLaunchAtLogin()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "PDF Renamer")
            button.image?.size = NSSize(width: 16, height: 16)
            button.image?.isTemplate = true
        }
        
        setupMenu()
        statusItem.menu = menu
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Automatic PDF Renamer", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let addFolderItem = NSMenuItem(title: "Add Folder to Monitor", action: #selector(addFolder), keyEquivalent: "")
        addFolderItem.target = self
        menu.addItem(addFolderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        
        let statusItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Automatic PDF Renamer", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        updateMenu()
    }
    
    @objc private func addFolder() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = false
        openPanel.message = "Select a folder to monitor for PDF files"
        openPanel.prompt = "Select Folder"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                // Use default pattern
                self.folderManager.addFolder(url: url, pattern: .authorTitleJournalYear)
                self.updateMenu()
                
                let alert = NSAlert()
                alert.messageText = "Folder Added"
                alert.informativeText = "Now monitoring: \(url.lastPathComponent)\nPattern: author_title_journal_year.pdf"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    private func updateMenu() {
        // Remove existing folder items (keep first 7 static items)
        while menu.numberOfItems > 7 {
            menu.removeItem(at: 7)
        }
        
        // Add folder items before the final separator and quit
        let insertIndex = menu.numberOfItems - 2
        
        for folder in folderManager.monitoredFolders {
            let folderItem = NSMenuItem(title: "📁 \(folder.url.lastPathComponent)", action: nil, keyEquivalent: "")
            folderItem.isEnabled = false
            menu.insertItem(folderItem, at: insertIndex)
            
            let removeItem = NSMenuItem(title: "  Remove this folder", action: #selector(removeFolder(_:)), keyEquivalent: "")
            removeItem.target = self
            removeItem.representedObject = folder.id
            menu.insertItem(removeItem, at: insertIndex + 1)
        }
        
        // Update status (now at index 5 due to launch at login item)
        if let statusItem = menu.item(at: 5) {
            let count = folderManager.monitoredFolders.count
            statusItem.title = "Status: Monitoring \(count) folder\(count == 1 ? "" : "s")"
        }
    }
    
    @objc private func removeFolder(_ sender: NSMenuItem) {
        guard let folderId = sender.representedObject as? UUID,
              let folder = folderManager.monitoredFolders.first(where: { $0.id == folderId }) else {
            return
        }
        
        folderManager.removeFolder(folder)
        updateMenu()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func setupLaunchAtLogin() {
        updateLaunchAtLoginMenuState()
    }
    
    @objc private func toggleLaunchAtLogin() {
        let isEnabled = isLaunchAtLoginEnabled()
        setLaunchAtLogin(!isEnabled)
        updateLaunchAtLoginMenuState()
    }
    
    private func updateLaunchAtLoginMenuState() {
        if let launchItem = menu.item(withTitle: "Launch at Login") {
            launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        }
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        guard let _ = Bundle.main.bundleIdentifier else { return false }
        
        // Check if app is in login items using System Preferences method
        let script = """
        tell application "System Events"
            try
                return (exists login item "\(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Automatic PDF Renamer")")
            on error
                return false
            end try
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(nil)
            return result.booleanValue
        }
        
        return false
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Automatic PDF Renamer"
        let appPath = Bundle.main.bundlePath
        
        let action = enabled ? "make" : "delete"
        let script = """
        tell application "System Events"
            try
                \(action) login item "\(appName)" at end with properties {path:"\(appPath)", hidden:false}
            on error
                -- Ignore errors
            end try
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }
}

@main
struct PDFRenamerMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = PDFRenamerMenuBarApp()
        app.delegate = delegate
        app.run()
    }
}