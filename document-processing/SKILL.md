---
name: document-processing
description: "Use when reading, creating, editing, merging, splitting, or extracting content from PDF files or Excel/spreadsheet files. Use when processing tabular data, building financial models in Excel, extracting text from scanned documents, or converting between document formats. Triggers: \"PDF\", \"Excel\", \"spreadsheet\", \"xlsx\", \"pypdf\", \"pdfplumber\", \"reportlab\", \"openpyxl\", \"pandas\", \"document processing\", \"extract text from PDF\", \"merge PDF\", \"split PDF\", \"financial model\", \"OCR\", \"spreadsheet automation\"."
---

# Document Processing

## When to Use

- User wants to read, create, edit, merge, split, rotate, watermark, or extract content from PDF files
- User wants to open, read, edit, create, or format Excel/spreadsheet files (.xlsx, .xlsm, .csv, .tsv)
- User needs to build a financial model, clean tabular data, or automate spreadsheet generation
- User needs OCR on scanned documents or table extraction from PDFs
- User asks to convert between document formats where the output is a PDF or spreadsheet file

## When NOT to Use

- Database ingestion pipelines or ETL workflows → use `data-engineering`
- Log file parsing, monitoring dashboards, or structured log analysis → use `observability`
- Primary deliverable is a Word document, HTML report, or standalone Python script
- Google Sheets API integration (no local file involved)

---

## PDF Processing

### Library Selection

| Library | Best For | Install |
|---|---|---|
| `pypdf` | Merge, split, rotate, metadata, watermark, encrypt | `pip install pypdf` |
| `pdfplumber` | Text extraction with layout, table extraction | `pip install pdfplumber` |
| `reportlab` | Create PDFs from scratch (canvas or document flow) | `pip install reportlab` |
| `pytesseract` | OCR on scanned/image-only PDFs | `pip install pytesseract pdf2image` |

### Merge PDFs with pypdf

```python
from pypdf import PdfWriter, PdfReader

writer = PdfWriter()
for pdf_file in ["doc1.pdf", "doc2.pdf", "doc3.pdf"]:
    reader = PdfReader(pdf_file)
    for page in reader.pages:
        writer.add_page(page)

with open("merged.pdf", "wb") as f:
    writer.write(f)
```

### Extract Table with pdfplumber

```python
import pdfplumber
import pandas as pd

with pdfplumber.open("document.pdf") as pdf:
    all_tables = []
    for page in pdf.pages:
        for table in page.extract_tables():
            if table:
                df = pd.DataFrame(table[1:], columns=table[0])
                all_tables.append(df)

combined = pd.concat(all_tables, ignore_index=True)
combined.to_excel("extracted_tables.xlsx", index=False)
```

### Create PDF with reportlab

```python
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet

doc = SimpleDocTemplate("report.pdf", pagesize=letter)
styles = getSampleStyleSheet()
story = [
    Paragraph("Report Title", styles['Title']),
    Spacer(1, 12),
    Paragraph("Body content goes here.", styles['Normal']),
]
doc.build(story)
```

> **ReportLab subscripts/superscripts**: Never use Unicode characters (₀₁₂, ⁰¹²) — built-in fonts render them as black boxes. Use XML tags instead: `H<sub>2</sub>O`, `x<super>2</super>`.

### OCR Pattern with pytesseract

```python
import pytesseract
from pdf2image import convert_from_path

images = convert_from_path("scanned.pdf")
text = ""
for i, image in enumerate(images):
    text += f"--- Page {i+1} ---\n"
    text += pytesseract.image_to_string(image) + "\n\n"
print(text)
```

### CLI Alternatives

| Tool | One-liner |
|---|---|
| `pdftotext` | `pdftotext -layout input.pdf output.txt` |
| `qpdf` | `qpdf --empty --pages file1.pdf file2.pdf -- merged.pdf` |
| `pdftk` | `pdftk file1.pdf file2.pdf cat output merged.pdf` |

---

## Spreadsheet Processing

### pandas vs openpyxl

| Need | Use |
|---|---|
| Bulk data analysis, statistics, CSV/Excel read for analysis | `pandas` |
| Formatting, formulas, color coding, cell-level control | `openpyxl` |

```python
import pandas as pd

df = pd.read_excel("file.xlsx", sheet_name=None)  # All sheets as dict
df["Sheet1"].describe()
df["Sheet1"].to_excel("output.xlsx", index=False)
```

```python
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font, PatternFill, Alignment

wb = load_workbook("existing.xlsx")
ws = wb.active

ws["A1"] = "Label"
ws["B1"] = "=SUM(B2:B10)"                    # Always formulas, never hardcoded values
ws["A1"].font = Font(bold=True, color="000000")
ws.column_dimensions["A"].width = 20

wb.save("output.xlsx")
```

> **Warning**: Loading with `data_only=True` then saving permanently replaces formulas with static values.

### Formula-First Philosophy

Never hardcode computed values in Python — let Excel calculate them. The spreadsheet must recalculate when source data changes.

```python
# WRONG
sheet["B10"] = df["Sales"].sum()        # Hardcodes 5000

# CORRECT
sheet["B10"] = "=SUM(B2:B9)"           # Excel owns the calculation
sheet["C5"] = "=(C4-C2)/C2"            # Growth rate as formula
sheet["D20"] = "=AVERAGE(D2:D19)"      # Average as formula
```

### Financial Model Color Coding

| Color | RGB | Meaning |
|---|---|---|
| Blue text | `0,0,255` | Hardcoded inputs / scenario drivers |
| Black text | `0,0,0` | All formulas and calculations |
| Green text | `0,128,0` | Links to other worksheets in same workbook |
| Red text | `255,0,0` | External links to other files |
| Yellow background | `255,255,0` | Key assumptions needing attention |

### Number Formatting Standards

| Type | Format | Example |
|---|---|---|
| Currency | `$#,##0` with units in header | `Revenue ($mm)` |
| Zeros | `$#,##0;($#,##0);-` | Displays as `−` |
| Percentages | `0.0%` | `12.5%` |
| Multiples | `0.0x` | `8.5x` |
| Negatives | Parentheses | `(123)` not `-123` |
| Years | Text string | `"2024"` not `2,024` |

### Formula Verification

Before building the full model, test 2–3 sample cell references manually. Then verify:

- NaN handling: `pd.notna(value)` before writing references
- Division by zero: wrap denominators (`=IF(B5=0, 0, A5/B5)`)
- Row indexing: DataFrame row 5 = Excel row 6 (1-indexed)
- Cross-sheet references: `=Sheet1!A1` format
- After saving, run `python scripts/recalc.py output.xlsx` to recalculate and detect `#REF!`, `#DIV/0!`, `#VALUE!`, `#NAME?`

---

## Quick Reference

| Task | Best Tool | Command / Code |
|---|---|---|
| Merge PDFs | pypdf | `writer.add_page(page)` for each file |
| Extract tables from PDF | pdfplumber | `page.extract_tables()` |
| Create PDF from scratch | reportlab | `SimpleDocTemplate` + `Platypus` story |
| OCR scanned PDF | pytesseract | `convert_from_path` then `image_to_string` |
| CLI merge | qpdf | `qpdf --empty --pages f1.pdf f2.pdf -- out.pdf` |
| Read/analyze spreadsheet | pandas | `pd.read_excel("file.xlsx", sheet_name=None)` |
| Format/formula spreadsheet | openpyxl | `load_workbook` + assign `"=FORMULA"` strings |
| Recalculate & error-check | LibreOffice | `python scripts/recalc.py output.xlsx` |

---

## Verification Checklist

### PDF
- [ ] Correct library chosen for the task (merge → pypdf, extract → pdfplumber, create → reportlab)
- [ ] Output file opens without errors and page count is correct
- [ ] No Unicode subscript/superscript characters used in reportlab Paragraphs
- [ ] OCR output spot-checked against source image for accuracy

### Spreadsheet
- [ ] Zero formula errors: `#REF!`, `#DIV/0!`, `#VALUE!`, `#NAME?` all absent
- [ ] All calculations use Excel formulas, not Python-hardcoded values
- [ ] Financial model color coding applied (blue inputs, black formulas, green cross-sheet)
- [ ] Number formats match standards (currency units in headers, zeros as `−`, negatives in parentheses)
- [ ] `scripts/recalc.py` run after saving and output shows `"status": "success"`
- [ ] Cell references verified for row offset (DataFrame → Excel is 1-indexed)
- [ ] Hardcoded source values documented with Source comment (system, date, reference)
