# FastAPI Best Practices Implementation Standard

## Overview

FastAPI is a modern, high-performance web framework for building APIs with Python 3.11+ based on standard Python type hints. This document outlines best practices for developing robust, scalable, and maintainable FastAPI applications following industry standards and security best practices.

## Project Structure and Organization

### Recommended Directory Structure
```
project/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI application entry point
│   ├── config.py              # Configuration management
│   ├── dependencies.py        # Dependency injection
│   ├── middleware.py          # Custom middleware
│   ├── exceptions.py          # Custom exception handlers
│   ├── api/
│   │   ├── __init__.py
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── endpoints/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── users.py
│   │   │   │   ├── auth.py
│   │   │   │   └── health.py
│   │   │   └── api.py         # API router aggregation
│   │   └── deps.py            # API dependencies
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py          # Core configuration
│   │   ├── security.py        # Security utilities
│   │   └── database.py        # Database configuration
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py            # Base model classes
│   │   ├── user.py
│   │   └── domain.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py            # Pydantic models
│   │   ├── auth.py
│   │   └── common.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── user_service.py
│   │   └── auth_service.py
│   ├── repositories/
│   │   ├── __init__.py
│   │   └── user_repository.py
│   └── utils/
│       ├── __init__.py
│       ├── helpers.py
│       └── validators.py
├── tests/
├── alembic/                   # Database migrations
├── requirements.txt
├── pyproject.toml
└── Dockerfile
```

## Application Configuration

### Settings Management
Use Pydantic BaseSettings for configuration management with environment variable support:

```python
from pydantic import BaseSettings, Field, validator
from typing import Optional, List
from pathlib import Path

class Settings(BaseSettings):
    """Application settings with environment variable support."""
    
    # Application
    app_name: str = "FastAPI Application"
    app_version: str = "1.0.0"
    debug: bool = False
    
    # API
    api_v1_prefix: str = "/api/v1"
    allowed_hosts: List[str] = ["*"]
    
    # Database
    database_url: str = Field(..., env="DATABASE_URL")
    database_pool_size: int = Field(default=10, env="DATABASE_POOL_SIZE")
    database_max_overflow: int = Field(default=20, env="DATABASE_MAX_OVERFLOW")
    
    # Security
    secret_key: str = Field(..., env="SECRET_KEY")
    access_token_expire_minutes: int = Field(default=30, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    algorithm: str = "HS256"
    
    # CORS
    cors_origins: List[str] = Field(default=[], env="CORS_ORIGINS")
    cors_credentials: bool = True
    cors_methods: List[str] = ["*"]
    cors_headers: List[str] = ["*"]
    
    # Logging
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    log_format: str = "json"
    
    # Redis (optional)
    redis_url: Optional[str] = Field(None, env="REDIS_URL")
    
    @validator('cors_origins', pre=True)
    def assemble_cors_origins(cls, v):
        """Parse CORS origins from environment variable."""
        if isinstance(v, str) and not v.startswith('['):
            return [i.strip() for i in v.split(',')]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)
    
    @validator('secret_key')
    def validate_secret_key(cls, v):
        """Ensure secret key is sufficiently complex."""
        if len(v) < 32:
            raise ValueError('Secret key must be at least 32 characters long')
        return v

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

settings = Settings()
```

### Application Factory Pattern
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
import uvicorn

def create_app() -> FastAPI:
    """Create and configure FastAPI application."""
    
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
        openapi_url="/openapi.json" if settings.debug else None,
    )
    
    # Add middleware
    setup_middleware(app)
    
    # Add exception handlers
    setup_exception_handlers(app)
    
    # Include routers
    setup_routers(app)
    
    return app

def setup_middleware(app: FastAPI) -> None:
    """Configure application middleware."""
    
    # Trust proxy headers
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=settings.allowed_hosts
    )
    
    # CORS
    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=settings.cors_credentials,
            allow_methods=settings.cors_methods,
            allow_headers=settings.cors_headers,
        )
    
    # Custom middleware
    from .middleware import LoggingMiddleware, SecurityHeadersMiddleware
    app.add_middleware(LoggingMiddleware)
    app.add_middleware(SecurityHeadersMiddleware)
```

## API Design and Structure

### Router Organization
Organize endpoints using APIRouter for better modularity:

```python
# app/api/v1/endpoints/users.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, get_db
from app.schemas.user import User, UserCreate, UserUpdate
from app.services.user_service import UserService
from app.models.user import User as UserModel

router = APIRouter()

@router.get("/", response_model=List[User])
async def read_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_active_user),
) -> List[User]:
    """Retrieve users with pagination."""
    service = UserService(db)
    users = await service.get_users(skip=skip, limit=limit)
    return users

@router.post("/", response_model=User, status_code=status.HTTP_201_CREATED)
async def create_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_active_superuser),
) -> User:
    """Create new user."""
    service = UserService(db)
    
    # Check if user already exists
    existing_user = await service.get_user_by_email(user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists"
        )
    
    user = await service.create_user(user_data)
    return user
```

### Response Models and Serialization
Use Pydantic models for request/response serialization:

```python
# app/schemas/user.py
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    """User role enumeration."""
    ADMIN = "admin"
    USER = "user"
    MODERATOR = "moderator"

class UserBase(BaseModel):
    """Base user schema."""
    email: EmailStr
    full_name: Optional[str] = None
    is_active: bool = True
    role: UserRole = UserRole.USER

class UserCreate(UserBase):
    """User creation schema."""
    password: str = Field(..., min_length=8, max_length=128)
    
    @validator('password')
    def validate_password(cls, v):
        """Validate password complexity."""
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one digit')
        return v

class UserUpdate(BaseModel):
    """User update schema."""
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    is_active: Optional[bool] = None
    role: Optional[UserRole] = None

class User(UserBase):
    """User response schema."""
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class UserInDB(User):
    """User schema with sensitive data."""
    hashed_password: str
```

### Error Handling and Exceptions
Implement comprehensive error handling:

```python
# app/exceptions.py
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
import logging

logger = logging.getLogger(__name__)

class CustomHTTPException(HTTPException):
    """Custom HTTP exception with additional context."""
    
    def __init__(
        self,
        status_code: int,
        detail: str,
        error_code: Optional[str] = None,
        context: Optional[dict] = None,
    ):
        super().__init__(status_code=status_code, detail=detail)
        self.error_code = error_code
        self.context = context or {}

class UserNotFoundError(CustomHTTPException):
    """User not found exception."""
    
    def __init__(self, user_id: int):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found",
            error_code="USER_NOT_FOUND",
            context={"user_id": user_id}
        )

async def validation_exception_handler(
    request: Request, 
    exc: RequestValidationError
) -> JSONResponse:
    """Handle validation errors."""
    logger.warning(f"Validation error for {request.url}: {exc}")
    
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "Validation Error",
            "error_code": "VALIDATION_ERROR",
            "details": exc.errors(),
            "path": str(request.url.path),
        },
    )

async def custom_http_exception_handler(
    request: Request,
    exc: CustomHTTPException
) -> JSONResponse:
    """Handle custom HTTP exceptions."""
    logger.error(f"Custom HTTP exception for {request.url}: {exc}")
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "error_code": exc.error_code,
            "context": exc.context,
            "path": str(request.url.path),
        },
    )
```

## Security Implementation

### Authentication and Authorization
Implement JWT-based authentication with proper security measures:

```python
# app/core/security.py
from datetime import datetime, timedelta
from typing import Optional, Union
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

def create_access_token(
    data: dict, 
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT access token."""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.access_token_expire_minutes
        )
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode, 
        settings.secret_key, 
        algorithm=settings.algorithm
    )
    return encoded_jwt

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Generate password hash."""
    return pwd_context.hash(password)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> UserModel:
    """Extract current user from JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.secret_key,
            algorithms=[settings.algorithm]
        )
        user_id: int = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if user is None:
        raise credentials_exception
    
    return user

async def get_current_active_user(
    current_user: UserModel = Depends(get_current_user),
) -> UserModel:
    """Ensure user is active."""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    return current_user
```

### Input Validation and Sanitization
Implement comprehensive input validation:

```python
# app/utils/validators.py
from typing import Optional
import re
from pydantic import validator
from fastapi import HTTPException, status

class ValidationUtils:
    """Utility class for common validation functions."""
    
    @staticmethod
    def validate_email(email: str) -> str:
        """Validate and normalize email address."""
        email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_regex, email):
            raise ValueError("Invalid email format")
        return email.lower().strip()
    
    @staticmethod
    def sanitize_string(value: str, max_length: int = 255) -> str:
        """Sanitize string input."""
        if not value:
            return ""
        
        # Remove potentially harmful characters
        sanitized = re.sub(r'[<>"\'']', '', value.strip())
        
        if len(sanitized) > max_length:
            raise ValueError(f"String too long (max {max_length} characters)")
        
        return sanitized
    
    @staticmethod
    def validate_pagination(skip: int = 0, limit: int = 100) -> tuple[int, int]:
        """Validate pagination parameters."""
        if skip < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Skip parameter must be non-negative"
            )
        
        if limit <= 0 or limit > 1000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Limit parameter must be between 1 and 1000"
            )
        
        return skip, limit
```

## Database Integration

### SQLAlchemy Configuration
Configure database with proper connection pooling and async support:

```python
# app/core/database.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings

# Database engine configuration
engine = create_engine(
    settings.database_url,
    pool_size=settings.database_pool_size,
    max_overflow=settings.database_max_overflow,
    pool_pre_ping=True,  # Verify connections before use
    echo=settings.debug,  # Log SQL queries in debug mode
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    """Dependency to get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### Repository Pattern
Implement repository pattern for data access:

```python
# app/repositories/base.py
from typing import Generic, TypeVar, Type, Optional, List
from sqlalchemy.orm import Session
from sqlalchemy.ext.declarative import DeclarativeMeta

ModelType = TypeVar("ModelType", bound=DeclarativeMeta)

class BaseRepository(Generic[ModelType]):
    """Base repository with common CRUD operations."""
    
    def __init__(self, db: Session, model: Type[ModelType]):
        self.db = db
        self.model = model
    
    def get(self, id: int) -> Optional[ModelType]:
        """Get entity by ID."""
        return self.db.query(self.model).filter(self.model.id == id).first()
    
    def get_multi(self, *, skip: int = 0, limit: int = 100) -> List[ModelType]:
        """Get multiple entities with pagination."""
        return (
            self.db.query(self.model)
            .offset(skip)
            .limit(limit)
            .all()
        )
    
    def create(self, *, obj_in: dict) -> ModelType:
        """Create new entity."""
        db_obj = self.model(**obj_in)
        self.db.add(db_obj)
        self.db.commit()
        self.db.refresh(db_obj)
        return db_obj
    
    def update(self, *, db_obj: ModelType, obj_in: dict) -> ModelType:
        """Update existing entity."""
        for field, value in obj_in.items():
            setattr(db_obj, field, value)
        
        self.db.add(db_obj)
        self.db.commit()
        self.db.refresh(db_obj)
        return db_obj
    
    def remove(self, *, id: int) -> ModelType:
        """Delete entity by ID."""
        obj = self.db.query(self.model).get(id)
        self.db.delete(obj)
        self.db.commit()
        return obj
```

## Service Layer Pattern

### Business Logic Organization
Implement service layer for business logic:

```python
# app/services/user_service.py
from typing import Optional, List
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.repositories.user_repository import UserRepository
from app.schemas.user import UserCreate, UserUpdate
from app.models.user import User
from app.core.security import get_password_hash, verify_password

class UserService:
    """User business logic service."""
    
    def __init__(self, db: Session):
        self.db = db
        self.user_repo = UserRepository(db)
    
    async def get_user_by_id(self, user_id: int) -> Optional[User]:
        """Retrieve user by ID."""
        user = self.user_repo.get(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        return user
    
    async def get_user_by_email(self, email: str) -> Optional[User]:
        """Retrieve user by email."""
        return self.user_repo.get_by_email(email)
    
    async def create_user(self, user_data: UserCreate) -> User:
        """Create new user with validation."""
        # Check if user already exists
        existing_user = await self.get_user_by_email(user_data.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this email already exists"
            )
        
        # Hash password
        hashed_password = get_password_hash(user_data.password)
        
        # Create user data
        user_dict = user_data.dict(exclude={'password'})
        user_dict['hashed_password'] = hashed_password
        
        return self.user_repo.create(obj_in=user_dict)
    
    async def authenticate_user(self, email: str, password: str) -> Optional[User]:
        """Authenticate user credentials."""
        user = await self.get_user_by_email(email)
        if not user:
            return None
        
        if not verify_password(password, user.hashed_password):
            return None
        
        return user
```

## Testing Standards

### Unit Testing with pytest
Implement comprehensive testing strategy:

```python
# tests/conftest.py
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import create_app
from app.core.database import get_db, Base
from app.core.config import settings

# Test database configuration
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="session")
def db():
    """Create test database."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def db_session(db):
    """Create test database session."""
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)
    yield session
    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture(scope="function")
def client(db_session):
    """Create test client."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()

@pytest.fixture
def test_user_data():
    """Sample user data for testing."""
    return {
        "email": "test@example.com",
        "full_name": "Test User",
        "password": "TestPassword123",
    }
```

### API Testing Examples
```python
# tests/test_users.py
import pytest
from fastapi import status
from app.schemas.user import UserCreate

class TestUserEndpoints:
    """Test user API endpoints."""
    
    def test_create_user_success(self, client, test_user_data):
        """Test successful user creation."""
        response = client.post("/api/v1/users/", json=test_user_data)
        
        assert response.status_code == status.HTTP_201_CREATED
        data = response.json()
        assert data["email"] == test_user_data["email"]
        assert data["full_name"] == test_user_data["full_name"]
        assert "id" in data
        assert "hashed_password" not in data
    
    def test_create_user_duplicate_email(self, client, test_user_data):
        """Test user creation with duplicate email."""
        # Create first user
        client.post("/api/v1/users/", json=test_user_data)
        
        # Attempt to create duplicate
        response = client.post("/api/v1/users/", json=test_user_data)
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "already exists" in response.json()["detail"]
    
    def test_get_user_not_found(self, client):
        """Test retrieving non-existent user."""
        response = client.get("/api/v1/users/999")
        
        assert response.status_code == status.HTTP_404_NOT_FOUND
```

## Performance Optimization

### Caching Strategies
Implement caching for improved performance:

```python
# app/core/cache.py
from functools import wraps
from typing import Optional, Callable, Any
import json
import redis
from app.core.config import settings

# Redis client setup
redis_client = redis.from_url(settings.redis_url) if settings.redis_url else None

def cache_response(expiration: int = 300):
    """Decorator to cache API responses."""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            if not redis_client:
                return await func(*args, **kwargs)
            
            # Create cache key
            cache_key = f"{func.__name__}:{hash(str(args) + str(kwargs))}"
            
            # Try to get from cache
            cached_result = redis_client.get(cache_key)
            if cached_result:
                return json.loads(cached_result)
            
            # Execute function and cache result
            result = await func(*args, **kwargs)
            redis_client.setex(
                cache_key,
                expiration,
                json.dumps(result, default=str)
            )
            
            return result
        return wrapper
    return decorator
```

### Database Query Optimization
```python
# app/repositories/user_repository.py
from sqlalchemy.orm import joinedload
from sqlalchemy import and_, or_

class UserRepository(BaseRepository[User]):
    """User repository with optimized queries."""
    
    def get_users_with_profiles(self, skip: int = 0, limit: int = 100):
        """Get users with their profiles in a single query."""
        return (
            self.db.query(User)
            .options(joinedload(User.profile))
            .filter(User.is_active == True)
            .offset(skip)
            .limit(limit)
            .all()
        )
    
    def search_users(
        self, 
        query: str, 
        skip: int = 0, 
        limit: int = 100
    ) -> List[User]:
        """Search users by name or email."""
        search_filter = or_(
            User.full_name.ilike(f"%{query}%"),
            User.email.ilike(f"%{query}%")
        )
        
        return (
            self.db.query(User)
            .filter(and_(User.is_active == True, search_filter))
            .offset(skip)
            .limit(limit)
            .all()
        )
```

## Monitoring and Observability

### Logging Configuration
```python
# app/core/logging.py
import logging
import sys
from typing import Dict, Any
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    """JSON formatter for structured logging."""
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        log_data: Dict[str, Any] = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        
        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        # Add extra fields
        for key, value in record.__dict__.items():
            if key not in {
                "name", "msg", "args", "levelname", "levelno", "pathname",
                "filename", "module", "exc_info", "exc_text", "stack_info",
                "lineno", "funcName", "created", "msecs", "relativeCreated",
                "thread", "threadName", "processName", "process", "getMessage"
            }:
                log_data[key] = value
        
        return json.dumps(log_data, default=str)

def setup_logging():
    """Configure application logging."""
    
    # Create logger
    logger = logging.getLogger("app")
    logger.setLevel(getattr(logging, settings.log_level.upper()))
    
    # Create handler
    handler = logging.StreamHandler(sys.stdout)
    
    # Set formatter
    if settings.log_format == "json":
        formatter = JSONFormatter()
    else:
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
    
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    
    return logger
```

### Health Checks and Metrics
```python
# app/api/v1/endpoints/health.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.api.deps import get_db
from app.core.config import settings
import time

router = APIRouter()

@router.get("/health")
async def health_check():
    """Basic health check endpoint."""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "version": settings.app_version,
    }

@router.get("/health/detailed")
async def detailed_health_check(db: Session = Depends(get_db)):
    """Detailed health check with dependency verification."""
    checks = {}
    overall_status = "healthy"
    
    # Database check
    try:
        db.execute("SELECT 1")
        checks["database"] = {"status": "healthy"}
    except Exception as e:
        checks["database"] = {"status": "unhealthy", "error": str(e)}
        overall_status = "unhealthy"
    
    # Redis check (if configured)
    if settings.redis_url:
        try:
            from app.core.cache import redis_client
            redis_client.ping()
            checks["redis"] = {"status": "healthy"}
        except Exception as e:
            checks["redis"] = {"status": "unhealthy", "error": str(e)}
            overall_status = "unhealthy"
    
    return {
        "status": overall_status,
        "timestamp": time.time(),
        "version": settings.app_version,
        "checks": checks,
    }
```

## Deployment Best Practices

### Docker Configuration
```dockerfile
# Dockerfile
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Production Configuration
```python
# app/main.py production setup
import uvicorn
from fastapi import FastAPI
from app.core.config import settings
from app.core.logging import setup_logging

# Setup logging
setup_logging()

# Create application
app = create_app()

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        workers=4,
        loop="uvloop",
        http="httptools",
        access_log=True,
        log_config=None,  # Use our custom logging
    )
```

## Code Quality and Standards

### Pre-commit Configuration
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/psf/black
    rev: 23.3.0
    hooks:
      - id: black
        language_version: python3.11

  - repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.0.275
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.4.0
    hooks:
      - id: mypy
        additional_dependencies: [types-all]
```

### FastAPI-Specific Linting Rules
```toml
# pyproject.toml FastAPI-specific configuration
[tool.ruff]
select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings  
    "F",   # pyflakes
    "I",   # isort
    "B",   # flake8-bugbear
    "C4",  # flake8-comprehensions
    "UP",  # pyupgrade
    "SIM", # flake8-simplify
    "TCH", # flake8-type-checking
]

[tool.ruff.per-file-ignores]
"app/api/v1/endpoints/*.py" = ["B008"]  # Allow Depends() in function defaults

[tool.mypy]
plugins = ["pydantic.mypy"]
strict = true
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
addopts = [
    "--strict-markers",
    "--disable-warnings",
    "--cov=app",
    "--cov-report=term-missing",
    "--cov-report=html",
    "--cov-fail-under=80"
]
```

## Security Checklist

### Production Security Requirements
- [ ] Use HTTPS in production with proper TLS configuration
- [ ] Implement rate limiting to prevent abuse
- [ ] Validate all input data using Pydantic models
- [ ] Use parameterized queries to prevent SQL injection
- [ ] Implement proper CORS configuration
- [ ] Use secure session management with JWT tokens
- [ ] Hash passwords using bcrypt with proper salt rounds
- [ ] Implement request size limits
- [ ] Use security headers middleware
- [ ] Log security events and failed authentication attempts
- [ ] Regularly update dependencies for security patches
- [ ] Use environment variables for sensitive configuration
- [ ] Implement proper error handling without information disclosure
- [ ] Use trusted host middleware in production
- [ ] Implement content type validation
- [ ] Use proper authentication for all protected endpoints

This comprehensive FastAPI implementation standard ensures robust, scalable, and maintainable API development following industry best practices and security standards.