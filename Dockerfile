# Stage 1: Build frontend
FROM node:20-alpine AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# Stage 2: Python backend
FROM python:3.11-slim
WORKDIR /app
COPY backend/ ./backend/
COPY artifacts/ ./artifacts/
COPY --from=frontend-build /app/frontend/dist ./frontend/dist
RUN pip install -r backend/requirements.txt
EXPOSE 10000
CMD ["sh", "-c", "uvicorn backend.app:app --host 0.0.0.0 --port ${PORT:-10000}"]