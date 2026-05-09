from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from datetime import datetime
from enum import Enum

class TaskStatus(str, Enum):
    pending    = "pending"
    in_progress = "in_progress"
    done       = "done"

class TaskInput(BaseModel):
    title:       str
    description: Optional[str] = None
    status:      TaskStatus    = TaskStatus.pending

class TaskResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:          int
    title:       str
    description: Optional[str] = None
    status:      TaskStatus
    createdAt:   datetime = Field(validation_alias="created_at")
    updatedAt:   datetime = Field(validation_alias="updated_at")

class Error(BaseModel):
    message: str