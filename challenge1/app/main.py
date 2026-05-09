from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import HTTPException

from database import engine
import models
from router import tasks

app = FastAPI(title="タスク管理 API")


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    if isinstance(exc.detail, dict):
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    return JSONResponse(status_code=exc.status_code, content={"message": str(exc.detail)})


app.include_router(tasks.router, prefix="/api/tasks", tags=["Tasks"])


@app.get("/health")
def health_check():
    return {"status": "ok"}
