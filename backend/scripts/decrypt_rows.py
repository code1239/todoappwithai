"""Verileri cozulmus haliyle terminalde gosterir (inceleme amaciyla).

Calistirma (proje kokunden):
    .venv\\Scripts\\python.exe backend\\scripts\\decrypt_rows.py [username]
"""

import os
import sys
from pathlib import Path

import django

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from datetime import timedelta  # noqa: E402

from django.utils import timezone  # noqa: E402
from planner.models import Task, WeeklyGoal  # noqa: E402
from ai.models import AIProposal, ChatMessage, ChatSession  # noqa: E402


def main():
    uname = sys.argv[1] if len(sys.argv) > 1 else None
    from django.contrib.auth import get_user_model

    users = get_user_model().objects.all()
    if uname:
        users = users.filter(username=uname)

    today = timezone.localdate()
    week_start = today - timedelta(days=today.weekday())

    for u in users:
        print(f'\n===== {u.username} =====')
        print('\n-- Hedefler:', week_start, '--')
        for g in WeeklyGoal.objects.filter(user=u, week_start=week_start):
            print(f'  #{g.id} {g.plain_title()} | {g.target} {g.unit or g.metric}')

        print('\n-- Gorevler --')
        for t in Task.objects.filter(user=u).order_by('date'):
            print(
                f'  #{t.id} {t.date} {t.kind:5s} {t.start_time or "":6s} '
                f'[{t.status}] {t.plain_title()} | {t.plain_notes()}'
            )

        print('\n-- AI Onerileri (son 10) --')
        for p in AIProposal.objects.filter(user=u)[:10]:
            print(f'  #{p.id} {p.kind:15s} {p.status:9s} {p.plain_summary()}')

        print('\n-- Sohbetler --')
        for s in ChatSession.objects.filter(user=u)[:5]:
            print(f'  oturum #{s.id} ozet: {s.plain_summary()[:120]}')
            for m in s.messages.all()[:20]:
                print(f'      [{m.role}] {m.plain_content()[:150]}')

    print('\nTamam.')


if __name__ == '__main__':
    main()
