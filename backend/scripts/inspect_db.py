import os
import sys

import pyodbc
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))

conn_str = (
    f"DRIVER={{{os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server')}}};"
    f"SERVER={os.getenv('DB_HOST', 'localhost')},{os.getenv('DB_PORT', '1433')};"
    f"DATABASE={os.getenv('DB_NAME', 'todo_db')};"
    f"UID={os.getenv('DB_USER', 'sa')};PWD={os.getenv('DB_PASSWORD', '')};"
    "TrustServerCertificate=yes;Encrypt=yes"
)
cn = pyodbc.connect(conn_str)
cur = cn.cursor()

print('=== Tablolar ===')
for row in cur.execute(
    "SELECT name FROM sys.tables WHERE name LIKE 'planner%' OR name LIKE 'ai%' ORDER BY name"
):
    print(' -', row[0])

print('\n=== planner_task ===')
for r in cur.execute(
    "SELECT id, title, date, kind, start_time, end_time, priority, status, goal_id FROM planner_task ORDER BY id"
):
    print(f'  #{r.id} {r.title:22} {r.date} {r.kind:5} {r.start_time} {r.priority:6} {r.status} goal={r.goal_id}')

print('\n=== planner_weeklygoal ===')
for r in cur.execute(
    "SELECT id, title, metric, target, week_start FROM planner_weeklygoal ORDER BY id"
):
    print(f'  #{r.id} {r.title:20} {r.metric} target={r.target} week={r.week_start}')

print('\n=== ai_aiproposal ===')
for r in cur.execute(
    "SELECT id, kind, status, LEFT(summary, 40) AS s FROM ai_aiproposal ORDER BY id"
):
    print(f'  #{r.id} {r.kind} {r.status} | {r.s}')
