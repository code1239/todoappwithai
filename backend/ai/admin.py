from django.contrib import admin

from .models import AIProposal, ChatMessage, ChatSession


@admin.register(AIProposal)
class AIProposalAdmin(admin.ModelAdmin):
    list_display = ('id', 'kind', 'user', 'status', 'created_at', 'decided_at')
    list_filter = ('kind', 'status', 'user')
    search_fields = ('summary',)
    readonly_fields = (
        'summary_plain', 'payload_plain', 'error', 'created_at', 'decided_at'
    )

    @admin.display(description='Ozet (cozulmus)')
    def summary_plain(self, obj):
        return obj.plain_summary()

    @admin.display(description='Payload (cozulmus)')
    def payload_plain(self, obj):
        import json

        return json.dumps(obj.plain_payload(), ensure_ascii=False, indent=2)


class ChatMessageInline(admin.TabularInline):
    model = ChatMessage
    extra = 0
    readonly_fields = ('content_plain', 'draft_plain', 'role', 'created_at')

    @admin.display(description='Icerik (cozulmus)')
    def content_plain(self, obj):
        return obj.plain_content()

    @admin.display(description='Taslak (cozulmus)')
    def draft_plain(self, obj):
        import json

        return json.dumps(obj.plain_draft(), ensure_ascii=False)


@admin.register(ChatSession)
class ChatSessionAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'updated_at', 'created_at')
    list_filter = ('user',)
    readonly_fields = ('summary_plain',)
    inlines = (ChatMessageInline,)

    @admin.display(description='Ozet (cozulmus)')
    def summary_plain(self, obj):
        return obj.plain_summary()


@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ('id', 'session', 'role', 'created_at')
    list_filter = ('role', 'session__user')
    readonly_fields = ('content_plain', 'draft_plain', 'created_at')

    @admin.display(description='Icerik (cozulmus)')
    def content_plain(self, obj):
        return obj.plain_content()

    @admin.display(description='Taslak (cozulmus)')
    def draft_plain(self, obj):
        import json

        return json.dumps(obj.plain_draft(), ensure_ascii=False)