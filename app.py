from fastapi import FastAPI
from starlette.responses import FileResponse
import mysql.connector

app = FastAPI()
db = mysql.connector.connect(
    host="localhost", user="harsh", passwd="harshpswd", db="dbms"
)


@app.get("/")
def home():
    return FileResponse("index.html")


@app.get("/api/tables")
def tables():
    cur = db.cursor()
    cur.execute("SHOW TABLES;")
    return cur.fetchall()


@app.get("/api/tables/{name}")
def fetch_table(name: str):
    cur = db.cursor()
    cur.execute(f"SELECT * FROM {name};")
    return cur.fetchall()
