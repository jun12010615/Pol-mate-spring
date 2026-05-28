import pymysql, json

conn = pymysql.connect(
    host="113.198.238.131", port=8306,
    user="root", password="dita2414",
    db="pol-mate", charset="utf8mb4"
)
cur = conn.cursor(pymysql.cursors.DictCursor)
cur.execute("""
    SELECT stmt_name, stmt_type, original_text
    FROM transcripts
    WHERE case_id = '2026-0528'
    ORDER BY transcript_id
""")
rows = cur.fetchall()
conn.close()

result = []
for r in rows:
    result.append({
        "name": r["stmt_name"] or "",
        "type": r["stmt_type"] or "",
        "text": r["original_text"] or ""
    })

print(json.dumps(result, ensure_ascii=False))
