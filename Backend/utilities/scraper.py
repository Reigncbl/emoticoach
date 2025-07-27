from fpdf import FPDF
import requests
from bs4 import BeautifulSoup
from unidecode import unidecode  # Handles Unicode to ASCII conversion

class PDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=True, margin=15)
        self.add_page()
        self.set_font("Arial", size=12)

    def add_chapter(self, title, content):
        self.set_font("Arial", "B", 14)
        self.cell(0, 10, unidecode(title), ln=True)  # Convert title to ASCII
        self.ln(4)
        self.set_font("Arial", size=12)
        for line in content.split("\n"):
            line = unidecode(line.strip())  # Convert each line to ASCII
            if line:
                self.multi_cell(0, 10, line)
        self.ln()

# Configuration
base_url = "https://www.freereadbooksonline.com/effective-communication"
chapters = range(1, 9)

pdf = PDF()

for chapter in chapters:
    url = f"{base_url}/{chapter}"
    try:
        res = requests.get(url, timeout=10)
        res.raise_for_status()
        soup = BeautifulSoup(res.text, "html.parser")
        
        # Get title
        title_div = soup.select_one(".panel-heading h2")
        title_text = title_div.get_text(strip=True) if title_div else f"Chapter {chapter}"

        # Get main text inside .panel-body
        body_div = soup.select_one(".panel-body")
        paragraphs = body_div.find_all("p") if body_div else []
        content = "\n\n".join(p.get_text(strip=True) for p in paragraphs)

        pdf.add_chapter(title_text, content)
        print(f"✔ Scraped {title_text}")
        
    except Exception as e:
        print(f"❌ Error at Chapter {chapter}: {e}")

# Save PDF
pdf.output("Effective_Communication.pdf")
print("✅ Saved as 'Effective_Communication.pdf'")
