from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
import psycopg2

app = FastAPI()

def get_page_html(book_id: int, page_number: int):
    conn = psycopg2.connect(
    host="localhost",
    port=8080,
    dbname="postgres",
    user="postgres",
    password="root"
    )
    cur = conn.cursor()
    cur.execute("""
        SELECT "bookHtml"
        FROM public.bookinfo
        WHERE "bookID" = %s AND "bookPage" = %s
    """, (book_id, page_number))
    result = cur.fetchone()

    cur.execute("""
        SELECT MAX("bookPage")
        FROM public.bookinfo
        WHERE "bookID" = %s
    """, (book_id,))
    max_page = cur.fetchone()[0]

    cur.close()
    conn.close()

    return result[0] if result else None, max_page or 1

@app.get("/book/{book_id}/page/{page_number}", response_class=HTMLResponse)
def view_page(book_id: int, page_number: int):
    html_content, max_page = get_page_html(book_id, page_number)

    if not html_content:
        raise HTTPException(status_code=404, detail="Page not found.")

    prev_page = page_number - 1 if page_number > 1 else None
    next_page = page_number + 1 if page_number < max_page else None

    nav_html = '<div style="margin-top: 2em;">'
    if prev_page:
        nav_html += f'<a href="/book/{book_id}/page/{prev_page}">⬅ Previous</a> '
    if next_page:
        nav_html += f' <a href="/book/{book_id}/page/{next_page}">Next ➡</a>'
    nav_html += '</div>'

    full_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Book {book_id} - Page {page_number}</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                padding: 2rem;
                background: #fefefe;
                line-height: 1.6;
            }}
            img {{
                max-width: 100%;
                height: auto;
                margin: 1rem 0;
            }}
            p {{
                margin-bottom: 1em;
            }}
            .nav {{
                margin-top: 2rem;
                font-size: 1rem;
            }}
        </style>
    </head>
    <body>
        <h1>📘 Book {book_id} — Page {page_number}</h1>
        {html_content}
        {nav_html}
    </body>
    </html>
    """

    return full_html
