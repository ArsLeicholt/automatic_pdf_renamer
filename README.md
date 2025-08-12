# Automatic PDF Renamer

A macOS menu bar application that automatically renames PDF files based on their metadata.

## Overview

Automatic PDF Renamer is a lightweight macOS menu bar utility designed for researchers, academics, and anyone who works with large collections of PDF documents. It automatically renames PDF files using their embedded metadata, creating consistent, meaningful filenames.

## Features

- Automatic PDF renaming based on embedded metadata
- Smart metadata extraction (title, author, date, journal)
- Text content parsing when metadata is missing
- Multiple folder monitoring
- 5 academic naming patterns available
- Menu bar integration with background operation
- Launch at login option
- Real-time processing of new PDFs
- Local processing (no network access)
- Sandboxed security model

## Installation

### Option 1: Download Repository
1. Download the latest repository version
2. Unzip and drag `Automatic PDF Renamer.app` to Applications folder
3. Launch from Applications or Spotlight

### Option 2: Build from Source
```bash
git clone https://github.com/yourusername/automatic-pdf-renamer.git
cd automatic-pdf-renamer
```

Then open Xcode and build the project, or use the command line:

## Usage

1. Launch the app - Look for the document icon in your menu bar
2. Add folders - Click the menu bar icon → "Add Folder to Monitor"
3. Select naming pattern - Choose your preferred format
4. Start monitoring - The app will automatically process PDFs

Example transformation:
```
Before: journal.pone.0123456.pdf
After:  Smith_Machine_Learning_Applications_PLOS_2024.pdf
```

## Building

Requirements: macOS 13.0+, Xcode 14.0+ or Command Line Tools

```bash
# Compile the Swift files directly
swiftc -o "Automatic PDF Renamer" Sources/*.swift -framework AppKit -framework PDFKit

# Or use Xcode to open and build the project
```

## Project Structure

```
├── Sources/                    # Swift source code
│   ├── main_fixed.swift       # Main application entry point
│   ├── FileMonitor.swift      # File system monitoring
│   ├── PDFMetadataExtractor.swift  # PDF metadata parsing
│   ├── NamingPatternManager.swift  # Filename pattern logic
│   └── SimpleFolderManager.swift   # Folder management
└── Scripts/                    # Build configuration
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
