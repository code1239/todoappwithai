from rest_framework import serializers

from .models import Task, WeeklyGoal


class TaskSerializer(serializers.ModelSerializer):
    goal_title = serializers.CharField(source='goal.title', read_only=True)

    class Meta:
        model = Task
        fields = (
            'id', 'title', 'notes', 'date', 'kind', 'start_time', 'end_time',
            'duration_minutes', 'priority', 'status', 'order', 'goal', 'goal_title',
            'completed_at', 'created_at', 'updated_at',
        )
        read_only_fields = ('completed_at', 'created_at', 'updated_at')

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['title'] = instance.plain_title()
        data['notes'] = instance.plain_notes()
        data['goal_title'] = (
            instance.goal.plain_title() if instance.goal_id else None
        )
        return data


class WeeklyGoalSerializer(serializers.ModelSerializer):
    progress = serializers.SerializerMethodField()

    class Meta:
        model = WeeklyGoal
        fields = (
            'id', 'title', 'description', 'metric', 'target', 'unit', 'week_start',
            'is_active', 'progress', 'created_at',
        )
        read_only_fields = ('created_at',)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['title'] = instance.plain_title()
        data['description'] = instance.plain_description()
        if data.get('unit') == '':
            data['unit'] = None
        return data

    def get_progress(self, obj):
        done_tasks = obj.tasks.filter(status=Task.Status.DONE)
        if obj.metric == WeeklyGoal.Metric.DURATION:
            done = sum((t.duration_minutes or 0) for t in done_tasks)
        else:
            done = done_tasks.count()
        return {'done': done, 'target': obj.target}