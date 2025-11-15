# Emoticoach System Class Diagram

This document provides a high-level class diagram for the Emoticoach system, split into Frontend (Flutter) and Backend (Python) components.

> Note: The diagram reflects the classes and relationships present in the provided code context. Some implementation details and auxiliary classes are omitted for clarity.

## Frontend (Flutter)

```mermaid
classDiagram
    direction TB

    class OverlayScreen {
      +bool messagingOverlayEnabled
      +bool messageAnalysisEnabled
      +bool smartSuggestionsEnabled
      +bool toneAdjusterEnabled
      +int _ragContextLimit
      +initState()
      +_loadSavedSettings()
      +_checkPermissions()
      +_saveSettings()
      +_initializeStatistics()
    }

    class ContactsListView {
      -TelegramService _telegramService
      +initState()
      +_loadContacts()
      +_loadTelegramContacts()
      +_handleContactTap(contact)
      +onContactSelected(contact) callback
    }

    class AnalysisView {
      -RagService _ragService
      -TelegramService _telegramService
      -bool _messageAnalysisEnabled
      -bool _smartSuggestionsEnabled
      -bool _toneAdjusterEnabled
      -String _latestMessage
      -Map _latestMessageDetails
      +initState()
      +_fetchMessages()
      +_analyzeEmotion(text)
      +_getToneForContact(contact)
      +_getInterpretationForContact(contact)
      +_getSuggestedResponseForContact(contact)
    }

    class EditOverlayScreen {
      -TelegramService _telegramService
      -RagService _ragService
      -TextEditingController _responseController
      -TextEditingController _shortenController
      +initState()
      +_fetchLatestMessage()
      +_generateResponse(instruction, showFeedback)
      +_applyToneToResponse(tone)
    }

    class TelegramService {
      +getMe(userId)
      +getContacts(userId)
      +getContactMessages(userId, contactId)
      +getLatestContactMessage(userId, contactId)
      +appendLatestContactMessage(userId, contactId)
    }

    class RagService {
      +getRecentEmotionContext(userId, contactId, limit)
      +generateContextualReply(userId, contactId, query, desiredTone)
    }

    class ManualAnalysisService { +analyzeMessage(userId, message) }
    class OverlayStatsService
    class OverlayStatsTracker {
      +initialize()
      +addListener(listener)
      +removeListener(listener)
      +getStatistics(period)
      +getDailyUsagePoints(period)
      +trackMessageAnalyzed(messageContent, analysisType)
    }

    class AuthUtils { +getSafeUserId() }

    OverlayScreen --> OverlayStatsTracker : listens
    OverlayScreen --> SharedPreferences : persists settings
    OverlayScreen ..> OverlayStatistics : displays

    ContactsListView --> TelegramService : uses
    ContactsListView ..> AuthUtils : resolves userId

    AnalysisView --> TelegramService : fetches messages
    AnalysisView --> RagService : emotion context
    AnalysisView ..> SharedPreferences : reads toggles
    AnalysisView ..> AuthUtils : resolves userId
    AnalysisView ..> OverlayStatsTracker : logs analysis

    EditOverlayScreen --> TelegramService : latest message
    EditOverlayScreen --> RagService : generates reply
    EditOverlayScreen ..> AuthUtils : resolves userId
```

## Backend (Python)

```mermaid
classDiagram
    direction TB

    class SimpleRAG {
      -Groq client
      -InferenceClient hf_client
      -EmotionEmbedder emotion_embedder
      -documents : List
      +add_document(text, metadata)
      +search(query, top_k)
      +get_response_tone(query)
      +get_emotion_data(text)
      +generate_response(query, user_messages)
    }

    class EmotionEmbedder {
      +analyze_text_full(text, translate_if_needed)
      +get_embedding(text)
    }

    class rag_routes {
      <<FastAPI Router>>
      +rag_sender_context(user_id, contact_id, query, limit, start_time, end_time, desired_tone)
      +recent_emotion_context(user_id, contact_id, window_minutes)
      +manual_emotion_context(payload)
      +get_latest_message(user_id, contact_id)
    }

    class multiuser_routes {
      <<FastAPI Router>>
      +request_code(user_id, phone_number, data, db)
      +verify_code(user_id, code, data, db)
      +get_me(user_id, db)
      +get_contacts(user_id, db)
      +get_contact_messages_multiuser(user_id, contact_id, data, db)
      +get_contact_messages_embed(user_id, contact_id, data, db)
      +append_latest_contact_message_multiuser(data, db)
      +get_latest_contact_message(user_id, contact_id, db)
    }

    class messages_services {
      <<Service>>
      +get_client(user_id, db) : TelegramClient
      +save_messages_to_db(messages, user_id, embeddings, emotion_outputs)
      +get_conversation_context(sender, receiver, limit)
      +get_latest_message_from_db(user_id, contact_id, db)
      +append_latest_contact_message(user_id, contact_id, db)
      +get_contact_messages_by_id(user_id, contact_id, db)
      +get_messages_with_interpretations(user_id, limit)
    }

    class MessagesRepository {
      +get_contact_messages(user_id, contact_id)
      +get_latest_contact_message(user_id, contact_id)
      +append_latest_contact_message(user_id, contact_id)
    }

    SimpleRAG --> EmotionEmbedder : uses
    SimpleRAG ..> Groq : LLM completions
    SimpleRAG ..> InferenceClient : HF embeddings

    rag_routes ..> SimpleRAG : uses (rag)
    rag_routes ..> Message : reads (sqlmodel)
    rag_routes ..> messages_services : cache/user info

    multiuser_routes ..> messages_services : delegates
    multiuser_routes ..> TelegramClient : Telethon
    multiuser_routes ..> TelegramSession : uses DB session

    messages_services ..> SimpleRAG : embeddings+emotion
    messages_services ..> Message : persists (sqlmodel)
    messages_services ..> TelegramSession : session lookup
    messages_services ..> MessageCache : cache
```

## Notes

- Frontend relies on SharedPreferences for persisting overlay settings.
- Latest message retrieval prefers DB-backed content (via `getLatestContactMessage`) to reuse stored interpretation/emotion when available.
- Emotion-aware reply generation is centralized in the backend RAG pipeline; caps output length with `max_tokens=400`.

## Viewing

- In VS Code, open this file and use the built-in Markdown preview (or install a Mermaid preview extension) to render the diagrams.
- Path: `docs/architecture/class-diagram.md`.
