from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator
from typing import Annotated


ShortText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
SongText = Annotated[str, StringConstraints(max_length=1000)]
ChordName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=24)]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class ChordPlacement(StrictModel):
    chord: ChordName
    position: int = Field(ge=0, le=1000)


class SongLine(StrictModel):
    text: SongText
    chords: list[ChordPlacement] = Field(max_length=40)


class SongSection(StrictModel):
    name: ShortText
    lines: list[SongLine] = Field(min_length=1, max_length=200)


class DigitizeResponse(StrictModel):
    title: ShortText | None
    key: ChordName | None
    sections: list[SongSection] = Field(min_length=1, max_length=40)

    @model_validator(mode="after")
    def require_song_content(self) -> "DigitizeResponse":
        if not any(
            line.text.strip() or line.chords
            for section in self.sections
            for line in section.lines
        ):
            raise ValueError("At least one lyric or chord is required.")
        return self


class ErrorResponse(StrictModel):
    detail: str

