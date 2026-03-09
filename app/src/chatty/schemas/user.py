"""
User Pydantic schemas for API requests and responses.
"""

import re
from datetime import datetime
from typing import List

from pydantic import BaseModel, ConfigDict, Field, field_validator


class UserCreateRequest(BaseModel):
    """Request schema for creating a user."""

    name: str = Field(..., min_length=1, max_length=255, description="User's display name")
    handle: str = Field(..., min_length=1, max_length=50, description="User's unique handle")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Validate name field."""
        if not v or not v.strip():
            raise ValueError("Name cannot be empty")
        return v.strip()

    @field_validator("handle")
    @classmethod
    def validate_handle(cls, v: str) -> str:
        """Validate handle field."""
        if not v or not v.strip():
            raise ValueError("Handle cannot be empty")
        normalized = v.lower().strip()
        if not re.match(r"^[a-z0-9_]+$", normalized):
            raise ValueError("Handle can only contain lowercase letters, numbers, and underscores")
        return normalized


class UserUpdateRequest(BaseModel):
    """Request schema for updating a user."""

    name: str | None = Field(None, min_length=1, max_length=255, description="User's display name")
    handle: str | None = Field(
        None, min_length=1, max_length=50, description="User's unique handle"
    )

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str | None) -> str | None:
        """Validate name field."""
        if v is not None and (not v or not v.strip()):
            raise ValueError("Name cannot be empty")
        return v.strip() if v else v

    @field_validator("handle")
    @classmethod
    def validate_handle(cls, v: str | None) -> str | None:
        """Validate handle field."""
        if v is not None:
            if not v or not v.strip():
                raise ValueError("Handle cannot be empty")
            normalized = v.lower().strip()
            if not re.match(r"^[a-z0-9_]+$", normalized):
                raise ValueError(
                    "Handle can only contain lowercase letters, numbers, and underscores"
                )
            return normalized
        return v


class UserResponse(BaseModel):
    """Response schema for user data."""

    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., description="Unique user identifier")
    name: str = Field(..., description="User's display name")
    handle: str = Field(..., description="User's unique handle")
    created_date: datetime = Field(..., description="When the user was created")
    last_updated_date: datetime = Field(..., description="When the user was last updated")


class UserListResponse(BaseModel):
    """Response schema for listing users."""

    users: List[UserResponse] = Field(..., description="List of users")
    total: int = Field(..., description="Total number of users")


class UserChatroomResponse(BaseModel):
    """Response schema for user's chatroom participation."""

    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., description="Unique chatroom identifier")
    name: str = Field(..., description="Chatroom name")
    created_date: datetime = Field(..., description="When the chatroom was created")
    last_updated_date: datetime = Field(..., description="When the chatroom was last updated")
    joined_date: datetime = Field(..., description="When the user joined the chatroom")


class UserChatroomListResponse(BaseModel):
    """Response schema for listing user's chatrooms."""

    chatrooms: List[UserChatroomResponse] = Field(
        ..., description="List of chatrooms the user participates in"
    )
    total: int = Field(..., description="Total number of chatrooms")


class DeleteResponse(BaseModel):
    """Response schema for delete operations."""

    deleted: bool = Field(..., description="Whether the deletion was successful")
