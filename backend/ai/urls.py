from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    ChatSessionsView,
    ChatView,
    DailyReviewView,
    ProposalViewSet,
    ProposeView,
)

router = DefaultRouter()
router.register('proposals', ProposalViewSet, basename='proposal')

urlpatterns = [
    path('propose', ProposeView.as_view(), name='ai-propose'),
    path('daily-review', DailyReviewView.as_view(), name='ai-daily-review'),
    path('chat', ChatView.as_view(), name='ai-chat'),
    path('chat/sessions', ChatSessionsView.as_view(), name='ai-chat-sessions'),
    path('', include(router.urls)),
]
