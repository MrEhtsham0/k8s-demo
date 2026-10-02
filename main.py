from contextlib import asynccontextmanager

from fastapi import FastAPI

from src.db.seed import init_db
from src.routes import health_router, users_router


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await init_db()
    yield


app = FastAPI(lifespan=lifespan)

app.include_router(health_router)
app.include_router(users_router)
