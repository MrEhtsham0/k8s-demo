from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class HealthResponse(BaseModel):
    status: str = Field(..., description="The status of the health check")
    version: str = Field(..., description="The version of the application")
    environment: str = Field(..., description="The environment of the application")
    timestamp: datetime = Field(..., description="The timestamp of the health check")


class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=255)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: EmailStr
    created_at: datetime
    updated_at: datetime
