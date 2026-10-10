from django.conf import settings
from django.db import models

from config.encryption import dec, enc


class EncryptedTextMixin:
    """save() sirasinda duyarli alanlari sifreler, plain_*() ile cozer."""

    encrypted_fields = ()

    def save(self, *args, **kwargs):
        for field in self.encrypted_fields:
            setattr(self, field, enc(getattr(self, field)))
        super().save(*args, **kwargs)

    def plain(self, field):
        return dec(getattr(self, field))


class WeeklyGoal(EncryptedTextMixin, models.Model):
    encrypted_fields = ('title', 'description')

    class Metric(models.TextChoices):
        COUNT = 'count', 'Adet (kac kez)'
        DURATION = 'duration', 'Sure (dakika)'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='weekly_goals'
    )
    title = models.CharField(max_length=400)
    description = models.TextField(blank=True)
    metric = models.CharField(max_length=10, choices=Metric.choices, default=Metric.COUNT)
    target = models.PositiveIntegerField(default=1)
    unit = models.CharField(max_length=30, blank=True, help_text='Serbest birim (sayfa, kez, dk...)')
    week_start = models.DateField(help_text='Haftanin baslangici (Pazartesi)')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-week_start', 'title']

    def plain_title(self):
        return self.plain('title')

    def plain_description(self):
        return self.plain('description')

    def __str__(self):
        return f'{self.plain_title()} ({self.target} {self.get_metric_display()})'


class Task(EncryptedTextMixin, models.Model):
    encrypted_fields = ('title', 'notes')

    class Kind(models.TextChoices):
        BLOCK = 'block', 'Saatli blok'
        LIST = 'list', 'Serbest liste'

    class Status(models.TextChoices):
        TODO = 'todo', 'Yapilacak'
        DONE = 'done', 'Tamamlandi'
        SKIPPED = 'skipped', 'Atlandi'

    class Priority(models.TextChoices):
        LOW = 'low', 'Dusuk'
        MEDIUM = 'medium', 'Orta'
        HIGH = 'high', 'Yuksek'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='tasks'
    )
    goal = models.ForeignKey(
        WeeklyGoal, on_delete=models.SET_NULL, null=True, blank=True, related_name='tasks'
    )
    title = models.CharField(max_length=400)
    notes = models.TextField(blank=True)
    date = models.DateField()
    kind = models.CharField(max_length=10, choices=Kind.choices, default=Kind.LIST)
    start_time = models.TimeField(null=True, blank=True)
    end_time = models.TimeField(null=True, blank=True)
    duration_minutes = models.PositiveIntegerField(null=True, blank=True)
    priority = models.CharField(
        max_length=10, choices=Priority.choices, default=Priority.MEDIUM
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.TODO)
    order = models.IntegerField(default=0)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['date', 'order', 'start_time']

    def plain_title(self):
        return self.plain('title')

    def plain_notes(self):
        return self.plain('notes')

    def __str__(self):
        return f'{self.date} - {self.plain_title()}'
