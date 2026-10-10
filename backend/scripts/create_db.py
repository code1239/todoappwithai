import os
import sys

import pyodbc
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))

host = os.getenv('DB_HOST', 'localhost')
port = os.getenv('DB_PORT', '1433')
user = os.getenv('DB_USER', 'sa')
pwd = os.getenv('DB_PASSWORD', '')
driver = os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server')
dbname = sys.argv[1] if len(sys.argv) > 1 else os.getenv('DB_NAME', 'todo_db')

conn_str = (
    f'DRIVER={{{driver}}};SERVER={host},{port};UID={user};PWD={pwd};'
    'TrustServerCertificate=yes;Encrypt=yes'
)
cn = pyodbc.connect(conn_str, autocommit=True)
cur = cn.cursor()
cur.execute(f"IF DB_ID('{dbname}') IS NULL CREATE DATABASE [{dbname}]")
print(f'database ready: {dbname}')
