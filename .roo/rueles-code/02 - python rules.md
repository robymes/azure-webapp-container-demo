# Python 3.11+ Coding Standards

## Language Version and Compatibility

- Use Python 3.11 or later for new projects
- Leverage Python 3.11+ features when appropriate (e.g., exception groups, tomllib, improved error messages)
- Maintain compatibility within the specified Python version range
- Use `from __future__ import annotations` for forward compatibility when using type hints

## Code Style and Formatting

### General Formatting
- Follow PEP 8 style guide strictly
- Use 4 spaces for indentation (no tabs)
- Limit lines to 88 characters (Black formatter standard)
- Use trailing commas in multi-line data structures
- Separate top-level function and class definitions with two blank lines
- Separate method definitions inside a class with one blank line

### Import Organization
- Group imports in the following order:
  1. Standard library imports
  2. Related third-party imports
  3. Local application/library imports
- Separate each group with a blank line
- Use absolute imports whenever possible
- Avoid wildcard imports (`from module import *`)
- Sort imports alphabetically within each group

```python
# Standard library
import os
import sys
from pathlib import Path

# Third-party
import requests
from pydantic import BaseModel

# Local
from .config import settings
from .utils import helper_function
```

## Type Hints and Annotations

- Use type hints for all function parameters and return values
- Use generic types from `typing` module when needed
- Prefer built-in collection types for Python 3.11+ (e.g., `list[str]` instead of `List[str]`)
- Use `Optional[T]` or `T | None` for optional parameters
- Document complex type unions clearly

```python
from typing import Optional, Union
from pathlib import Path

def process_file(file_path: Path, encoding: str = "utf-8") -> dict[str, str] | None:
    """Process a file and return parsed data."""
    pass

# Python 3.10+ union syntax
def get_user_data(user_id: int) -> dict[str, str] | None:
    """Retrieve user data by ID."""
    pass
```

## Error Handling and Exceptions

### Exception Handling Best Practices
- Use specific exception types rather than broad `except` clauses
- Prefer `except Exception` over bare `except`
- Use exception chaining with `raise ... from` when re-raising
- Create custom exception classes when needed
- Use exception groups (Python 3.11+) for handling multiple related exceptions

```python
# Good: Specific exception handling
try:
    result = risky_operation()
except (ValueError, TypeError) as e:
    logger.error(f"Input validation failed: {e}")
    raise ProcessingError("Invalid input data") from e

# Python 3.11+: Exception Groups
try:
    validate_all_inputs(data)
except* ValidationError as eg:
    for error in eg.exceptions:
        logger.error(f"Validation failed: {error}")
```

### Custom Exceptions
- Create custom exception hierarchies for domain-specific errors
- Include meaningful error messages and context
- Use dataclasses for structured exception data

```python
class DataProcessingError(Exception):
    """Base exception for data processing operations."""
    pass

class ValidationError(DataProcessingError):
    """Raised when data validation fails."""
    
    def __init__(self, field: str, value: str, message: str):
        self.field = field
        self.value = value
        super().__init__(f"Validation failed for {field}={value}: {message}")
```

## Data Structures and Classes

### Class Design
- Use dataclasses for simple data containers
- Implement `__str__` and `__repr__` methods appropriately
- Use properties for computed attributes
- Follow single responsibility principle
- Use composition over inheritance when appropriate

```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class User:
    """Represents a user in the system."""
    id: int
    name: str
    email: str
    is_active: bool = True
    
    def __post_init__(self):
        """Validate user data after initialization."""
        if not self.email or "@" not in self.email:
            raise ValueError("Invalid email address")
    
    @property
    def display_name(self) -> str:
        """Return formatted display name."""
        return f"{self.name} <{self.email}>"
```

### Collections and Data Handling
- Use comprehensions for simple transformations
- Prefer `pathlib.Path` over string paths
- Use `enum.Enum` for constants and choices
- Leverage `collections.defaultdict` and `collections.Counter` when appropriate

```python
from pathlib import Path
from enum import Enum
from collections import defaultdict

class Status(Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

# Good: List comprehension
active_users = [user for user in users if user.is_active]

# Good: Path handling
config_path = Path("config") / "settings.toml"
```

## Functions and Methods

### Function Design
- Keep functions small and focused (single responsibility)
- Use descriptive function names
- Limit function parameters (max 5-7 parameters)
- Use keyword-only arguments for clarity when appropriate
- Return consistent types

```python
def calculate_total_price(
    items: list[dict[str, float]], 
    *,
    tax_rate: float = 0.0,
    discount_rate: float = 0.0,
    currency: str = "USD"
) -> dict[str, float]:
    """Calculate total price with tax and discount applied."""
    pass
```

### Async Programming
- Use `async`/`await` for I/O-bound operations
- Prefer `asyncio.gather()` for concurrent operations
- Use context managers (`async with`) for resource management
- Handle asyncio exceptions properly

```python
import asyncio
import aiohttp
from typing import AsyncIterator

async def fetch_data(session: aiohttp.ClientSession, url: str) -> dict:
    """Fetch data from URL asynchronously."""
    async with session.get(url) as response:
        response.raise_for_status()
        return await response.json()

async def process_urls(urls: list[str]) -> list[dict]:
    """Process multiple URLs concurrently."""
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_data(session, url) for url in urls]
        return await asyncio.gather(*tasks, return_exceptions=True)
```

## Configuration and Environment

### Configuration Management
- Use environment variables for configuration
- Provide sensible defaults
- Validate configuration at startup
- Use `pydantic.BaseSettings` for structured configuration
- Support multiple configuration sources (env vars, files, CLI args)

```python
from pydantic import BaseSettings, Field
from pathlib import Path

class Settings(BaseSettings):
    """Application settings."""
    
    debug: bool = False
    database_url: str = Field(..., env="DATABASE_URL")
    api_key: str = Field(..., env="API_KEY")
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    data_dir: Path = Field(default=Path("data"), env="DATA_DIR")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
```

## Logging and Debugging

### Logging Best Practices
- Use structured logging with JSON format for production
- Include correlation IDs for request tracing
- Log at appropriate levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Avoid logging sensitive information
- Use lazy string formatting

```python
import logging
import json
from typing import Any

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

def process_user_request(user_id: int, request_data: dict[str, Any]) -> None:
    """Process user request with proper logging."""
    logger.info(
        "Processing user request",
        extra={
            "user_id": user_id,
            "request_type": request_data.get("type"),
            "correlation_id": request_data.get("correlation_id")
        }
    )
    
    try:
        # Process request
        result = perform_operation(request_data)
        logger.info("Request processed successfully", extra={"user_id": user_id})
    except Exception as e:
        logger.error(
            "Request processing failed",
            extra={"user_id": user_id, "error": str(e)},
            exc_info=True
        )
        raise
```

## Testing and Quality Assurance

### Testing Standards
- Write unit tests for all public functions and methods
- Use pytest as the testing framework
- Aim for >90% code coverage
- Use fixtures for test data setup
- Mock external dependencies
- Write integration tests for critical paths

```python
import pytest
from unittest.mock import Mock, patch
from myapp.services import UserService
from myapp.models import User

@pytest.fixture
def sample_user():
    """Provide sample user for tests."""
    return User(id=1, name="John Doe", email="john@example.com")

@pytest.fixture
def user_service():
    """Provide UserService instance with mocked dependencies."""
    return UserService(database=Mock(), cache=Mock())

class TestUserService:
    """Test cases for UserService."""
    
    def test_get_user_by_id_success(self, user_service, sample_user):
        """Test successful user retrieval."""
        user_service.database.get_user.return_value = sample_user
        
        result = user_service.get_user_by_id(1)
        
        assert result == sample_user
        user_service.database.get_user.assert_called_once_with(1)
    
    def test_get_user_by_id_not_found(self, user_service):
        """Test user not found scenario."""
        user_service.database.get_user.return_value = None
        
        with pytest.raises(UserNotFoundError):
            user_service.get_user_by_id(999)
```

## Security Best Practices

### Input Validation and Sanitization
- Validate all input data
- Use parameterized queries for database operations
- Sanitize user input before processing
- Implement rate limiting for API endpoints
- Use secure random generation for tokens and IDs

```python
import secrets
import re
from pydantic import BaseModel, validator

class UserInput(BaseModel):
    """Validated user input model."""
    
    email: str
    name: str
    age: int
    
    @validator('email')
    def validate_email(cls, v):
        """Validate email format."""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(pattern, v):
            raise ValueError('Invalid email format')
        return v.lower()
    
    @validator('name')
    def validate_name(cls, v):
        """Validate and sanitize name."""
        if not v.strip():
            raise ValueError('Name cannot be empty')
        return v.strip()
    
    @validator('age')
    def validate_age(cls, v):
        """Validate age range."""
        if not 13 <= v <= 120:
            raise ValueError('Age must be between 13 and 120')
        return v

def generate_secure_token() -> str:
    """Generate cryptographically secure token."""
    return secrets.token_urlsafe(32)
```

## Performance Optimization

### General Performance Guidelines
- Use generators for large datasets
- Implement caching for expensive operations
- Use connection pooling for database operations
- Profile code before optimizing
- Use `functools.lru_cache` for function memoization

```python
import functools
from typing import Iterator
import time

@functools.lru_cache(maxsize=128)
def expensive_calculation(n: int) -> int:
    """Cached expensive calculation."""
    time.sleep(0.1)  # Simulate expensive operation
    return n * n

def process_large_dataset(data: list[dict]) -> Iterator[dict]:
    """Process large dataset using generator."""
    for item in data:
        if item.get('active', False):
            processed = transform_item(item)
            if processed:
                yield processed
```

## Documentation Standards

### Code Documentation
- Write clear docstrings for all public functions, classes, and methods
- Use Google-style or NumPy-style docstrings consistently
- Include type information in docstrings
- Document parameters, return values, and exceptions
- Provide usage examples for complex functions

```python
def calculate_statistics(
    data: list[float], 
    include_median: bool = True
) -> dict[str, float]:
    """Calculate basic statistics for a list of numbers.
    
    Args:
        data: List of numeric values to analyze
        include_median: Whether to include median in results
        
    Returns:
        Dictionary containing statistical measures:
            - mean: Arithmetic mean
            - std: Standard deviation  
            - min: Minimum value
            - max: Maximum value
            - median: Median value (if include_median=True)
            
    Raises:
        ValueError: If data list is empty
        TypeError: If data contains non-numeric values
        
    Example:
        >>> data = [1, 2, 3, 4, 5]
        >>> stats = calculate_statistics(data)
        >>> print(stats['mean'])
        3.0
    """
    if not data:
        raise ValueError("Data list cannot be empty")
    
    # Implementation here
    pass
```

## Project Structure and Organization

### Package Structure
- Use meaningful package and module names
- Keep related functionality together
- Separate business logic from infrastructure code
- Use `__init__.py` files to control public API
- Follow domain-driven design principles when appropriate

```
project/
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── main.py
│       ├── config.py
│       ├── models/
│       │   ├── __init__.py
│       │   ├── user.py
│       │   └── product.py
│       ├── services/
│       │   ├── __init__.py
│       │   ├── user_service.py
│       │   └── auth_service.py
│       ├── repositories/
│       │   ├── __init__.py
│       │   └── database.py
│       └── utils/
│           ├── __init__.py
│           ├── helpers.py
│           └── validators.py
├── tests/
├── docs/
├── requirements.txt
├── pyproject.toml
└── README.md
```

## Dependencies and Package Management

### Dependency Management
- Use `pyproject.toml` for project configuration
- Pin exact versions in production (`requirements.txt`)
- Use version ranges for development (`pyproject.toml`)
- Regularly update dependencies
- Use virtual environments for isolation
- Document dependency rationale

```toml
# pyproject.toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "myapp"
version = "1.0.0"
description = "My Python application"
requires-python = ">=3.11"
dependencies = [
    "pydantic>=2.0.0",
    "fastapi>=0.100.0",
    "httpx>=0.24.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "black>=23.0.0",
    "ruff>=0.0.275",
    "mypy>=1.4.0",
]
```

## Code Quality Tools

### Required Tools
- **Black**: Code formatting
- **Ruff**: Linting and code quality
- **mypy**: Type checking
- **pytest**: Testing framework
- **pre-commit**: Git hooks for code quality

### Configuration Example
```toml
# pyproject.toml
[tool.black]
line-length = 88
target-version = ['py311']

[tool.ruff]
target-version = "py311"
line-length = 88
select = [
    "E",  # pycodestyle errors
    "W",  # pycodestyle warnings
    "F",  # pyflakes
    "I",  # isort
    "B",  # flake8-bugbear
    "C4", # flake8-comprehensions
    "UP", # pyupgrade
]

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "--strict-markers --disable-warnings"
```

## Code Review Checklist

### Before Submitting Code
- [ ] Code follows PEP 8 style guidelines
- [ ] All functions have type hints and docstrings
- [ ] Unit tests are written and passing
- [ ] Code coverage meets minimum requirements
- [ ] No hardcoded credentials or sensitive data
- [ ] Error handling is appropriate and comprehensive
- [ ] Performance considerations have been addressed
- [ ] Security best practices are followed
- [ ] Dependencies are properly documented
- [ ] Code is properly formatted with Black
- [ ] Linting passes with Ruff
- [ ] Type checking passes with mypy