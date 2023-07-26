import psycopg2
import os
from aws_lambda_powertools import Logger
from database.config import DatabaseConfig


stage = os.environ.get('STAGE', 'dev')
logger = Logger()
db_config = DatabaseConfig(stage)

def get_play_by_play(game_id, period, page_number=1):
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
                event_number, 
                event_type_value, 
                period, 
                wc_timestring, 
                pc_timestring, 
                home_description, 
                neutral_description, 
                visitor_description, 
                score, 
                player1_name, 
                player1_team_id, 
                team.full_name, 
                player2_name, 
                player2_team_id, 
                t2.full_name, 
                player3_name, 
                player3_team_id, 
                t3.full_name, 
                COUNT(*) OVER (RANGE unbounded preceding) as total_results 
            FROM play_by_play 
            LEFT JOIN team 
                ON play_by_play.player1_team_id = team.team_id 
            LEFT JOIN team t2 
                ON play_by_play.player2_team_id = t2.team_id 
            LEFT JOIN team t3 
                ON play_by_play.player3_team_id = t3.team_id 
            WHERE 
                game_id=(%s) 
                AND period=(%s)
            ) 
        SELECT * FROM paginated_table 
        ORDER BY event_number ASC 
        LIMIT 10 
        OFFSET (%s);
    """
    cursor.execute(query, (game_id, period, current_offset))
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
            'event_number': result[1],
            'event_type_value': result[2],
            'period': result[3],
            'wc_timestring': result[4].strftime('%I:%M'),
            'pc_timestring': result[5].strftime('%M:%S'),
            'home_description': result[6],
            'neutral_description': result[7],
            'visitor_description': result[8],
            'score': result[9],
            'player1_name': result[10],
            'player1_team_name': result[12],
            'player2_name': result[13],
            'player2_team_name': result[15],
            'player3_name': result[16],
            'player3_team_name': result[18]                                    
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
