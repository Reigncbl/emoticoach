from sqlmodel import Session, select
from model import ScenarioCompletion, ReadingProgress


class StatsService:

    @staticmethod
    def _compute_overall_avg(results):
        """
        Computes the global average of all available scenario scores for a user.
        """
        all_scores = []

        for completion, _ in results:
            scores = [
                completion.clarity_score,
                completion.empathy_score,
                completion.assertiveness_score,
                completion.appropriateness_score
            ]
            valid_scores = [s for s in scores if s is not None]
            all_scores.extend(valid_scores)

        return sum(all_scores) / len(all_scores) if all_scores else None

    @staticmethod
    def _get_scenario_results(user_id: str, session: Session):
        """
        Returns all scenario completions for a user.
        Using a JOINable pattern (ScenarioCompletion, None).
        """
        query = (
            select(ScenarioCompletion, None)
            .where(ScenarioCompletion.user_id == user_id)
        )
        return session.exec(query).all()

    @staticmethod
    def _get_scenario_count(user_id: str, session: Session) -> int:
        """
        Returns number of completed scenarios by this user.
        """
        results = session.exec(
            select(ScenarioCompletion).where(ScenarioCompletion.user_id == user_id)
        ).all()
        return len(results)

    @staticmethod
    def _get_article_count(user_id: str, session: Session) -> int:
        """
        Returns number of completed readings by this user.
        CompletedAt != NULL is required.
        """
        results = session.exec(
            select(ReadingProgress)
            .where(ReadingProgress.CompletedAt.is_not(None))
            .where(ReadingProgress.MobileNumber == user_id)
        ).all()
        return len(results)

    @staticmethod
    def get_user_stats(user_id: str, session: Session):
        """
        Main entry point for routes.
        Returns: {
            scenario_count,
            article_count,
            overall_avg_score
        }
        """

        # Fetch scenario completions ONCE
        scenario_results = StatsService._get_scenario_results(user_id, session)

        scenario_count = len(scenario_results)
        article_count = StatsService._get_article_count(user_id, session)
        overall_avg = StatsService._compute_overall_avg(scenario_results)

        return {
            "scenario_count": scenario_count,
            "article_count": article_count,
            "overall_avg_score": overall_avg
        }
