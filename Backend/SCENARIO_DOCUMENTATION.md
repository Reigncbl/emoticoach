# Scenario System Documentation

## 🎯 **What We've Built**

A complete emotional coaching scenario system that uses Supabase Storage for YAML configurations and a PostgreSQL database for metadata.

## 📁 **Available Scenarios**

### 1. **Handling Workplace Criticism** (Beginner)

- **Character**: Alex - Direct, blunt colleague
- **Learning Goal**: Respond constructively to criticism without getting defensive
- **Category**: Workplace
- **Duration**: 8 minutes, 8 turns

### 2. **Supporting a Stressed Friend** (Intermediate)

- **Character**: Sam - Overwhelmed friend needing support
- **Learning Goal**: Practice active listening and emotional support skills
- **Category**: Friendship
- **Duration**: 12 minutes, 10 turns

### 3. **Family Communication Challenge** (Advanced)

- **Character**: Jordan - Family member feeling misunderstood
- **Learning Goal**: Navigate family conflict with empathy while maintaining boundaries
- **Category**: Family
- **Duration**: 15 minutes, 12 turns

### 4. **Meeting a New Classmate** (Beginner) 🆕

- **Character**: Casey - Nervous new student wanting to fit in
- **Learning Goal**: Practice making friends and welcoming newcomers
- **Category**: Social
- **Duration**: 10 minutes, 8 turns

### 5. **Consoling a Friend in Need** (Intermediate) 🆕

- **Character**: Riley - Friend experiencing disappointment/loss
- **Learning Goal**: Provide emotional support and comfort during difficult times
- **Category**: Friendship
- **Duration**: 15 minutes, 10 turns

## 🛠 **API Endpoints**

### **Core Scenario Operations**

```
GET /scenarios/list
- Lists all available scenarios with basic info

GET /scenarios/details/{scenario_id}
- Gets detailed scenario information including character details

GET /scenarios/start/{scenario_id}
- Starts a conversation and returns opening message

POST /scenarios/chat
- Chat with AI character (requires scenario_id)

POST /scenarios/evaluate
- Evaluate conversation for communication skills
```

### **Scenario Management** 🆕

```
POST /scenarios/create
- Create new scenario with YAML configuration
- Body: {title, description, category, difficulty, config_file, yaml_content}

POST /scenarios/upload-yaml
- Upload YAML file to Supabase Storage
- File upload endpoint for .yaml/.yml files
```

## 💾 **Data Storage**

### **Database (PostgreSQL)**

- **Table**: `scenarios`
- **Fields**: id, title, description, category, difficulty, config_file, estimated_duration, max_turns, is_active

### **Supabase Storage**

- **Bucket**: `scenario-configs`
- **Files**: Character YAML configurations
- **Access**: S3-compatible API with your provided credentials

## 🎭 **YAML Configuration Structure**

Each scenario has a YAML file with this structure:

```yaml
roleplay:
  name: Character Name
  description: |
    Detailed character personality, communication style,
    scenario context, specific situations, and behavioral rules
  first_message: |
    Character's opening message to start the conversation
```

## 🚀 **Usage Examples**

### **List Scenarios**

```bash
GET /scenarios/list
Response: {"success": true, "scenarios": [...]}
```

### **Start Conversation**

```bash
GET /scenarios/start/1
Response: {
  "success": true,
  "scenario_id": 1,
  "scenario_title": "Handling Workplace Criticism",
  "character_name": "Alex",
  "first_message": "I've looked at your proposal and...",
  "conversation_started": true
}
```

### **Chat with Character**

```bash
POST /scenarios/chat
Body: {
  "message": "Thanks for the feedback, Alex...",
  "scenario_id": 1,
  "conversation_history": [...]
}
```

### **Create New Scenario**

```bash
POST /scenarios/create
Body: {
  "title": "Job Interview Practice",
  "description": "Practice interviewing skills...",
  "category": "professional",
  "difficulty": "intermediate",
  "config_file": "job_interview_config.yaml",
  "yaml_content": "roleplay:\n  name: Ms. Johnson\n..."
}
```

## 🔧 **Technical Features**

- ✅ **Cloud Storage**: YAML configs stored in Supabase Storage
- ✅ **Database Integration**: Metadata in PostgreSQL
- ✅ **Dynamic Loading**: Configs loaded on-demand from storage
- ✅ **File Upload**: API endpoints for adding new scenarios
- ✅ **Fallback Support**: Local file fallback if storage unavailable
- ✅ **S3 Compatibility**: Uses boto3 for reliable storage access

## 🌟 **Next Steps**

The system is ready for:

1. Frontend integration
2. User authentication
3. Progress tracking
4. Scenario analytics
5. Custom scenario creation by users

All scenario configurations are now stored in the cloud and can be easily managed through the API!
