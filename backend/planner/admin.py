from django.contrib import admin

from .models import Task, WeeklyGoal


@admin.register(WeeklyGoal)
class WeeklyGoalAdmin(admin.ModelAdmin):
    list_display = (
        'title_plain', 'user', 'metric', 'target', 'unit', 'week_start', 'is_active'
    )
    list_filter = ('metric', 'is_active', 'week_start', 'user')
    search_fields = ('title', 'description')
    date_hierarchy = 'week_start'
    readonly_fields = ('title_plain', 'description_plain')

    @admin.display(description='Baslik (cozulmus)')
    def title_plain(self, obj):
        return obj.plain_title()

    @admin.display(description='Aciklama (cozulmus)')
    def description_plain(self, obj):
        return obj.plain_description()


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = (
        'title_plain', 'user', 'date', 'kind', 'start_time', 'end_time',
        'priority', 'status', 'goal',
    )
    list_filter = ('kind', 'status', 'priority', 'date', 'user')
    search_fields = ('title', 'notes')
    date_hierarchy = 'date'
    list_editable = ('status', 'priority')
    readonly_fields = ('title_plain', 'notes_plain')

    @admin.display(description='Baslik (cozulmus)')
    def title_plain(self, obj):
        return obj.plain_title()

    @admin.display(description='Notlar (cozulmus)')
    def notes_plain(self, obj):
        return obj.plain_notes()