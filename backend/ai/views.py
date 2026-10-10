from datetime import date as date_cls

from django.utils import timezone
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from planner.models import WeeklyGoal

from . import services
from .models import AIProposal, ChatMessage, ChatSession
from .serializers import (
    AIProposalSerializer,
    ChatMessageSerializer,
    ChatSessionSerializer,
)


class ProposalViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = AIProposalSerializer

    def get_queryset(self):
        qs = AIProposal.objects.filter(user=self.request.user)
        status_param = self.request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)
        return qs

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        proposal = self.get_object()
        if proposal.status != AIProposal.Status.PENDING:
            return Response(
                {'detail': 'Bu oneri zaten sonuclandirilmis.'}, status=400
            )
        applied = services.apply_proposal(proposal)
        proposal.status = AIProposal.Status.APPROVED
        proposal.decided_at = timezone.now()
        proposal.save(update_fields=['status', 'decided_at'])
        data = self.get_serializer(proposal).data
        data['applied'] = applied
        return Response(data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        proposal = self.get_object()
        if proposal.status != AIProposal.Status.PENDING:
            return Response(
                {'detail': 'Bu oneri zaten sonuclandirilmis.'}, status=400
            )
        proposal.status = AIProposal.Status.REJECTED
        proposal.decided_at = timezone.now()
        proposal.save(update_fields=['status', 'decided_at'])
        return Response(self.get_serializer(proposal).data)


def _create_proposal(user, kind, goal=None, day=None):
    try:
        data = services.generate_proposal(user, kind, goal=goal, day=day)
        proposal = AIProposal.objects.create(
            user=user,
            goal=goal,
            kind=kind,
            summary=data.get('summary', ''),
            payload={'changes': data.get('changes', [])},
        )
        return proposal, None
    except Exception as exc:  # noqa: BLE001
        proposal = AIProposal.objects.create(
            user=user,
            goal=goal,
            kind=kind,
            payload={'changes': []},
            error=str(exc),
        )
        return proposal, exc


def _parse_day(value):
    if not value:
        return None
    return date_cls.fromisoformat(str(value))


class ProposeView(APIView):
    def post(self, request):
        kind = request.data.get('kind', AIProposal.Kind.REVISE_PLAN)
        if kind not in dict(AIProposal.Kind.choices):
            return Response({'detail': 'Gecersiz kind.'}, status=400)

        goal = None
        goal_id = request.data.get('goal_id')
        if goal_id:
            goal = WeeklyGoal.objects.filter(id=goal_id, user=request.user).first()
            if not goal:
                return Response({'detail': 'Hedef bulunamadi.'}, status=404)
        if kind == AIProposal.Kind.GOAL_BREAKDOWN and not goal:
            return Response(
                {'detail': 'goal_breakdown icin goal_id gerekli.'}, status=400
            )

        day = _parse_day(request.data.get('date')) or timezone.localdate()
        proposal, err = _create_proposal(request.user, kind, goal=goal, day=day)
        ser = AIProposalSerializer(proposal)
        if err:
            return Response(ser.data, status=502)
        return Response(ser.data, status=201)


class DailyReviewView(APIView):
    def post(self, request):
        day = _parse_day(request.data.get('date'))
        proposal, err = _create_proposal(
            request.user, AIProposal.Kind.DAILY_REVIEW, day=day
        )
        ser = AIProposalSerializer(proposal)
        if err:
            return Response(ser.data, status=502)
        return Response(ser.data, status=201)


class ChatView(APIView):
    def post(self, request):
        message = str(request.data.get('message', '')).strip()
        if not message:
            return Response({'detail': 'message alani bos olamaz.'}, status=400)

        session = None
        session_id = request.data.get('session_id')
        if session_id:
            session = ChatSession.objects.filter(
                id=session_id, user=request.user
            ).first()
            if not session:
                return Response({'detail': 'Sohbet bulunamadi.'}, status=404)

        try:
            result = services.chat_turn(request.user, message, session=session)
        except Exception as exc:  # noqa: BLE001
            return Response({'detail': f'AI cagrisi basarisiz: {exc}'}, status=502)
        return Response(result, status=201)

    def get(self, request):
        session_id = request.query_params.get('session_id')
        if session_id:
            session = ChatSession.objects.filter(
                id=session_id, user=request.user
            ).first()
        else:
            session = ChatSession.objects.filter(user=request.user).first()
        if not session:
            return Response({'session_id': None, 'messages': []})
        return Response(
            {
                'session_id': session.id,
                'messages': ChatMessageSerializer(
                    session.messages.all(), many=True
                ).data,
            }
        )


class ChatSessionsView(APIView):
    def get(self, request):
        sessions = ChatSession.objects.filter(user=request.user)
        data = []
        for s in sessions:
            last = s.messages.last()
            data.append(
                {
                    'id': s.id,
                    'updated_at': s.updated_at,
                    'created_at': s.created_at,
                    'preview': last.plain_content() if last else '',
                }
            )
        return Response({'sessions': data})
