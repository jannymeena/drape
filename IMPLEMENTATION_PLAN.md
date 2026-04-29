# Drape Implementation Plan: Enterprise AI B2C Application

> **Status:** Phases 1–3 are the active focus. See [`PHASE_PLAN.md`](./PHASE_PLAN.md) for the detailed, step-by-step breakdown of those phases. New contributors should start with [`README.md`](./README.md).

## 🏗️ Technology Stack Summary
*   **Monorepo Strategy:** Folder-based
*   **Backend:** Python 3.11+, FastAPI
*   **Mobile:** Flutter (Dart)
*   **Database:** PostgreSQL (with `pgvector` extension)
*   **Authentication:** Firebase Auth (JWT)
*   **Cloud Infrastructure:** AWS (ECS Fargate, Application Load Balancer, RDS)

---

## 📂 1. The Monorepo Folder Structure

Set up your root directory like this:

```text
drape/
├── backend/                  # FastAPI Application
│   ├── app/
│   │   ├── api/              # Routers (endpoints)
│   │   │   ├── dependencies/ # Auth, DB session injectors
│   │   │   └── routes/       # e.g., users.py, chat.py
│   │   ├── core/             # Config, security, exceptions
│   │   ├── schemas/          # Pydantic models (Input/Output validation)
│   │   ├── services/         # Business logic & AI clients
│   │   ├── db/               # SQLAlchemy models & migrations
│   │   └── main.py           # FastAPI app entry point
│   ├── alembic/              # Database migration scripts
│   ├── requirements.txt      # Python dependencies
│   └── Dockerfile            # Backend containerization
│
├── mobile/                   # Flutter Application
│   ├── lib/
│   │   ├── api_client/       # Auto-generated from FastAPI Swagger
│   │   ├── screens/          # UI
│   │   └── main.dart         # Flutter entry point
│   └── pubspec.yaml
│
├── docker-compose.yml        # Local development database
└── IMPLEMENTATION_PLAN.md    # This document
```

---

## 🛠️ Phase 1: API Skeleton (No DB, No Auth)
**Goal:** Define your API contracts (Inputs and Outputs) and test them via Swagger using dummy data.

1. **Initialize the Backend:**
   * Navigate to `/backend` and create a virtual environment (`python -m venv venv`).
   * Install FastAPI and Uvicorn: `pip install fastapi uvicorn pydantic`.
2. **Create Pydantic Schemas:** 
   * In `app/schemas/user.py`, define what a user object looks like (e.g., `UserResponse`, `UserCreate`).
3. **Build Dummy Routes:**
   * In `app/api/routes/users.py`, create standard CRUD endpoints.
   * Hardcode the return values. 
   ```python
   @router.get("/{user_id}", response_model=UserResponse)
   async def get_user(user_id: int):
       return {"id": user_id, "name": "Test User", "email": "test@test.com"}
   ```
4. **Test:** Run `uvicorn app.main:app --reload`. Open `http://localhost:8000/docs` and test your fake endpoints.

---

## 🗄️ Phase 2: Relational Database (Standard Tables)
**Goal:** Connect your API to a local database and replace dummy data with real standard CRUD operations.

1. **Local Database Setup:**
   * Create a `docker-compose.yml` in the root folder using the `pgvector` image (so you don't have to change it later):
     ```yaml
     services:
       db:
         image: pgvector/pgvector:pg16
         environment:
           POSTGRES_USER: admin
           POSTGRES_PASSWORD: password
           POSTGRES_DB: my_app_db
         ports:
           - "5432:5432"
     ```
   * Run `docker-compose up -d`.
2. **ORM Setup:**
   * Install DB libraries: `pip install sqlalchemy alembic psycopg2-binary`.
   * Initialize Alembic: `alembic init alembic`.
3. **Create Relational Models:**
   * In `app/db/models.py`, create your standard tables (`Users`, `Profiles`, etc.) using SQLAlchemy. **Do not add vector columns yet.**
4. **Wire up API:**
   * Update your FastAPI routes to inject a DB session (`Depends(get_db)`) and query the real database.
   * Use Alembic to generate and apply your first migration (`alembic revision --autogenerate -m "init"`, `alembic upgrade head`).

---

## 🔐 Phase 3: Authentication & Role-Based Access
**Goal:** Secure the API using Firebase, with local mock support for easy testing.

1. **Install Dependencies:** `pip install firebase-admin`.
2. **Write the Auth Dependency (with Local Mock):**
   * In `app/api/dependencies/auth.py`, create your auth logic:
     ```python
     import os
     from fastapi import Depends, HTTPException
     from fastapi.security import HTTPBearer
     
     security = HTTPBearer()

     async def get_current_user(credentials = Depends(security)):
         if os.getenv("ENVIRONMENT") == "local":
             # Fake user for offline local development
             return {"uid": "mock_123", "role": "customer"}
             
         # Production logic
         token = credentials.credentials
         try:
             # Add firebase_admin verify logic here
             decoded = auth.verify_id_token(token)
             return decoded
         except Exception:
             raise HTTPException(status_code=401, detail="Invalid auth token")
     ```
3. **Secure Routes:** Add `user = Depends(get_current_user)` to your endpoints.
4. **Test:** Verify in Swagger that the local mock works, then optionally switch `ENVIRONMENT` to `prod` and pass a real Firebase JWT.

---

## 🧠 Phase 4: AI & Vector Database Integration
**Goal:** Give the backend its "brain" by enabling `pgvector` and integrating AI models.

1. **Enable Vector Support in Postgres:**
   * Connect to your local DB via a tool like DBeaver or psql.
   * Run: `CREATE EXTENSION IF NOT EXISTS vector;`
2. **Update Models:**
   * Install pgvector python support: `pip install pgvector`.
   * Add the vector column to `app/db/models.py` (e.g., in a `Documents` or `Memory` table):
     ```python
     from pgvector.sqlalchemy import Vector
     
     class Document(Base):
         __tablename__ = "documents"
         id = Column(Integer, primary_key=True)
         user_id = Column(Integer, ForeignKey("users.id"))
         text_content = Column(String)
         embedding = Column(Vector(1536)) # OpenAI dimensions
     ```
   * Create and run an Alembic migration for this new column.
3. **AI Service Layer:**
   * Install AI SDK: `pip install openai`.
   * In `app/services/ai/client.py`, write functions to call OpenAI for Chat Completions and Embeddings.
4. **Vector Search Logic:**
   * Write SQLAlchemy queries to do similarity searches: 
     `db.query(Document).order_by(Document.embedding.l2_distance(user_query_embedding)).limit(5).all()`

---

## ☁️ Phase 5: Cloud Deployment (AWS)
**Goal:** Move the backend to production infrastructure.

1. **Database:** Provision an **Amazon RDS for PostgreSQL** instance. Connect to it and run `CREATE EXTENSION vector;`.
2. **Containerize API:** Ensure your `Dockerfile` correctly builds the FastAPI app. Push the image to **Amazon ECR**.
3. **Compute:** Create an **ECS Fargate** Cluster. Create a Task Definition using your ECR image.
4. **Networking:** Set up an **Application Load Balancer (ALB)** to route HTTP/HTTPS traffic to your Fargate containers.
5. **Environment Variables:** Securely store production secrets (OpenAI Keys, DB connection strings, Firebase Admin JSON) in AWS Secrets Manager or ECS Environment Variables.

---

## 📱 Phase 6: Mobile Client Integration (Flutter)
**Goal:** Build the UI and connect it to your live backend.

1. **Flutter Setup:** Navigate to `/mobile` and create a new Flutter app.
2. **Auto-Generate API Client:** 
   * Use an OpenAPI generator tool (like `swagger_dart_code_generator`).
   * Point it at your live (or local) FastAPI `openapi.json` file. It will generate all Data Models and API calling functions automatically.
3. **Authentication UI:**
   * Implement `firebase_auth` in Flutter.
   * Add Google and Apple sign-in buttons.
4. **Connect the Pieces:**
   * On successful login, retrieve the Firebase JWT in Flutter.
   * Pass this JWT in the `Authorization: Bearer <token>` header of your auto-generated API client.
   * Make requests to your fully functional Enterprise AI backend!