from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from pydantic import BaseModel
import os
import subprocess
import base64
import glob
import threading
import traceback
import httpx
import asyncio
import xml.etree.ElementTree as ET

app = FastAPI(title="GovGen Document Editor Backend")

# Allow the Flutter dev server (any port on localhost) to embed this as an iframe
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class FrameOptionsMiddleware(BaseHTTPMiddleware):
    """Allow this app to be embedded in an iframe from any origin."""
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Frame-Options"] = "ALLOWALL"
        response.headers["Content-Security-Policy"] = "frame-ancestors *"
        return response

app.add_middleware(FrameOptionsMiddleware)

# Mount static files directory
# Point to the React project's build output
editor_dist_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.dirname(__file__)), "editor-react", "dist"))
legacy_static_dir = os.path.join(os.path.dirname(__file__), "static")

if os.path.exists(editor_dist_dir):
    app.mount("/assets", StaticFiles(directory=os.path.join(editor_dist_dir, "assets")), name="assets")
    # Also serve other files in dist (like favicon, vite.svg)
    app.mount("/dist", StaticFiles(directory=editor_dist_dir), name="dist")
else:
    app.mount("/static", StaticFiles(directory=legacy_static_dir), name="static")

@app.get("/", response_class=HTMLResponse)
async def read_index():
    """Serves the main React editor HTML."""
    index_path = os.path.join(editor_dist_dir, "index.html")
    if not os.path.exists(index_path):
        index_path = os.path.join(legacy_static_dir, "index.html")
        
    if os.path.exists(index_path):
        with open(index_path, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>Editor Not Found</h1><p>Ensure editor-react/dist/index.html exists.</p>"

import base64
import glob
import threading

execution_lock = threading.Lock()

class CodeExecuteRequest(BaseModel):
    code: str
    files: dict[str, str] = {}

class ProxyRequest(BaseModel):
    url: str

@app.post("/proxy")
async def proxy_url(request: ProxyRequest):
    """Fetches a URL from the backend with browser-like headers and handles PDF extraction."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    }
    try:
        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(request.url, headers=headers, timeout=20.0)
            
            content_type = response.headers.get("Content-Type", "").lower()
            params = request.url.lower()
            
            if "application/pdf" in content_type or params.endswith(".pdf") or "pdf" in params:
                import fitz
                import io
                try:
                    doc = fitz.open(stream=io.BytesIO(response.content), filetype="pdf")
                    text = ""
                    for page in doc:
                        text += page.get_text()
                    return {
                        "content": text,
                        "status_code": response.status_code,
                        "type": "pdf",
                        "char_count": len(text)
                    }
                except Exception as pdf_err:
                    return {"content": f"PDF Error: {str(pdf_err)}", "status_code": response.status_code, "type": "error"}

            return {
                "content": response.text,
                "status_code": response.status_code,
                "type": "html",
                "char_count": len(response.text)
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/execute")
async def execute_code(request: CodeExecuteRequest):
    """Executes Python code in a subprocess with a global lock for stability."""
    if not execution_lock.acquire(blocking=False):
        return {"stdout": "", "stderr": "Backend Busy: Another execution is in progress.", "exit_code": -3}
    
    temp_dir = f"temp_run_{threading.get_ident()}"
    try:
        # Create temp execution directory
        if not os.path.exists(temp_dir):
            os.makedirs(temp_dir)
            
        # Write dummy/real data files provided by the frontend
        for filename, content in request.files.items():
            file_path = os.path.join(temp_dir, filename)
            # Ensure subdirectories exist if needed
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(content)

        # Save code to a temporary file in the same directory
        code_file = os.path.join(temp_dir, "script.py")
        with open(code_file, "w", encoding="utf-8") as f:
            f.write(request.code)
        
        # Run the code
        result = subprocess.run(
            ["python", "script.py"],
            cwd=temp_dir,
            capture_output=True,
            text=True,
            timeout=15
        )
        
        # Check for generated plots (png files)
        plots = {}
        for img_path in glob.glob(os.path.join(temp_dir, "*.png")):
            with open(img_path, "rb") as img_file:
                plots[os.path.basename(img_path)] = base64.b64encode(img_file.read()).decode('utf-8')

        # Clean up files but keep the directory (optional cleanup)
        for f in os.listdir(temp_dir):
            try:
                os.remove(os.path.join(temp_dir, f))
            except:
                pass
            
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "exit_code": result.returncode,
            "plots": plots
        }
    except subprocess.TimeoutExpired:
        return {"stdout": "", "stderr": "Timeout: Code execution exceeded 15 seconds.", "exit_code": -1}
    except Exception as e:
        return {"stdout": "", "stderr": f"Error: {str(e)}\n{traceback.format_exc()}", "exit_code": -2}
    finally:
        execution_lock.release()
        # Final cleanup of temp dir
        try:
            import shutil
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir)
        except:
            pass

class SemanticSearchRequest(BaseModel):
    query: str
    limit: int = 10
    minYear: int = None

async def _fetch_openalex(client, query, limit):
    try:
        url = "https://api.openalex.org/works"
        res = await client.get(url, params={"search": query, "per-page": limit, "sort": "relevance_score:desc"}, timeout=15.0)
        papers = []
        if res.status_code == 200:
            for work in res.json().get('results', []):
                authors = [{"name": a.get('author', {}).get('display_name', 'Unknown')} for a in work.get('authorships', [])]
                idx = work.get('abstract_inverted_index')
                abstr = ""
                if idx:
                    words = [(pos, word) for word, pos_list in idx.items() for pos in pos_list]
                    words.sort()
                    abstr = " ".join(w[1] for w in words)
                if not abstr: continue
                pdf_url = work.get('open_access', {}).get('oa_url')
                papers.append({
                    "paperId": "OA-" + str(work.get('id', '').split('/')[-1]),
                    "title": work.get('title') or 'Untitled',
                    "abstract": abstr,
                    "authors": authors,
                    "year": work.get('publication_year'),
                    "url": work.get('id'),
                    "openAccessPdf": {"url": pdf_url} if pdf_url else None
                })
        return papers
    except: return []

async def _fetch_epmc(client, query, limit):
    try:
        url = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
        res = await client.get(url, params={"query": query, "format": "json", "resultType": "core", "pageSize": limit}, timeout=15.0)
        papers = []
        if res.status_code == 200:
            for work in res.json().get('resultList', {}).get('result', []):
                abstr = work.get('abstractText')
                if not abstr: continue
                authors = [{"name": work.get('authorString', 'Unknown')}]
                papers.append({
                    "paperId": "EPMC-" + str(work.get('id', '')),
                    "title": work.get('title') or 'Untitled',
                    "abstract": abstr,
                    "authors": authors,
                    "year": int(work.get('pubYear', 0)) if work.get('pubYear') else None,
                    "url": f"https://europepmc.org/article/MED/{work.get('id')}",
                    "openAccessPdf": None
                })
        return papers
    except: return []

async def _fetch_arxiv(client, query, limit):
    try:
        url = "http://export.arxiv.org/api/query"
        res = await client.get(url, params={"search_query": f"all:{query}", "max_results": limit}, timeout=15.0)
        papers = []
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            ns = {'atom': 'http://www.w3.org/2005/Atom'}
            for entry in root.findall('atom:entry', ns):
                abstr = entry.find('atom:summary', ns)
                if abstr is None or not abstr.text: continue
                title = entry.find('atom:title', ns)
                link = entry.find('atom:id', ns)
                papers.append({
                    "paperId": "ARXIV-" + str(link.text.split('/')[-1] if link is not None else 'uuid'),
                    "title": title.text.replace('\n', ' ') if title is not None else 'Untitled',
                    "abstract": abstr.text.replace('\n', ' '),
                    "authors": [{"name": author.find('atom:name', ns).text} for author in entry.findall('atom:author', ns) if author.find('atom:name', ns) is not None],
                    "year": int(entry.find('atom:published', ns).text[:4]) if entry.find('atom:published', ns) is not None else None,
                    "url": link.text if link is not None else None,
                    "openAccessPdf": {"url": link.text.replace('/abs/', '/pdf/') + ".pdf"} if link is not None else None
                })
        return papers
    except: return []

@app.post("/semantic_scholar")
async def semantic_scholar_search(request: SemanticSearchRequest):
    """Universal Academic Aggregator masquerading as Semantic Scholar proxy."""
    try:
        clean_query = request.query.replace('\n', ' ').replace('\r', ' ').strip()
        fetch_limit = request.limit * 3 # Overfetch to account for missing abstracts
        
        async with httpx.AsyncClient(headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}) as client:
            results = await asyncio.gather(
                _fetch_openalex(client, clean_query, fetch_limit),
                _fetch_epmc(client, clean_query, fetch_limit),
                _fetch_arxiv(client, clean_query, fetch_limit),
                return_exceptions=True
            )
            
            all_papers = []
            seen_titles = set()
            for provider_papers in results:
                if isinstance(provider_papers, list):
                    # Only take up to the requested limit per provider to keep balance
                    count = 0
                    for p in provider_papers:
                        t = p['title'].lower()
                        year = p.get('year')
                        
                        if request.minYear is not None and year is not None:
                            if year < request.minYear:
                                continue
                                
                        if t not in seen_titles:
                            seen_titles.add(t)
                            all_papers.append(p)
                            count += 1
                        if count >= request.limit:
                            break
            
            # Sort by year descending
            all_papers.sort(key=lambda x: x['year'] or 0, reverse=True)
            
            return {"data": all_papers, "error": None}
    except Exception as e:
        return {"data": [], "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
