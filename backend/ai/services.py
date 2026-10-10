import json
import os
from datetime import date as date_cls
from datetime import datetime, time, timedelta

from django.db import transaction
from django.utils import timezone
from openai import OpenAI

from planner.models import Task, WeeklyGoal
from .models import AIProposal, ChatMessage, ChatSession

SYSTEM_PROMPT = """Sen bir kisisel planlama asistanisin. Kullanicinin haftalik hedeflerine
ulasmasi icin gunluk planini duzenlersin. GOREVIN: mevcut duruma bakip, haftalik hedeflere
ulasmayi saglayacak somut plan degisiklikleri ONERMEK.

Kurallar:
- Sadece JSON dondur, baska hicbir sey yazma.
- Gecmis tarihlere gorev ekleme; bugun veya sonrasina ekle.
- Saatli bloklar icin start_time ve end_time "HH:MM" formatinda ve mantikli olsun (cakismasin).
- Serbest liste gorevleri icin kind="list", saat alanlari null olsun.
- Bir haftalik hedefe bagli gorevlerde ilgili goal_id'yi kullan.
- Turkce yaz.

JSON semasi:
{
  "summary": "kullaniciya gosterecegin kisa Turkce aciklama",
  "changes": [
    {"action": "create", "title": "...", "date": "YYYY-MM-DD", "kind": "block"|"list",
     "start_time": "HH:MM"|null, "end_time": "HH:MM"|null,
     "duration_minutes": sayi|null, "priority": "low"|"medium"|"high",
     "notes": "...", "goal_id": sayi|null},
    {"action": "update", "task_id": sayi, "date": "YYYY-MM-DD"|null, "start_time": "HH:MM"|null,
     "end_time": "HH:MM"|null, "priority": "low"|"medium"|"high"|null, "status": "todo"|"done"|"skipped"|null},
    {"action": "delete", "task_id": sayi}
  ]
}"""

CHAT_SYSTEM_PROMPT = """Sen kullaniciya haftalik planini cikarmasinda yardim eden planlama asistanisin.

Kurallar:
- Kullaniciyla bedava Turkce konus, kisa ve samimi ol.
- Tekrarlayan, olculebilir bir ihtiyac gordun mu (ornek: "haftada 3 kere spor",
  "500 sayfa kitap") -> ONCE gerekli sorulari sor (hangi gunler/hangi saat uygun),
  bilgi toplaninca HAFTALIK HEDEF ve/veya GUNLUK GOREVLER olarak taslak uret.
- Tek seferlik bir fiil/isin varsa (ornek: "pazartesi doktor randevum var") ->
  saati biliniyorsa zamanli blok, degilse "saati onemli mi, biliyor musun?" diye sor;
  onemsizse ilgili gune serbest liste gorevi olarak taslak uret.
- Hacimli hedefleri (sayfa, dakika vb.) haftanin kalan gunlerine dengeli dagit;
  hedefi haftalik hedef olarak, bolumu de gunluk gorevler olarak ver.
- Zaten planda olan gorevleri tekrarlama; mevcut planla celismeyen oneriler yap.
- Gecmis tarihlere gorev ekleme (bugun veya sonrasi).
- Saatli bloklar "HH:MM" ve mantikli olsun; serbest liste gorevleri kind="list".
- Bu hafta icin hedef olusturuyorsan metric: "count" (adet) veya "duration" (dakika),
  target sayi, ve istersen unit (ornek "sayfa", "kez") verebilirsin. week_start degeri
  BELGELER'deki hafta baslangicina esit olsun.
- Yeterli bilgi yoksa draft=null dondur, soru sor. Bilgi tamamsa draft'i doldur.

CEVAP FORMATI (SADECE JSON, baska bir sey yazma):
{
  "reply": "kullaniciya gosterecegin Turkce yanit",
  "draft": null | {
    "changes": [
      {"action":"create_goal","title":"...","metric":"count"|"duration",
       "target": sayi, "unit":"..."|null, "week_start":"YYYY-MM-DD"},
      {"action":"create","title":"...","date":"YYYY-MM-DD","kind":"block"|"list",
       "start_time":"HH:MM"|null,"end_time":"HH:MM"|null,
       "duration_minutes":sayi|null,"priority":"low"|"medium"|"high",
       "notes":"...","goal_id":sayi|null,"goal_ref":dizin|null},
      {"action":"update","task_id":sayi, "date":"YYYY-MM-DD"|null,
       "start_time":"HH:MM"|null,"end_time":"HH:MM"|null,
       "priority":"low"|"medium"|"high"|null,"status":"todo"|"done"|"skipped"|null},
      {"action":"delete","task_id":sayi}
    ]
  }
}

Ayrica: draft icindeki create_goal'in kacinci sirada oldugunu bil; create gorevlerinde
o hedefe baglamak icin goal_ref'i (0'dan baslayan dizin) kullan. goal_ref yerine dogrudan
bilinen goal_id de kullanilabilir.
"""


def _client():
    api_key = os.getenv('OPENAI_API_KEY', '')
    if not api_key or api_key.startswith('sk-REPLACE'):
        raise RuntimeError('OPENAI_API_KEY ayarlanmamis (.env dosyasini doldurun).')
    return OpenAI(api_key=api_key)


def _model():
    return os.getenv('OPENAI_MODEL', 'gpt-4o-mini')


def build_context(user, day=None):
    today = day or timezone.localdate()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)

    goals = WeeklyGoal.objects.filter(
        user=user, week_start=week_start, is_active=True
    )
    tasks = Task.objects.filter(user=user, date__gte=week_start, date__lte=week_end)

    def goal_progress(goal):
        done = goal.tasks.filter(status=Task.Status.DONE)
        if goal.metric == WeeklyGoal.Metric.DURATION:
            value = sum((t.duration_minutes or 0) for t in done)
        else:
            value = done.count()
        return value

    return {
        'today': today.isoformat(),
        'week_start': week_start.isoformat(),
        'week_end': week_end.isoformat(),
        'goals': [
            {
                'id': g.id,
                'title': g.plain_title(),
                'metric': g.metric,
                'target': g.target,
                'unit': g.unit or '',
                'done': goal_progress(g),
            }
            for g in goals
        ],
        'tasks': [
            {
                'id': t.id,
                'title': t.plain_title(),
                'date': t.date.isoformat(),
                'kind': t.kind,
                'start_time': t.start_time.strftime('%H:%M') if t.start_time else None,
                'end_time': t.end_time.strftime('%H:%M') if t.end_time else None,
                'priority': t.priority,
                'status': t.status,
                'goal_id': t.goal_id,
            }
            for t in tasks
        ],
    }


def _ask(messages):
    client = _client()
    resp = client.chat.completions.create(
        model=_model(),
        messages=messages,
        response_format={'type': 'json_object'},
        temperature=0.4,
    )
    content = resp.choices[0].message.content
    return json.loads(content)


def _ask_text(messages, temperature=0.3):
    client = _client()
    resp = client.chat.completions.create(
        model=_model(),
        messages=messages,
        temperature=temperature,
    )
    return resp.choices[0].message.content or ''


def generate_proposal(user, kind, goal=None, day=None):
    ctx = build_context(user, day)
    messages = [
        {'role': 'system', 'content': SYSTEM_PROMPT},
        {'role': 'user', 'content': json.dumps(ctx, ensure_ascii=False)},
    ]

    if kind == 'goal_breakdown' and goal is not None:
        messages.append(
            {
                'role': 'user',
                'content': (
                    f"Su haftalik hedefi gunluk gorevlere bol: '{goal.plain_title()}' "
                    f"(hedef: {goal.target}, metrik: {goal.metric}). "
                    f"Hafta {ctx['week_start']} ile {ctx['week_end']} arasinda. "
                    f"Bu hedef icin goal_id={goal.id} kullan. Gunlere dengeli dagit."
                ),
            }
        )
    elif kind == 'daily_review':
        messages.append(
            {
                'role': 'user',
                'content': (
                    f"Gun sonu degerlendirmesi yap ({ctx['today']}). Tamamlanan ve "
                    "tamamlanmayan gorevleri degerlendir. Haftalik hedeflere ulasmak icin "
                    "gelecek gunlerde yapilacak duzeltme onerileri uret. Geciken onemli "
                    "gorevleri uygun gunlere tasi."
                ),
            }
        )
    else:
        messages.append(
            {
                'role': 'user',
                'content': (
                    f"Plani yeniden duzenle ({ctx['today']}). Mevcut gorevleri ve haftalik "
                    "hedef ilerlemesini dikkate al. Gereksiz gorevleri kaldirmayi, cakisan "
                    "bloklari duzeltmeyi ve hedeflere yetisecek sekilde ekleme yapmayi Oner."
                ),
            }
        )

    data = _ask(messages)
    if 'changes' not in data:
        data = {'summary': data.get('summary', ''), 'changes': []}
    return data


# ---- payload uygulama ----

_CREATE_FIELDS = {
    'title', 'date', 'kind', 'start_time', 'end_time',
    'duration_minutes', 'priority', 'notes', 'goal_id',
}
_UPDATE_FIELDS = {
    'date', 'start_time', 'end_time', 'priority', 'status',
    'title', 'notes', 'kind', 'duration_minutes',
}


def _parse_time(value):
    if not value:
        return None
    if isinstance(value, time):
        return value
    return time.fromisoformat(str(value))


def _parse_date(value):
    if not value:
        return None
    if isinstance(value, date_cls):
        return value
    return date_cls.fromisoformat(str(value))


def _clean_create(ch, user):
    out = {}
    if ch.get('title'):
        out['title'] = str(ch['title'])[:200]
    if ch.get('date'):
        out['date'] = _parse_date(ch['date'])
    out['kind'] = ch.get('kind') if ch.get('kind') in ('block', 'list') else 'list'
    out['start_time'] = _parse_time(ch.get('start_time'))
    out['end_time'] = _parse_time(ch.get('end_time'))
    if isinstance(ch.get('duration_minutes'), int):
        out['duration_minutes'] = ch['duration_minutes']
    if ch.get('priority') in ('low', 'medium', 'high'):
        out['priority'] = ch['priority']
    out['notes'] = str(ch.get('notes', '') or '')
    gid = ch.get('goal_id')
    if gid and WeeklyGoal.objects.filter(id=gid, user=user).exists():
        out['goal_id'] = gid
    return out


def _clean_update(ch):
    out = {}
    if ch.get('date'):
        out['date'] = _parse_date(ch['date'])
    if 'start_time' in ch:
        out['start_time'] = _parse_time(ch.get('start_time'))
    if 'end_time' in ch:
        out['end_time'] = _parse_time(ch.get('end_time'))
    if ch.get('priority') in ('low', 'medium', 'high'):
        out['priority'] = ch['priority']
    if ch.get('status') in ('todo', 'done', 'skipped'):
        out['status'] = ch['status']
        out['completed_at'] = timezone.now() if ch['status'] == 'done' else None
    if ch.get('title'):
        out['title'] = str(ch['title'])[:200]
    if ch.get('kind') in ('block', 'list'):
        out['kind'] = ch['kind']
    if isinstance(ch.get('duration_minutes'), int):
        out['duration_minutes'] = ch['duration_minutes']
    if 'notes' in ch:
        out['notes'] = str(ch.get('notes', '') or '')
    return out


def _clean_goal(ch, user):
    out = {}
    if ch.get('title'):
        out['title'] = str(ch['title'])[:200]
    if ch.get('metric') in ('count', 'duration'):
        out['metric'] = ch['metric']
    if isinstance(ch.get('target'), int) and ch['target'] > 0:
        out['target'] = ch['target']
    if ch.get('unit'):
        out['unit'] = str(ch['unit'])[:30]
    ws = _parse_date(ch.get('week_start'))
    if ws is None:
        today = timezone.localdate()
        ws = today - timedelta(days=today.weekday())
    out['week_start'] = ws
    return out


@transaction.atomic
def apply_proposal(proposal):
    payload = proposal.plain_payload() or {}
    applied = 0
    created_goals = []
    for ch in payload.get('changes', []):
        action = ch.get('action')
        if action == 'create_goal':
            fields = _clean_goal(ch, proposal.user)
            if fields.get('title'):
                goal = WeeklyGoal.objects.create(user=proposal.user, **fields)
                created_goals.append(goal)
                if proposal.goal is None:
                    proposal.goal = goal
                    proposal.save(update_fields=['goal'])
                applied += 1
        elif action == 'create':
            fields = _clean_create(ch, proposal.user)
            if fields.get('title') and fields.get('date'):
                ref = ch.get('goal_ref')
                if 'goal_id' not in fields and isinstance(ref, int) and 0 <= ref < len(created_goals):
                    fields['goal_id'] = created_goals[ref].id
                Task.objects.create(user=proposal.user, **fields)
                applied += 1
        elif action == 'update':
            task = Task.objects.filter(
                id=ch.get('task_id'), user=proposal.user
            ).first()
            if task:
                for field, value in _clean_update(ch).items():
                    setattr(task, field, value)
                task.save()
                applied += 1
        elif action == 'delete':
            deleted, _ = Task.objects.filter(
                id=ch.get('task_id'), user=proposal.user
            ).delete()
            applied += deleted
    return applied


# ---- sohbet ----

_HISTORY_LIMIT = 10


def _summary_messages(session, older):
    msgs = [
        {
            'role': 'system',
            'content': (
                'Kullaniciyla yapilan haftalik planlama sohbetinin kisa bir ozetini yaz. '
                'Hedefler, gorevler, secilen gunler/saatler ve hala netlesmemis konular '
                'yer alsin. Turkce, maddeler halinde, en fazla 250 kelime.'
            ),
        }
    ]
    prev = session.plain_summary()
    if prev:
        msgs.append({'role': 'user', 'content': f'Onceki ozet:\n{prev}'})
    for m in older:
        msgs.append(
            {
                'role': m.role,
                'content': m.plain_content(),
            }
        )
    return msgs


def _refresh_summary(session, msgs):
    older = msgs[:-_HISTORY_LIMIT]
    if not older:
        return session.plain_summary()
    if not session.plain_summary() and len(older) > _HISTORY_LIMIT:
        older = older[-_HISTORY_LIMIT * 2:]
    summary = _ask_text(_summary_messages(session, older))
    session.summary = summary
    session.save(update_fields=['summary'])
    return summary


def chat_turn(user, message, session=None):
    if session is None:
        session = ChatSession.objects.create(user=user)

    ChatMessage.objects.create(session=session, role=ChatMessage.Role.USER, content=message)
    session.updated_at = timezone.now()
    session.save(update_fields=['updated_at'])

    msgs = list(session.messages.order_by('created_at', 'id'))
    summary = ''
    if len(msgs) > _HISTORY_LIMIT:
        summary = _refresh_summary(session, msgs)

    ctx = build_context(user)
    system = CHAT_SYSTEM_PROMPT
    system += '\n\n--- HAFTALIK DURUM (mevcut veriler) ---\n' + json.dumps(ctx, ensure_ascii=False)
    if summary:
        system += '\n\n--- ONCEKI SOHBETIN OZETI ---\n' + summary

    history = msgs[-_HISTORY_LIMIT:]
    conv = [
        {'role': m.role, 'content': m.plain_content()}
        for m in history
    ]
    data = _ask([{'role': 'system', 'content': system}, *conv])

    reply = str(data.get('reply', '')).strip() or 'Anlasildi.'
    draft = data.get('draft') or None

    proposal = None
    changes = (draft or {}).get('changes', []) if draft else []
    if changes:
        proposal = AIProposal.objects.create(
            user=user,
            kind=AIProposal.Kind.CHAT,
            summary=reply,
            payload={'changes': changes},
        )

    ChatMessage.objects.create(
        session=session,
        role=ChatMessage.Role.ASSISTANT,
        content=reply,
        draft=draft or {},
        proposal=proposal,
    )

    out = {
        'session_id': session.id,
        'reply': reply,
        'draft': draft,
        'proposal_id': proposal.id if proposal else None,
    }
    if proposal is not None:
        out['proposal_status'] = proposal.status
        out['change_count'] = len(changes)
    return out
