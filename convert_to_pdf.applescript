set htmlFilePath to "/Users/matvey/Dev/MusicVisualizer/OPTIMIZATION_ROADMAP.html"
set pdfFilePath to "/Users/matvey/Dev/MusicVisualizer/OPTIMIZATION_ROADMAP.pdf"

tell application "Safari"
    activate
    set newDoc to make new document with properties {URL:"file://" & htmlFilePath}
    delay 3
    tell newDoc to print with print dialog without showing print dialog
    delay 2
    close newDoc
    quit
end tell