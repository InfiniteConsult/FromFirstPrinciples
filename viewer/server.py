import re
import uvicorn
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# --- Configuration ---
# All paths are relative to the user's home directory inside the container.
HOME_DIR = Path.home()
ARTICLES_DIR = HOME_DIR / "articles"
VIEWER_DIR = HOME_DIR / "viewer"
DATA_DIR = HOME_DIR / "data"

TEMPLATES_DIR = VIEWER_DIR / "templates"
STATIC_DIR = VIEWER_DIR / "static"
CERT_FILE = DATA_DIR / "cert.pem"
KEY_FILE = DATA_DIR / "key.pem"


def format_title(slug: str) -> str:
    """Converts a directory slug into a human-readable title."""
    # Remove leading digits and underscores, replace underscores with spaces, and title case.
    # e.g., "0001_basic_fastapi" -> "Basic Fastapi"
    cleaned_slug = re.sub(r"^\d+_", "", slug)
    return cleaned_slug.replace("_", " ").title()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    On startup, scan the articles directory and build a catalog of available articles.
    This catalog is stored in the application's state for quick access.
    """
    print("Server is starting up, building article catalog...")
    articles = []
    if ARTICLES_DIR.is_dir():
        for item in sorted(ARTICLES_DIR.iterdir()):
            if item.is_dir() and (item / "README.md").is_file():
                slug = item.name
                articles.append({
                    "slug": slug,
                    "title": format_title(slug),
                    "path": item / "README.md"
                })
    app.state.articles_catalog = {article["slug"]: article for article in articles}
    print(f"Found {len(articles)} articles.")
    yield
    print("Server is shutting down.")


# --- FastAPI Application ---
app = FastAPI(lifespan=lifespan)

# Mount the static directory to serve CSS and JavaScript files.
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# Configure Jinja2 for HTML templating.
templates = Jinja2Templates(directory=TEMPLATES_DIR)


# --- API Endpoints ---
@app.get("/api/articles")
async def get_articles_index():
    """Returns a list of all discovered articles (slug and title)."""
    if not hasattr(app.state, "articles_catalog") or not app.state.articles_catalog:
        return []
    # Return a list of dicts, excluding the server-side file path.
    return [
        {"slug": data["slug"], "title": data["title"]}
        for data in app.state.articles_catalog.values()
    ]


@app.get("/articles/{article_slug}/static/{file_path:path}")
async def serve_article_static(article_slug: str, file_path: str):
    """Serves a static file from within a specific article's directory."""
    if article_slug not in app.state.articles_catalog:
        raise HTTPException(status_code=404, detail="Article not found")

    # Construct the full path to the static file
    article_dir = app.state.articles_catalog[article_slug]["path"].parent
    static_file_path = article_dir / "static" / file_path

    if not static_file_path.is_file():
        raise HTTPException(status_code=404, detail="Static file not found")

    return FileResponse(static_file_path)


@app.get("/api/articles/{article_slug}")
async def get_article_content(article_slug: str):
    """Returns the raw Markdown content of a specific article."""
    if article_slug not in app.state.articles_catalog:
        raise HTTPException(status_code=404, detail="Article not found")

    file_path = app.state.articles_catalog[article_slug]["path"]
    return FileResponse(file_path, media_type="text/markdown; charset=utf-8")


# --- Frontend Serving ---
@app.get("/")
async def serve_frontend(request: Request):
    """Serves the main index.html single-page application."""
    return templates.TemplateResponse({"request": request}, "index.html")


# --- Main Entry Point ---
if __name__ == "__main__":
    """
    Allows the server to be run with `python3 server.py`.
    Configures Uvicorn to use the shared TLS certificates.
    """
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8889,  # Matches the port exposed in the Dockerfile
        reload=True,
        ssl_keyfile=str(KEY_FILE),
        ssl_certfile=str(CERT_FILE),
    )