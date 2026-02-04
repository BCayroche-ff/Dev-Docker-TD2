import os
from contextlib import asynccontextmanager

import psycopg2
import psycopg2.extras
from fastapi import FastAPI, HTTPException
from fastapi.responses import PlainTextResponse
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from pydantic import BaseModel

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://admin:changeme@localhost:5432/cloudshop")

http_requests_total = Counter(
    "http_requests_total", "Total HTTP requests", ["method", "path", "status"]
)
http_request_duration = Histogram(
    "http_request_duration_seconds", "HTTP request duration", ["method", "path"]
)


def get_db():
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = True
    return conn


def init_db():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                price DECIMAL(10,2) NOT NULL,
                stock INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
        cur.execute("SELECT COUNT(*) FROM products")
        if cur.fetchone()[0] == 0:
            cur.execute("""
                INSERT INTO products (name, description, price, stock) VALUES
                ('Laptop Pro', 'High-performance laptop', 1299.99, 50),
                ('Wireless Mouse', 'Ergonomic wireless mouse', 29.99, 200),
                ('USB-C Hub', '7-in-1 USB-C hub', 49.99, 150),
                ('Mechanical Keyboard', 'RGB mechanical keyboard', 89.99, 100),
                ('Monitor 27"', '4K IPS monitor', 449.99, 30)
            """)
        conn.close()
        print("Products table ready")
    except Exception as e:
        print(f"DB init error: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="CloudShop Products API", lifespan=lifespan)


class ProductCreate(BaseModel):
    name: str
    description: str | None = None
    price: float
    stock: int = 0


@app.get("/health")
def health():
    try:
        conn = get_db()
        conn.close()
        return {"status": "ok", "service": "products-api", "db": "connected"}
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")


@app.get("/metrics")
def metrics():
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/products")
def list_products():
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM products ORDER BY id")
    products = cur.fetchall()
    conn.close()
    return [dict(p) for p in products]


@app.get("/products/{product_id}")
def get_product(product_id: int):
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM products WHERE id = %s", (product_id,))
    product = cur.fetchone()
    conn.close()
    if not product:
        raise HTTPException(status_code=404, detail="product not found")
    return dict(product)


@app.post("/products", status_code=201)
def create_product(product: ProductCreate):
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        "INSERT INTO products (name, description, price, stock) VALUES (%s, %s, %s, %s) RETURNING *",
        (product.name, product.description, product.price, product.stock),
    )
    created = cur.fetchone()
    conn.close()
    return dict(created)
