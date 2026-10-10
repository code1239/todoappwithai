from django.conf import settings
from django.db import models

from config.encryption import enc, enc_json, dec, dec_json


class AIProposal(models.Model):
    """Yapay zekanin onerdigi plan degisiklikleri (kullanici onayina sunulur)."""

    class Kind(models.TextChoices):
        GOAL_BREAKDOWN = 'goal_breakdown', 'Haftalik hedef -> gunluk gorevler'
        REVISE_PLAN = 'revise_plan', 'Plani yeniden duzenle (manuel)'
        DAILY_REVIEW = 'daily_review', 'Gun sonu degerlendirme'
        CHAT = 'chat', 'Sohbet plani'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Bekliyor'
        APPROVED = 'approved', 'Onaylandi'
        REJECTED = 'rejected', 'Reddedildi'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ai_proposals'
    )
    goal = models.ForeignKey(
        'planner.WeeklyGoal',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='ai_proposals',
    )
    kind = models.CharField(max_length=20, choices=Kind.choices)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    summary = models.TextField(blank=True)
    payload = models.TextField(blank=True)
    error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    decided_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        self.summary = enc(self.summary)
        self.payload = enc_json(self.payload)
        super().save(*args, **kwargs)

    def plain_summary(self):
        return dec(self.summary)

    def plain_payload(self):
        return dec_json(self.payload)

    def __str__(self):
        return f'[{self.kind}] {self.get_status_display()} - {self.user}'


class ChatSession(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='chat_sessions'
    )
    summary = models.TextField(blank=True, help_text='10 mesajdan oncekilerin AI ozeti')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def save(self, *args, **kwargs):
        self.summary = enc(self.summary)
        super().save(*args, **kwargs)

    def plain_summary(self):
        return dec(self.summary)


class ChatMessage(models.Model):
    class Role(models.TextChoices):
        USER = 'user', 'Kullanici'
        ASSISTANT = 'assistant', 'Asistan'

    session = models.ForeignKey(
        ChatSession, on_delete=models.CASCADE, related_name='messages'
    )
    role = models.CharField(max_length=10, choices=Role.choices)
    content = models.TextField()
    draft = models.TextField(blank=True, help_text='Assistant mesajindaki plan taslagi')
    proposal = models.ForeignKey(
        AIProposal,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='chat_messages',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at', 'id']

    def save(self, *args, **kwargs):
        self.content = enc(self.content)
        self.draft = enc_json(self.draft)
        super().save(*args, **kwargs)

    def plain_content(self):
        return dec(self.content)

    def plain_draft(self):
        return dec_json(self.draft)

    def __str__(self):
        return f'[{self.role}] {self.plain_content()}'