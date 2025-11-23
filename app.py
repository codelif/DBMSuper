from fastapi import FastAPI, Request, params
from starlette.responses import FileResponse
import mysql.connector

app = FastAPI()
db = mysql.connector.connect(
    host="localhost", user="karvy", passwd="folkofair", db="dbms"
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

@app.get("/api/create_table")
def create_table(request: Request):
    params = dict(request.query_params)

    table_name = params.get("name")
    if not table_name:
        return {"error": "table name missing"}

    # collect columns like col1, type1, col2, type2...
    columns = []
    i = 1
    while True:
        col = params.get(f"col{i}")
        typ = params.get(f"type{i}")
        if not col or not typ:
            break
        columns.append(f"`{col}` {typ}")
        i += 1

    if not columns:
        return {"error": "no columns provided"}

    query = f"CREATE TABLE `{table_name}` ({', '.join(columns)});"

    cur = db.cursor()
    cur.execute(query)
    db.commit()
    return {"status": "success", "table": table_name}

@app.get("/api/drop")
def drop_table(request: Request):
    params=dict(request.query_params)

    table_name= params.get("name")
    if not table_name:
        return {"error": "table name missing"}
    
    
    query = f"DROP TABLE `{table_name}`;"

    cur = db.cursor()
    cur.execute(query)
    db.commit()

    return {"status": "success", "table": table_name}

@app.get("/api/truncate")
def truncate_table(request: Request):
    params=dict(request.query_params)

    table_name= params.get("name")
    if not table_name:
        return {"error": "table name missing"}
    
    
    query = f"TRUNCATE TABLE `{table_name}`;"

    cur = db.cursor()
    cur.execute(query)
    db.commit()

    return {"status": "success", "table": table_name}

@app.get("/api/artifacts")
def fetch_all_artifacts():
    cur = db.cursor()
    cur.execute(f"SELECT * FROM DbArtifacts;")
    return cur.fetchall()

@app.get("/api/call_procedure")
def call_procedure(request: Request):
    params=dict(request.query_params)

    procedure_name= params.get("name")
    if not procedure_name:
        return {"error": "table name missing"}
    
    
    query = f"call `{procedure_name}`;"

    cur = db.cursor()
    cur.execute(query)
    return cur.fetchall()

@app.get("/api/call_function")
def call_function(request: Request):
    params=dict(request.query_params)

    function_name= params.get("name")
    if not function_name:
        return {"error": "table name missing"}
    
    
    query = f"select `{function_name}`;"

    cur = db.cursor()
    cur.execute(query)
    return cur.fetchall()



