"""
Chatroom Pydantic schemas for API requests and responses.
"""

import re
from datetime import datetime
from typing import List

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChatroomCreateRequest(BaseModel):
    """Request schema for creating a chatroom."""

    name: str = Field(..., min_length=1, max_length=100, description="Chatroom name")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Validate name field."""
        if not v or not v.strip():
            raise ValueError("Name cannot be empty")
        normalized = v.lower().strip()
        if not re.match(r"^[a-z0-9_]+$", normalized):
            raise ValueError("Name can only contain lowercase letters, numbers, and underscores")
        return normalized


class ChatroomUpdateRequest(BaseModel):
    """Request schema for updating a chatroom."""

    name: str | None = Field(None, min_length=1, max_length=100, description="Chatroom name")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str | None) -> str | None:
        """Validate name field."""
        if v is not None:
            if not v or not v.strip():
                raise ValueError("Name cannot be empty")
            normalized = v.lower().strip()
            if not re.match(r"^[a-z0-9_]+$", normalized):
                raise ValueError(
                    "Name can only contain lowercase letters, numbers, and underscores"
                )
            return normalized
        return v


class ChatroomResponse(BaseModel):
    """Response schema for chatroom data."""

    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., description="Unique chatroom identifier")
    name: str = Field(..., description="Chatroom name")
    created_date: datetime = Field(..., description="When the chatroom was created")
    last_updated_date: datetime = Field(..., description="When the chatroom was last updated")


class ChatroomListResponse(BaseModel):
    """Response schema for listing chatrooms."""

    chatrooms: List[ChatroomResponse] = Field(..., description="List of chatrooms")
    total: int = Field(..., description="Total number of chatrooms")


class ChatroomUserResponse(BaseModel):
    """Response schema for chatroom's user participants."""

    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., description="Unique user identifier")
    name: str = Field(..., description="User's display name")
    handle: str = Field(..., description="User's unique handle")
    created_date: datetime = Field(..., description="When the user was created")
    last_updated_date: datetime = Field(..., description="When the user was last updated")
    joined_date: datetime = Field(..., description="When the user joined the chatroom")


class ChatroomUserListResponse(BaseModel):
    """Response schema for listing chatroom's users."""

    users: List[ChatroomUserResponse] = Field(..., description="List of users in the chatroom")
    total: int = Field(..., description="Total number of users")


class DeleteResponse(BaseModel):
    """Response schema for delete operations."""

    deleted: bool = Field(..., description="Whether the deletion was successful")
