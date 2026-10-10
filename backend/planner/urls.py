from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import DashboardView, TaskViewSet, WeekPlanView, WeeklyGoalViewSet

router = DefaultRouter()
router.register('goals', WeeklyGoalViewSet, basename='goal')
router.register('tasks', TaskViewSet, basename='task')

urlpatterns = [
    path('dashboard/today', DashboardView.as_view(), name='dashboard-today'),
    path('week-plan', WeekPlanView.as_view(), name='week-plan'),
    path('', include(router.urls)),
]
