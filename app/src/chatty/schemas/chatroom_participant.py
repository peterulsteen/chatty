"""
ChatroomParticipant Pydantic schemas for API requests and responses.
"""

import re
from datetime import datetime
from typing import List

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChatroomParticipantCreateRequest(BaseModel):
    """Request schema for creating a chatroom participant."""

    user_id: str = Field(..., description="User UUID")
    chatroom_id: str = Field(..., description="Chatroom UUID")

    @field_validator("user_id", "chatroom_id")
    @classmethod
    def validate_uuids(cls, v: str) -> str:
        """Validate UUID format."""
        if not v or not v.strip():
            raise ValueError("UUID cannot be empty")
        uuid_pattern = r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        if not re.match(uuid_pattern, v.lower()):
            raise ValueError("Invalid UUID format")
        return v.strip()


class ChatroomParticipantResponse(BaseModel):
    """Response schema for chatroom participant data."""

    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., description="Unique participant identifier")
    user_id: str = Field(..., description="User UUID")
    chatroom_id: str = Field(..., description="Chatroom UUID")
    created_date: datetime = Field(..., description="When the participant was added")
    last_updated_date: datetime = Field(..., description="When the participant was last updated")


class ChatroomParticipantListResponse(BaseModel):
    """Response schema for listing chatroom participants."""

    participants: List[ChatroomParticipantResponse] = Field(..., description="List of participants")
    total: int = Field(..., description="Total number of participants")


class DeleteResponse(BaseModel):
    """Response schema for delete operations."""

    deleted: bool = Field(..., description="Whether the deletion was successful")
