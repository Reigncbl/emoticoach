import os
import re
import yaml
from datetime import datetime
from llama_index.llms.groq import Groq
from llama_index.core.llms import ChatMessage, MessageRole

from dotenv import load_dotenv

load_dotenv()
model = os.getenv('model')
api_key = os.getenv('api_key')
llm = Groq(model=model, api_key=api_key)

# Get config file path
script_dir = os.path.dirname(os.path.abspath(__file__))
templates_dir = os.path.join(os.path.dirname(script_dir), "Templates")
config_path = os.path.join(templates_dir, "teacher_config.yaml")

# Load roleplay config
try:
    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)
except FileNotFoundError:
    print(f"Error: Could not find teacher_config.yaml at {config_path}")
    exit(1)

roleplay_prompt = config["roleplay"]["description"]
first_message = config["roleplay"]["first_message"]

# System instruction (character role)
messages = [
    ChatMessage(role=MessageRole.SYSTEM, content=roleplay_prompt)
]

# First assistant message
messages.append(ChatMessage(role=MessageRole.ASSISTANT, content=first_message))
print(f"{config['roleplay']['name']}:", first_message)

while True:
    user_input = input("You: ")
    if user_input.lower() in ["exit", "quit"]:
        print("\nEvaluating conversation...")

        # Prompt for minimal score + tip
        eval_prompt = (
            "Evaluate the user's replies on these four parameters:\n"
            "Clarity, Empathy, Assertiveness, Appropriateness.\n"
            "Give each parameter a score from 1 to 10.\n"
            "Then provide ONE short tip for improvement.\n"
            "Return the result in valid YAML format:\n"
            "evaluation:\n"
            "  clarity: [1-10]\n"
            "  empathy: [1-10]\n"
            "  assertiveness: [1-10]\n"
            "  appropriateness: [1-10]\n"
            "  tip: '[short tip for improvement]'\n\n"
            "Conversation to evaluate:\n"
        )

        for msg in messages[1:]:
            if msg.role == MessageRole.USER:
                eval_prompt += f"User: {msg.content}\n"
            elif msg.role == MessageRole.ASSISTANT:
                eval_prompt += f"{config['roleplay']['name']}: {msg.content}\n"

        eval_messages = [
            ChatMessage(role=MessageRole.SYSTEM, content="You are an impartial conversation evaluator."),
            ChatMessage(role=MessageRole.USER, content=eval_prompt)
        ]

        evaluation_response = llm.chat(eval_messages)
        evaluation_content = re.sub(r"<think>.*?</think>", "", evaluation_response.message.content, flags=re.DOTALL).strip()

        try:
            eval_data = yaml.safe_load(evaluation_content)

            eval_filename = f"evaluation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.yaml"
            eval_path = os.path.join(templates_dir, eval_filename)
            with open(eval_path, "w", encoding="utf-8") as f:
                yaml.dump(eval_data, f, allow_unicode=True)

            print("\n=== Conversation Evaluation ===")
            if 'evaluation' in eval_data:
                for param in ["clarity", "empathy", "assertiveness", "appropriateness"]:
                    if param in eval_data['evaluation']:
                        print(f"{param.capitalize()}: {eval_data['evaluation'][param]}/10")
                if 'tip' in eval_data['evaluation']:
                    print(f"\nTip: {eval_data['evaluation']['tip']}")
            else:
                print(evaluation_content)

        except yaml.YAMLError:
            print("⚠️ Could not parse evaluation YAML.")
            print(evaluation_content)

        print("\nEnding conversation...")
        break

    messages.append(ChatMessage(role=MessageRole.USER, content=user_input))
    response = llm.chat(messages)
    content = re.sub(r"<think>.*?</think>", "", response.message.content, flags=re.DOTALL).strip()
    messages.append(ChatMessage(role=MessageRole.ASSISTANT, content=content))
    print(f"{config['roleplay']['name']}:", content)
