import os
from datetime import UTC, datetime

from fastapi import APIRouter

from src.schemas.routes_schema import HealthResponse

router = APIRouter()


@router.get("/health")
async def health() -> HealthResponse:
    # Values come from ConfigMap in K8s (or defaults when running locally)
    return HealthResponse(
        status="ok",
        version=os.getenv("APP_VERSION", "1.0.0"),
        environment=os.getenv("APP_ENV", "development"),
        timestamp=datetime.now(UTC),
    )
