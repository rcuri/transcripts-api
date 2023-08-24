from .index import get_games
import json
from aws_lambda_powertools import Logger


logger = Logger()


@logger.inject_lambda_context(log_event=True)
def handler(event, _):
    parameters = event.get('queryStringParameters', {})
    if not parameters:
        logger.info("No query parameters received in request")
        parameters = {}
    page_number = parameters.get('page_number', 1)
    season = parameters.get('season')
    home_team_id = parameters.get('home_team_id')
    visitor_team_id = parameters.get('visitor_team_id')
    logger.info({
        "page_number": page_number,
        "season": season,
        "home_team_id": home_team_id,
        "visitor_team_id": visitor_team_id
    })
    player_results = get_games(page_number, season, home_team_id, visitor_team_id)
    logger.info("Successfully finished call to get_games function")
    return player_results
