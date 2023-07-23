from models.play_by_play import PlayByPlay
from pathlib import Path
from sqlalchemy.orm import Session
from database.config import DatabaseConfig
import csv
from sqlalchemy import create_engine
import logging
import datetime
from models.base import Base
from models.game import Game
from models.team import Team

logger = logging.getLogger(__name__)
f_handler = logging.FileHandler('load_tables.log')

class PlayByPlayTableLoader:
    def __init__(self, csv_directory):
        self.model = PlayByPlay
        self.data_directory = Path(csv_directory)
        self.db_config = DatabaseConfig("production")
    
    def load_db(self):
        csv_files = [file for file in self.data_directory.rglob("*.csv")]
        engine = create_engine(self.db_config.db_url)
        Base.metadata.create_all(engine)        
        event_composite_keys = {}            
        for raw_file in csv_files:
            with open(raw_file, newline='') as csvfile:
                reader = csv.DictReader(csvfile)
                with Session(engine) as session:
                    for row in reader:
                        if event_composite_keys.get((row['game_id'], row['event_number'])):
                            continue
                        event_composite_keys[(row['game_id'], row['event_number'])] = True                        
                        clean_row = {}
                        clean_row['game_id'] = row['game_id']
                        clean_row['event_number'] = row['event_number']
                        clean_row['event_msg_type_code'] = row['event_msg_type_code']
                        clean_row['event_type_value'] = row['event_type_value']
                        clean_row['period'] = row['period']
                        clean_row['home_description'] = row['home_description']
                        clean_row['neutral_description'] = row['neutral_description']
                        clean_row['visitor_description'] = row['visitor_description']
                        clean_row['score'] = row['score']
                        clean_row['player1_id'] = row['player1_id']
                        clean_row['player1_name'] = row['player1_name']
                        clean_row['player1_team_id'] = int(float(row['player1_team_id'])) if row['player1_team_id'] else None
                        clean_row['player2_id'] = row['player2_id']
                        clean_row['player2_team_id'] = int(float(row['player2_team_id'])) if row['player2_team_id'] else None
                        clean_row['player2_name'] = row['player2_name']
                        clean_row['player3_id'] = row['player3_id']  
                        clean_row['player3_team_id'] = int(float(row['player3_team_id'])) if row['player3_team_id'] else None
                        clean_row['player3_name'] = row['player3_name']
                        try:
                            clean_row['wc_timestring'] = datetime.datetime.strptime(row['wc_timestring'], "%I:%M %p").time()
                        except ValueError:
                            logger.error("current row's time string is not valid")
                        try:
                            clean_row['pc_timestring'] = datetime.datetime.strptime(row['pc_timestring'], "%M:%S").time()
                        except ValueError:
                            logger.error("current row's playclock time is not a valid time")
                        current_rec = PlayByPlay(clean_row)
                        logger.info("Adding row to session")
                        session.add(current_rec)
                        logger.info("Added row to session")
                    session.commit()