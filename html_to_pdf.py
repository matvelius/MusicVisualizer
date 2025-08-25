#!/usr/bin/env python3
import os
import subprocess
import sys

def html_to_pdf():
    html_file = "/Users/matvey/Dev/MusicVisualizer/OPTIMIZATION_ROADMAP.html"
    pdf_file = "/Users/matvey/Dev/MusicVisualizer/OPTIMIZATION_ROADMAP.pdf"
    
    try:
        # Try using wkhtmltopdf if available
        result = subprocess.run(['which', 'wkhtmltopdf'], capture_output=True)
        if result.returncode == 0:
            subprocess.run(['wkhtmltopdf', html_file, pdf_file])
            print(f"PDF created using wkhtmltopdf: {pdf_file}")
            return
    except:
        pass
    
    try:
        # Try using WeasyPrint (requires installation)
        import weasyprint
        weasyprint.HTML(filename=html_file).write_pdf(pdf_file)
        print(f"PDF created using WeasyPrint: {pdf_file}")
        return
    except ImportError:
        pass
    
    try:
        # Use system print command with PDF output
        import tempfile
        import shutil
        
        # Create a simple shell script to open and print
        script = f"""
        open -a Safari "{html_file}"
        sleep 3
        osascript -e 'tell application "Safari" to print the front document'
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
            f.write(script)
            script_path = f.name
        
        os.chmod(script_path, 0o755)
        subprocess.run([script_path])
        os.unlink(script_path)
        
        print("Attempted to print via Safari - check your Downloads folder for the PDF")
        
    except Exception as e:
        print(f"All PDF conversion methods failed: {e}")
        print("\nAlternative solutions:")
        print("1. Open the HTML file in a browser and use Print > Save as PDF")
        print("2. Install pandoc: brew install pandoc")
        print("3. Install wkhtmltopdf: brew install wkhtmltopdf")
        print(f"\nHTML file is available at: {html_file}")

if __name__ == "__main__":
    html_to_pdf()