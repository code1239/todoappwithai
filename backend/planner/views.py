from datetime import date as date_cls
from datetime import timedelta

from django.utils import timezone
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Task, WeeklyGoal
from .serializers import TaskSerializer, WeeklyGoalSerializer


class OwnedMixin:
    def get_queryset(self):
        return super().get_queryset().filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class WeeklyGoalViewSet(OwnedMixin, viewsets.ModelViewSet):
    serializer_class = WeeklyGoalSerializer
    queryset = WeeklyGoal.objects.all()

    def get_queryset(self):
        qs = super().get_queryset()
        week = self.request.query_params.get('week_start')
        if week:
            qs = qs.filter(week_start=week)
        return qs


class TaskViewSet(OwnedMixin, viewsets.ModelViewSet):
    serializer_class = TaskSerializer
    queryset = Task.objects.all()

    def get_queryset(self):
        qs = super().get_queryset()
        params = self.request.query_params
        if params.get('date'):
            qs = qs.filter(date=params['date'])
        if params.get('start'):
            qs = qs.filter(date__gte=params['start'])
        if params.get('end'):
            qs = qs.filter(date__lte=params['end'])
        if params.get('kind'):
            qs = qs.filter(kind=params['kind'])
        if params.get('goal'):
            qs = qs.filter(goal_id=params['goal'])
        return qs

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        task = self.get_object()
        if task.status == Task.Status.DONE:
            task.status = Task.Status.TODO
            task.completed_at = None
        else:
            task.status = Task.Status.DONE
            task.completed_at = timezone.now()
        task.save()
        return Response(self.get_serializer(task).data)


class DashboardView(APIView):
    def get(self, request):
        day = request.query_params.get('date')
        today = timezone.localdate()
        if day:
            today = date_cls.fromisoformat(day)

        tasks = Task.objects.filter(user=request.user, date=today)
        week_start = today - timedelta(days=today.weekday())
        goals = WeeklyGoal.objects.filter(
            user=request.user, week_start=week_start, is_active=True
        )
        return Response(
            {
                'date': today,
                'week_start': week_start,
                'blocks': TaskSerializer(
                    tasks.filter(kind=Task.Kind.BLOCK), many=True
                ).data,
                'list': TaskSerializer(
                    tasks.filter(kind=Task.Kind.LIST), many=True
                ).data,
                'goals': WeeklyGoalSerializer(goals, many=True).data,
            }
        )


class WeekPlanView(APIView):
    def get(self, request):
        day = request.query_params.get('date')
        today = timezone.localdate()
        if day:
            today = date_cls.fromisoformat(day)

        week_start = today - timedelta(days=today.weekday())
        days = []
        for offset in range(7):
            d = week_start + timedelta(days=offset)
            tasks = Task.objects.filter(user=request.user, date=d)
            days.append(
                {
                    'date': d,
                    'weekday': d.weekday(),
                    'blocks': TaskSerializer(
                        tasks.filter(kind=Task.Kind.BLOCK), many=True
                    ).data,
                    'list': TaskSerializer(
                        tasks.filter(kind=Task.Kind.LIST), many=True
                    ).data,
                }
            )
        return Response({'week_start': week_start, 'days': days})
