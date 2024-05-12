import os
import psycopg2
import psycopg2.extras
from fastapi import FastAPI, Depends, Form, Request, HTTPException, status
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from database import get_db_connection

app = FastAPI()
templates = Jinja2Templates(directory="templates")
app.mount("/static", StaticFiles(directory="static"), name="static")

# Function to create the greetings table (if it doesn't exist)
def create_greetings_table():
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS greetings (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    message TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    avatar_url TEXT
                );
            """)
        conn.commit()

# Call the function to create the table at app startup
@app.on_event("startup")
def on_startup():
    create_greetings_table()

# HTML template rendering
@app.get("/", response_class=HTMLResponse)
def read_greetings(request: Request):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, message, created_at, avatar_url FROM greetings ORDER BY created_at DESC")
            greetings = cur.fetchall()
            return templates.TemplateResponse("index.html", {"request": request, "greetings": greetings})

# Handle new greetings (HTMX POST)
@app.post("/greetings", response_class=HTMLResponse)
async def create_greeting(request: Request, github_id: str = Form(...), message: str = Form(...)):
    if not github_id or not message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="GitHub ID and message are required")

    avatar_url = f"https://github.com/{github_id}.png?size=150"  # Construct GitHub avatar URL

    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "INSERT INTO greetings (name, message, avatar_url) VALUES (%s, %s, %s) RETURNING id, name, message, created_at, avatar_url",
                (github_id, message, avatar_url),
            )
            new_greeting = cur.fetchone()

    # Fetch updated greetings
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, message, created_at, avatar_url FROM greetings ORDER BY created_at DESC")
            greetings = cur.fetchall()
    return templates.TemplateResponse("greetings_list.html", {"request": request, "greetings": greetings})

# Edit greeting (HTMX GET)
@app.get("/greetings/{greeting_id}/edit", response_class=HTMLResponse)
async def edit_greeting(request: Request, greeting_id: int):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT name, message, avatar_url FROM greetings WHERE id = %s", (greeting_id,))
            greeting = cur.fetchone()

    if not greeting:
      raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Greeting not found")
    print(vars(greeting))
    return templates.TemplateResponse("edit_greeting.html", {"request": request, "greeting": greeting, "greeting_id": greeting_id})

# Update greeting (HTMX PUT)
@app.put("/greetings/{greeting_id}", response_class=HTMLResponse)
async def update_greeting(request: Request, greeting_id: int, github_id: str = Form(...), message: str = Form(...), avatar_url: str = Form(None)):
    if not github_id or not message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="GitHub ID and message are required")

    avatar_url = f"https://github.com/{github_id}.png?size=150"

    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "UPDATE greetings SET name = %s, message = %s, avatar_url = %s WHERE id = %s RETURNING id, name, message, created_at, avatar_url",
                (github_id, message, avatar_url, greeting_id),
            )
            updated_greeting = cur.fetchone()

    if not updated_greeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Greeting not found")

    return templates.TemplateResponse("greetings_list.html", {"request": request, "greetings": [updated_greeting]})

# Delete greeting (HTMX DELETE)
@app.delete("/greetings/{greeting_id}", response_class=HTMLResponse)
async def delete_greeting(request: Request, greeting_id: int):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("DELETE FROM greetings WHERE id = %s", (greeting_id,))

    # Fetch updated greetings
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, message, created_at, avatar_url FROM greetings ORDER BY created_at DESC")
            greetings = cur.fetchall()
    return templates.TemplateResponse("greetings_list.html", {"request": request, "greetings": greetings})

@app.get("/avatar-preview", response_class=HTMLResponse)
async def avatar_preview(request: Request, github_id: str):
    avatar_url = f"https://github.com/{github_id}.png?size=150"
    return templates.TemplateResponse("avatar_preview.html", {"request": request, "avatar_url": avatar_url})

