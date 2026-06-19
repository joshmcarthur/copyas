#!/usr/bin/env python3
"""Generate golden fixtures for RecursiveTextSplit LangChain conformance tests.

Requires: pip install langchain-text-splitters

Reference: langchain_text_splitters.character.RecursiveCharacterTextSplitter
Regenerate when the Swift port or LangChain version changes.
"""

from __future__ import annotations

import json
from pathlib import Path

from langchain_text_splitters import RecursiveCharacterTextSplitter

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Tests/RecursiveTextSplitTests/Fixtures/langchain_golden.json"

FIXTURES = [
    {
        "name": "short_single_paragraph",
        "chunk_size": 250,
        "chunk_overlap": 0,
        "separators": ["\n\n", "\n", " ", ""],
        "input": "This is a short paragraph that fits in one chunk.",
    },
    {
        "name": "multiparagraph_no_overlap",
        "chunk_size": 80,
        "chunk_overlap": 0,
        "separators": ["\n\n", "\n", " ", ""],
        "input": (
            "First paragraph with enough text to force a split when chunk size is small.\n\n"
            "Second paragraph continues the document with more content for testing.\n\n"
            "Third paragraph wraps up the sample input for golden fixture generation."
        ),
    },
    {
        "name": "multiparagraph_overlap",
        "chunk_size": 100,
        "chunk_overlap": 20,
        "separators": ["\n\n", "\n", " ", ""],
        "input": (
            "Alpha paragraph one has several words to exceed the chunk limit.\n\n"
            "Beta paragraph two adds more text across the boundary.\n\n"
            "Gamma paragraph three completes the overlap fixture."
        ),
    },
    {
        "name": "long_unbreakable_word",
        "chunk_size": 10,
        "chunk_overlap": 0,
        "separators": ["\n\n", "\n", " ", ""],
        "input": "prefix supercalifragilisticexpialidocious suffix",
    },
]


def split_fixture(case: dict) -> dict:
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=case["chunk_size"],
        chunk_overlap=case["chunk_overlap"],
        separators=case["separators"],
        length_function=len,
        keep_separator=True,
    )
    chunks = splitter.split_text(case["input"])
    return {
        "name": case["name"],
        "chunk_size": case["chunk_size"],
        "chunk_overlap": case["chunk_overlap"],
        "separators": case["separators"],
        "input": case["input"],
        "chunks": chunks,
    }


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "generator": "Scripts/generate-splitter-fixtures.py",
        "langchain_package": "langchain-text-splitters",
        "fixtures": [split_fixture(case) for case in FIXTURES],
    }
    OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
