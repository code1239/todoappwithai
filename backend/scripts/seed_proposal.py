import os
import sys

import django

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User  # noqa: E402
from django.utils import timezone  # noqa: E402

from ai.models import AIProposal  # noqa: E402

user = User.objects.get(username='testuser')
today = timezone.localdate().isoformat()

proposal = AIProposal.objects.create(
    user=user,
    kind=AIProposal.Kind.REVISE_PLAN,
    summary='Test: aksam yuruyusu ekle, market gorevini yuksek oncelik yap.',
    payload={
        'changes': [
            {
                'action': 'create',
                'title': 'Aksam yuruyusu',
                'date': today,
                'kind': 'block',
                'start_time': '19:00',
                'end_time': '19:30',
                'priority': 'medium',
                'goal_id': 1,
            },
            {'action': 'update', 'task_id': 2, 'priority': 'high'},
        ]
    },
)
print(f'proposal_id={proposal.id}')
