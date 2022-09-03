from fastapi import FastAPI

from app.utils import get_message

app = FastAPI()


@app.get("/")
async def root():
    return {"message": get_message()}
