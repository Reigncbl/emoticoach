import uuid
from sqlmodel import Session, select
from sqlalchemy import desc
from datetime import datetime
from model.scenario_completion import ScenarioCompletion
from model.scenario_with_config import ScenarioWithConfig


def save_completion(session: Session, request) -> dict:
    existing_completion = session.exec(
        select(ScenarioCompletion)
        .where(ScenarioCompletion.user_id == request.user_id)
        .where(ScenarioCompletion.scenario_id == request.scenario_id)
    ).first()

    if existing_completion:
        # Update
        existing_completion.completion_time_minutes = request.completion_time_minutes
        existing_completion.clarity_score = request.final_clarity_score
        existing_completion.empathy_score = request.final_empathy_score
        existing_completion.assertiveness_score = request.final_assertiveness_score
        existing_completion.appropriateness_score = request.final_appropriateness_score
        existing_completion.user_rating = request.user_rating
        existing_completion.total_messages = request.total_messages
        existing_completion.completed_at = datetime.utcnow()

        session.commit()
        session.refresh(existing_completion)

        return {
            "success": True,
            "message": "Scenario completion updated successfully",
            "completion_id": existing_completion.scenario_completion_id,
            "is_repeat": True
        }
    else:
        # Create
        completed_scenarios = ScenarioCompletion(
            scenario_completion_id=str(uuid.uuid4()),
            user_id=request.user_id,
            scenario_id=request.scenario_id,
            completion_time_minutes=request.completion_time_minutes,
            clarity_score=request.final_clarity_score,
            empathy_score=request.final_empathy_score,
            assertiveness_score=request.final_assertiveness_score,
            appropriateness_score=request.final_appropriateness_score,
            user_rating=request.user_rating,
            total_messages=request.total_messages
        )

        session.add(completed_scenarios)
        session.commit()
        session.refresh(completed_scenarios)

        return {
            "success": True,
            "message": "Scenario completed successfully",
            "completion_id": completed_scenarios.scenario_completion_id,
            "is_repeat": False
        }


def get_user_completions(session: Session, user_id: str) -> dict:
    query = (
        select(ScenarioCompletion, ScenarioWithConfig)
        .join(ScenarioWithConfig)
        .where(ScenarioCompletion.user_id == user_id)
        .where(ScenarioCompletion.scenario_id == ScenarioWithConfig.id)
    )

    results = session.exec(query).all()
    # Sort by completed_at in descending order
    results = sorted(results, key=lambda x: x[0].completed_at, reverse=True)

    completed_scenarios = []
    for completion, scenario in results:
        scores = [
            completion.clarity_score,
            completion.empathy_score,
            completion.assertiveness_score,
            completion.appropriateness_score
        ]
        valid_scores = [s for s in scores if s is not None]
        avg_score = sum(valid_scores) / len(valid_scores) if valid_scores else None

        completed_scenarios.append({
            "scenario_id": scenario.id,
            "title": scenario.title,
            "description": scenario.description,
            "category": scenario.category,
            "difficulty": scenario.difficulty,
            "estimated_duration": scenario.estimated_duration,
            "completed_at": completion.completed_at.isoformat(),
            "completion_time_minutes": completion.completion_time_minutes,
            "clarity_score": completion.clarity_score,
            "empathy_score": completion.empathy_score,
            "assertiveness_score": completion.assertiveness_score,
            "appropriateness_score": completion.appropriateness_score,
            "average_score": avg_score,
            "user_rating": completion.user_rating,
            "total_messages": completion.total_messages,
            "completion_count": 1
        })

    return {
        "success": True,
        "completed_scenarios": completed_scenarios,
        "total_completed": len(completed_scenarios)
    }
