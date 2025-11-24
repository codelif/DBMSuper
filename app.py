from fastapi import FastAPI, Request
from starlette.responses import FileResponse
import mysql.connector

app = FastAPI()
db = mysql.connector.connect(
    host="localhost", user="harsh", passwd="harshpswd", db="dbms"
)


@app.get("/")
def index():
    return FileResponse("index.html")

@app.get("/editor")
def editor():
    return FileResponse("editor.html")

@app.get("/ddl")
def ddl():
    return FileResponse("ddl.html")

@app.get("/artifacts")
def artifacts():
    return FileResponse("artifacts.html")

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
    cur.execute("select name, type, description, param_count from DbArtifacts;")
    return cur.fetchall()

@app.get("/api/call_procedure")
def call_procedure(request: Request):
    params = dict(request.query_params)

    procedure_name = params.get("name")
    if not procedure_name:
        return {"error": "procedure name missing"}

    args = []
    i = 1
    while True:
        key = f"p{i}"
        if key not in params:
            break
        args.append(params[key])
        i += 1

    cur = db.cursor()
    if args:
        placeholders = ", ".join(["%s"] * len(args))
        query = f"call `{procedure_name}`({placeholders});"
        cur.execute(query, tuple(args))
    else:
        query = f"call `{procedure_name}`();"
        cur.execute(query)

    # collect the first result set to return
    all_rows = cur.fetchall()

    # drain any remaining result sets to keep connector in sync
    while cur.nextset():
        try:
            cur.fetchall()
        except mysql.connector.errors.InterfaceError:
            break

    db.commit()
    cur.close()
    return all_rows


@app.get("/api/call_function")
def call_function(request: Request):
    params = dict(request.query_params)

    function_name = params.get("name")
    if not function_name:
        return {"error": "function name missing"}

    args = []
    i = 1
    while True:
        key = f"p{i}"
        if key not in params:
            break
        args.append(params[key])
        i += 1

    cur = db.cursor()
    if args:
        placeholders = ", ".join(["%s"] * len(args))
        query = f"select `{function_name}`({placeholders});"
        cur.execute(query, tuple(args))
    else:
        query = f"select `{function_name}`();"
        cur.execute(query)

    rows = cur.fetchall()
    cur.close()
    return rows

@app.get("/api/describe/{name}")
def describe_table(name: str):
    cur = db.cursor()
    cur.execute(f"DESC {name};")
    return cur.fetchall()


@app.get("/api/update_table")
def update_table(request: Request):
    params = dict(request.query_params)

    table_name = params.get("table_name")
    if not table_name:
        return {"error": "table name missing"}

    column_name = params.get("column_name")
    if not column_name:
        return {"error": "column name missing"}

    value = params.get("value")
    if value is None:
        return {"error": "value missing"}

    p_col = params.get("primary_col")
    p_val = params.get("primary_val")
    if not p_col or not p_val:
        return {"error": "no value for where clause"}

    query = f"UPDATE `{table_name}` SET `{column_name}` = %s WHERE `{p_col}` = %s;"
    cur = db.cursor()
    cur.execute(query, (value, p_val))
    db.commit()
    return {"status": "success", "table": table_name}

@app.get("/api/delete_table")
def delete_table(request: Request):
    params = dict(request.query_params)

    table_name = params.get("table_name")
    if not table_name:
        return {"error": "table name missing"}

    p_col = params.get("primary_col")
    p_val = params.get("primary_val")
    if not p_col or not p_val:
        return {"error": "no value for where clause"}

    query = f"DELETE FROM `{table_name}` WHERE `{p_col}` = %s;"
    cur = db.cursor()
    cur.execute(query, (p_val,))
    db.commit()
    return {"status": "success", "table": table_name}
