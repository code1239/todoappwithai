from rest_framework import serializers

from .models import AIProposal, ChatMessage, ChatSession


class AIProposalSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIProposal
        fields = (
            'id', 'goal', 'kind', 'status', 'summary', 'payload',
            'error', 'created_at', 'decided_at',
        )
        read_only_fields = fields

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['summary'] = instance.plain_summary()
        data['payload'] = instance.plain_payload()
        return data


class ChatSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatSession
        fields = ('id', 'summary', 'created_at', 'updated_at')
        read_only_fields = fields


class ChatMessageSerializer(serializers.ModelSerializer):
    draft = serializers.SerializerMethodField()

    class Meta:
        model = ChatMessage
        fields = ('id', 'role', 'content', 'draft', 'proposal', 'created_at')
        read_only_fields = fields

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['content'] = instance.plain_content()
        return data

    def get_draft(self, instance):
        return instance.plain_draft()