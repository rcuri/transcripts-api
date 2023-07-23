from models.game import Game
from pathlib import Path
from sqlalchemy.orm import Session
from database.config import DatabaseConfig
import csv
from sqlalchemy import create_engine
import logging
from models.base import Base
from models.team import Team

logger = logging.getLogger(__name__)
f_handler = logging.FileHandler('load_game_table.log')

class GameTableLoader:
    def __init__(self, csv_directory):
        self.model = Game
        self.data_directory = Path(csv_directory)
        self.db_config = DatabaseConfig("production")
    
    def load_db(self):
        csv_files = [file for file in self.data_directory.rglob("*.csv")]
        engine = create_engine(self.db_config.db_url)
        Base.metadata.create_all(engine)
        with Session(engine) as session:
            for raw_file in csv_files:
                with open(raw_file, newline='') as csvfile:
                    reader = csv.DictReader(csvfile)
                    for row in reader:
                        clean_row = {}
                        """
                        clean_row['game_id'] = row['game_id']
                        clean_row['game_date'] = row['game_date']
                        clean_row['season_id'] = row['season_id']
                        clean_row['season'] = row['season']
                        clean_row['season_type'] = row['season_type']
                        clean_row['final_score'] = row['final_score']
                        clean_row['visitor_team_id'] = row['visitor_team_id']
                        clean_row['visitor_team_abbreviation'] = row['visitor_team_abbreviation']
                        clean_row['visitor_team_name'] = row['visitor_team_name']
                        clean_row['home_team_id'] = row['home_team_id']
                        clean_row['home_team_abbreviation'] = row['home_team_abbreviation']
                        clean_row['home_team_name'] = row['home_team_name']
                        clean_row['matchup'] = row['matchup']
                        clean_row['final_score'] = row['state']
                        clean_row['year_founded'] = row['year_founded']
                        """
                        clean_row['game_id'] = row[str.upper('game_id')]
                        clean_row['game_date'] = row[str.upper('game_date')]
                        clean_row['season_id'] = row[str.upper('season_id')]
                        clean_row['season'] = row[str.upper('season')]
                        clean_row['season_type'] = row[str.upper('season_type')]
                        clean_row['final_score'] = row[str.upper('final_score')]
                        clean_row['visitor_team_id'] = row[str.upper('visitor_team_id')]
                        clean_row['visitor_team_abbreviation'] = row[str.upper('visitor_team_abbreviation')]
                        clean_row['visitor_team_name'] = row[str.upper('visitor_team_name')]
                        clean_row['home_team_id'] = row[str.upper('home_team_id')]
                        clean_row['home_team_abbreviation'] = row[str.upper('home_team_abbreviation')]
                        clean_row['home_team_name'] = row[str.upper('home_team_name')]
                        clean_row['matchup'] = row[str.upper('matchup')]
                        clean_row['final_score'] = row[str.upper('final_score')]
                        current_rec = Game(clean_row)
                        logger.info("Adding row to session")
                        session.add(current_rec)
                        logger.info("Added row to session")
                session.commit()