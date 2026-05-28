import json, requests, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

with open("C:\\Jsp\\Pol-mate-spring\\transcripts_2026_0528.json", encoding="utf-8-sig") as f:
    transcripts = json.load(f)

payload = {
    "caseId": "2026-0528",
    "caseName": "강남구 카페 절도 및 폭행 사건",
    "transcripts": transcripts
}

print(f"조서 수: {len(transcripts)}")
for t in transcripts:
    print(f"  - {t['name']} ({t['type']}) 텍스트길이={len(t['text'])}")

print("\n관계망 AI 분석 요청 중...")
resp = requests.post("http://localhost:5001/relation_map", json=payload, timeout=300)
print(f"Status: {resp.status_code}")

result = resp.json()
print(f"Success: {result.get('success')}")
if result.get("error"):
    print(f"Error: {result.get('error')}")
else:
    response_str = result.get("response", "")
    print(f"\n=== AI 응답 ===\n{response_str}")

    # JSON 파싱 시도
    try:
        parsed = json.loads(response_str)
        persons = parsed.get("persons", [])
        edges   = parsed.get("edges", [])
        print(f"\n=== 파싱 결과 ===")
        print(f"인물 {len(persons)}명:")
        for p in persons:
            print(f"  [{p.get('role')}] {p.get('name')} - {p.get('label','')}")
        print(f"\n관계 {len(edges)}개:")
        for e in edges:
            print(f"  {e.get('source')} → {e.get('target')} [{e.get('relType')}] status={e.get('status','?')}")
    except Exception as ex:
        print(f"JSON 파싱 실패: {ex}")
