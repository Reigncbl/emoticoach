"""
Conversation Flow Tracker for Smart Chat Scenario Endings
"""
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from datetime import datetime
import re

class ConversationAnalysis(BaseModel):
    """Analysis of conversation flow to determine if it should end"""
    should_end: bool
    confidence: float  # 0.0 to 1.0
    reason: str
    suggested_ending_message: Optional[str] = None
    conversation_quality: Dict[str, float]  # metrics like engagement, resolution

class ConversationTracker:
    """Tracks conversation flow and determines optimal ending points"""
    
    def __init__(self):
        self.closure_indicators = [
            "thanks", "thank you", "goodbye", "bye", "see you", "take care",
            "that helps", "i understand now", "i feel better", "makes sense",
            "i'll try that", "i'll work on", "good advice", "helpful"
        ]
        
        self.resolution_patterns = [
            r"i (understand|get it|see|realize)",
            r"that (makes sense|helps|clarifies)",
            r"(good|great|helpful) (advice|tip|suggestion)",
            r"i'll (try|work on|practice|remember)",
            r"feel (better|more confident|clearer)"
        ]
        
        self.stagnation_patterns = [
            r"(i don't know|not sure|confused)",
            r"(still don't|still can't|still feel)",
            r"(repeat|same|again)"
        ]

    async def analyze_conversation_flow(
        self, 
        conversation_history: List[Dict[str, str]],
        scenario_config: Dict[str, Any]
    ) -> ConversationAnalysis:
        """
        Analyze conversation to determine if it should end naturally
        
        Args:
            conversation_history: List of messages with role and content
            scenario_config: Scenario configuration for context
            
        Returns:
            ConversationAnalysis with ending recommendation
        """
        user_messages = [msg['content'].lower() for msg in conversation_history if msg['role'] == 'user']
        ai_messages = [msg['content'].lower() for msg in conversation_history if msg['role'] == 'assistant']
        
        if len(user_messages) < 2:
            return ConversationAnalysis(
                should_end=False,
                confidence=0.0,
                reason="Conversation too short",
                conversation_quality={"engagement": 0.5}
            )
        
        # Check for natural closure indicators
        closure_score = self._check_closure_indicators(user_messages[-2:])
        
        # Check for problem resolution
        resolution_score = self._check_resolution_patterns(user_messages)
        
        # Check for conversation stagnation
        stagnation_score = self._check_stagnation(user_messages[-3:])
        
        # Check conversation length appropriateness
        length_score = self._evaluate_conversation_length(len(user_messages))
        
        # Calculate overall ending confidence
        should_end, confidence, reason = self._calculate_ending_decision(
            closure_score, resolution_score, stagnation_score, length_score
        )
        
        suggested_ending = self._generate_ending_message(
            reason, scenario_config.get('roleplay', {}).get('name', 'AI')
        ) if should_end else None
        
        return ConversationAnalysis(
            should_end=should_end,
            confidence=confidence,
            reason=reason,
            suggested_ending_message=suggested_ending,
            conversation_quality={
                "closure": closure_score,
                "resolution": resolution_score,
                "engagement": max(0.1, 1.0 - stagnation_score),
                "length_appropriateness": length_score
            }
        )

    def _check_closure_indicators(self, recent_messages: List[str]) -> float:
        """Check for natural conversation closure signals"""
        score = 0.0
        for message in recent_messages:
            for indicator in self.closure_indicators:
                if indicator in message:
                    score += 0.3
        return min(1.0, score)

    def _check_resolution_patterns(self, user_messages: List[str]) -> float:
        """Check if user shows signs of problem resolution"""
        score = 0.0
        recent_messages = user_messages[-3:] if len(user_messages) > 3 else user_messages
        
        for message in recent_messages:
            for pattern in self.resolution_patterns:
                if re.search(pattern, message):
                    score += 0.4
                    
        return min(1.0, score)

    def _check_stagnation(self, recent_messages: List[str]) -> float:
        """Check for conversation stagnation or confusion"""
        score = 0.0
        for message in recent_messages:
            for pattern in self.stagnation_patterns:
                if re.search(pattern, message):
                    score += 0.3
                    
        # Check for repetitive responses
        if len(set(recent_messages)) < len(recent_messages) * 0.7:
            score += 0.2
            
        return min(1.0, score)

    def _evaluate_conversation_length(self, message_count: int) -> float:
        """Evaluate if conversation length is appropriate for ending"""
        if message_count < 5:
            return 0.1  # Too short
        elif message_count <= 12:
            return 0.8  # Good length
        elif message_count <= 20:
            return 0.9  # Should consider ending
        else:
            return 1.0  # Definitely should end

    def _calculate_ending_decision(
        self, 
        closure_score: float, 
        resolution_score: float, 
        stagnation_score: float, 
        length_score: float
    ) -> tuple[bool, float, str]:
        """Calculate if conversation should end and why"""
        
        # High confidence ending scenarios
        if closure_score >= 0.6 and resolution_score >= 0.4:
            return True, 0.9, "Natural closure with resolution achieved"
            
        if length_score >= 0.9 and (closure_score >= 0.3 or resolution_score >= 0.3):
            return True, 0.8, "Appropriate length reached with some closure"
            
        if stagnation_score >= 0.6 and length_score >= 0.5:
            return True, 0.7, "Conversation stagnating, suggest gentle ending"
            
        # Medium confidence scenarios
        if resolution_score >= 0.6:
            return True, 0.6, "Good problem resolution achieved"
            
        if length_score >= 0.9:
            return True, 0.5, "Conversation length suggests natural ending point"
            
        return False, max(closure_score, resolution_score) * 0.3, "Continue conversation"

    def _generate_ending_message(self, reason: str, character_name: str) -> str:
        """Generate appropriate ending message based on reason"""
        endings = {
            "Natural closure with resolution achieved": f"It sounds like you've gained some valuable insights! I'm glad I could help you work through this. Feel free to practice these skills in real situations.",
            
            "Appropriate length reached with some closure": f"We've covered a lot of ground today. I think this is a good place to wrap up our conversation. Remember to apply what we've discussed!",
            
            "Conversation stagnating, suggest gentle ending": f"I can see this is a complex situation. Sometimes it helps to take time to process what we've talked about. Would you like to end here and reflect on our discussion?",
            
            "Good problem resolution achieved": f"You've shown great insight and growth in our conversation. I think you're ready to handle similar situations with confidence!",
            
            "Conversation length suggests natural ending point": f"We've had a thorough discussion about this. I believe you now have the tools and understanding to move forward positively."
        }
        
        return endings.get(reason, f"Thank you for this meaningful conversation. I hope our discussion has been helpful for your communication journey.")

# Usage helper function
async def should_end_conversation(conversation_history: List[Dict[str, str]], scenario_config: Dict[str, Any]) -> ConversationAnalysis:
    """Helper function to check if conversation should end"""
    tracker = ConversationTracker()
    return await tracker.analyze_conversation_flow(conversation_history, scenario_config)
