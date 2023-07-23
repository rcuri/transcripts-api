import psycopg2
import os
from aws_lambda_powertools import Logger
from database.config import DatabaseConfig


stage = os.environ.get('STAGE', 'dev')
logger = Logger()
db_config = DatabaseConfig(stage)

def get_transcript_status(transcript_id):
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
    cursor = connection.cursor()
    query = """
        SELECT 
            transaction_id, 
            line_number, 
            speaker_name, 
            time_spoken, 
            spoken_line 
        FROM transcript_results 
        WHERE 
            transaction_id=(%s) 
        ORDER BY line_number ASC;
    """
    cursor.execute(query, (transcript_id,))
    results = cursor.fetchall()
    cursor.close()
    connection.commit()
    if not results:
        logger.info("No results found")
        response = {
            "statusCode": 404
        }
        return response
    logger.info({"query_results:", results})
    output = []
    for result in results:
        current_record = {
            'transaction_id': result[0],
            'line_number': result[1],
            'time_spoken': result[2],
            'speaker_name': result[3],            
            'spoken_line': result[4]
        }
        output.append(current_record)
    logger.info({"response_data": output})
    response = {
        "data": output
    }
    return response
