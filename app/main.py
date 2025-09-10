from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
import os
import json
from pathlib import Path

app = FastAPI(title="Hello World File Writer API", version="1.0.0")

# Configure the persistent volume path
PERSISTENT_VOLUME_PATH = "/data"

class WriteFileRequest(BaseModel):
    content: str
    filename: str = None

class WriteFileResponse(BaseModel):
    message: str
    filename: str
    timestamp: str
    file_path: str

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "Hello World FastAPI application is running!"}

@app.get("/health")
async def health_check():
    """Detailed health check including volume access"""
    try:
        # Check if persistent volume is accessible
        volume_accessible = os.path.exists(PERSISTENT_VOLUME_PATH)
        volume_writable = os.access(PERSISTENT_VOLUME_PATH, os.W_OK) if volume_accessible else False
        
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "volume_path": PERSISTENT_VOLUME_PATH,
            "volume_accessible": volume_accessible,
            "volume_writable": volume_writable
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Health check failed: {str(e)}")

@app.post("/write-file", response_model=WriteFileResponse)
async def write_file(request: WriteFileRequest):
    """
    Write content to a text file in the persistent volume
    """
    try:
        # Ensure the persistent volume directory exists
        os.makedirs(PERSISTENT_VOLUME_PATH, exist_ok=True)
        
        # Generate filename if not provided
        if not request.filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            request.filename = f"hello_world_{timestamp}.txt"
        
        # Ensure .txt extension
        if not request.filename.endswith('.txt'):
            request.filename += '.txt'
        
        # Create full file path
        file_path = os.path.join(PERSISTENT_VOLUME_PATH, request.filename)
        
        # Write content to file
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(request.content)
        
        # Verify file was written
        if not os.path.exists(file_path):
            raise HTTPException(status_code=500, detail="File was not created successfully")
        
        return WriteFileResponse(
            message="File written successfully",
            filename=request.filename,
            timestamp=datetime.now().isoformat(),
            file_path=file_path
        )
        
    except PermissionError:
        raise HTTPException(status_code=500, detail="Permission denied: Cannot write to persistent volume")
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"OS error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

@app.get("/list-files")
async def list_files():
    """List all files in the persistent volume"""
    try:
        if not os.path.exists(PERSISTENT_VOLUME_PATH):
            return {"files": [], "message": "Persistent volume directory does not exist"}
        
        files = []
        for filename in os.listdir(PERSISTENT_VOLUME_PATH):
            file_path = os.path.join(PERSISTENT_VOLUME_PATH, filename)
            if os.path.isfile(file_path):
                stat = os.stat(file_path)
                files.append({
                    "filename": filename,
                    "size": stat.st_size,
                    "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()
                })
        
        return {
            "files": files,
            "count": len(files),
            "volume_path": PERSISTENT_VOLUME_PATH
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing files: {str(e)}")

@app.get("/read-file/{filename}")
async def read_file(filename: str):
    """Read content from a file in the persistent volume"""
    try:
        file_path = os.path.join(PERSISTENT_VOLUME_PATH, filename)
        
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail="File not found")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        stat = os.stat(file_path)
        return {
            "filename": filename,
            "content": content,
            "size": stat.st_size,
            "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error reading file: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)