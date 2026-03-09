"""
Message Pydantic schemas for API requests and responses.
"""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class MessageCreateRequest(BaseModel):
    """Request schema for creating a message."""

    message_text: str = Field(..., min_length=1, max_length=1024, description="Message content")
    user_id: str = Field(..., description="ID of the user sending the message")
    chatroom_id: str = Field(..., description="ID of the chatroom where message is sent")
    is_reply: bool = Field(False, description="Whether this is a reply to another message")
    parent_message_id: Optional[str] = Field(
        None, description="ID of parent message (required if is_reply=True)"
    )

    @field_validator("message_text")
    @classmethod
    def validate_message_text(cls, v: str) -> str:
        """Validate message text field."""
        if not v or not v.strip():
            raise ValueError("Message text cannot be empty or only whitespace")
        return v.strip()

    @model_validator(mode="after")
    def validate_reply_fields(self) -> "MessageCreateRequest":
        """Validate parent_message_id is consistent with is_reply."""
        if self.is_reply and not self.parent_message_id:
            raise ValueError("parent_message_id is required when is_reply is True")
        if not self.is_reply and self.parent_message_id:
            raise ValueError("parent_message_id should only be set when is_reply is True")
        return self


class MessageResponse(BaseModel):
    """Response schema for message data."""

    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., description="Unique message identifier")
    message_text: str = Field(..., description="Message content")
    user_id: str = Field(..., description="ID of the user who sent the message")
    chatroom_id: str = Field(..., description="ID of the chatroom where message was sent")
    is_reply: bool = Field(..., description="Whether this is a reply to another message")
    parent_message_id: Optional[str] = Field(None, description="ID of parent message")
    created_date: datetime = Field(..., description="When the message was created")
    last_updated_date: datetime = Field(..., description="When the message was last updated")


class MessageListResponse(BaseModel):
    """Response schema for listing messages."""

    messages: List[MessageResponse] = Field(..., description="List of messages")
    total: int = Field(..., description="Total number of messages")


class DeleteResponse(BaseModel):
    """Response schema for delete operations."""

    deleted: bool = Field(..., description="Whether the deletion was successful")
