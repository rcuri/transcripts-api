import psycopg2
import os
from aws_lambda_powertools import Logger
from database.config import DatabaseConfig


stage = os.environ.get('STAGE', 'dev')
logger = Logger()
db_config = DatabaseConfig(stage)


@logger.inject_lambda_context(log_event=True)
def update_generate_transcript_status(event, _):
    print(event)
    transcript_input = event['transcript_input']
    transcript_id = transcript_input['transcript_id']
    connection = psycopg2.connect(
        user=db_config.POSTGRES_USER,
        password=db_config.POSTGRES_PW,
        host=db_config.POSTGRES_URL,
        database=db_config.POSTGRES_DB,
        port=db_config.POSTGRES_PORT
    )
    query = """
        UPDATE transcript 
        SET 
            transaction_status='SUCCEEDED' 
        WHERE transaction_id=(%s);
    """
    cursor = connection.cursor()
    cursor.execute(query, (transcript_id,))
    cursor.close()
    connection.commit()
    logger.info(f"Updated status for transcript row with transcript_id {transcript_id}")