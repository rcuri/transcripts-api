import psycopg2
import os
from aws_lambda_powertools import Logger
from database.config import DatabaseConfig


stage = os.environ.get('STAGE', 'dev')
logger = Logger()
db_config = DatabaseConfig(stage)

def get_games(page_number=1, season=None, home_team_id=None, visitor_team_id=None):
    connection = psycopg2.connect(
        user=db_config.POSTGRES_USER,
        password=db_config.POSTGRES_PW,
        host=db_config.POSTGRES_URL,
        database=db_config.POSTGRES_DB,
        port=db_config.POSTGRES_PORT
    )
    connection.set_session(readonly=True)
    logger.debug({
        "message": "Successfully created a read-only connection to PostgreSQL db",
        "database": db_config.POSTGRES_DB,
        "host": db_config.POSTGRES_URL
    })
    per_page = 10
    current_offset = (int(page_number) - 1) * per_page
    cursor = connection.cursor()
    query = """
    WITH paginated_table AS (
        SELECT 
            game_id, 
            matchup, 
            game_date, 
            final_score, 
            home_team_id, 
            home_team_name, 
            visitor_team_id, 
            visitor_team_name, 
            count(*) over (range unbounded preceding) as total_results 
        FROM game 
        WHERE 
            season = COALESCE(%s, season)
            AND home_team_id = COALESCE(%s, home_team_id)
            AND visitor_team_id = COALESCE(%s, visitor_team_id)
        ) 
    SELECT * FROM paginated_table 
    ORDER BY game_date DESC 
    LIMIT 10 
    OFFSET (%s);"""
    cursor.execute(
        query, (season, home_team_id, visitor_team_id, current_offset)
    )
    results = cursor.fetchall()
    cursor.close()
    connection.commit()
    if not results:
        logger.info("No results found")
        response = {
            "statusCode": 404
        }
        return response
    logger.info({"query_results": results})    
    output = []
    for result in results:
        current_record = {
            'game_id': result[0],
            'matchup': result[1],
            'game_date': result[2].strftime('%B %d, %Y'),
            'final_score': result[3],
            'home_team_id': result[4],
            'home_team_name': result[5],
            'visitor_team_id': result[6],
            'visitor_team_name': result[7]
        }
        output.append(current_record)
    logger.info({"response_data": output})
    # Last column of row contains total results in query
    total = results[0][-1]
    total_pages = (total // per_page) + 1
    logger.debug("Successfully compiled results")
    logger.info({
        "current_page": page_number,
        "total_pages": total_pages,
        "total": total
    })
    response = {
        "page": page_number,
        "per_page": per_page,
        "total": total,
        "total_pages": total_pages,
        "data": output
    }
    return response
