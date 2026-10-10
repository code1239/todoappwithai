"""Mevcut verileri alan bazli sifreye cevirir.

Calistirma (proje kokunden):
    .venv\\Scripts\\python.exe backend\\scripts\\encrypt_existing.py
"""

import os
import sys
from pathlib import Path

import django

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from config.encryption import is_encrypted  # noqa: E402
from planner.models import Task, WeeklyGoal  # noqa: E402
from ai.models import AIProposal, ChatMessage, ChatSession  # noqa: E402


def _counts():
    return (
        Task.objects.count(),
        WeeklyGoal.objects.count(),
        AIProposal.objects.count(),
        ChatSession.objects.count(),
        ChatMessage.objects.count(),
    )


before = _counts()
saved = 0
for model in (Task, WeeklyGoal, ChatSession, ChatMessage, AIProposal):
    for obj in model.objects.all():
        obj.save()
        saved += 1

after = _counts()
print(f'Islendi: {saved} kayit | once {before} -> sonra {after}')

unencrypted = (
    Task.objects.exclude(title__startswith='enc:').count()
    + WeeklyGoal.objects.exclude(title__startswith='enc:').count()
    + AIProposal.objects.exclude(summary__startswith='enc:').count()
)
print(f'Henuz sifrelenmemis kayit sayisi: {unencrypted}')
print('Tamam.')
