import os
import json
import boto3
from botocore.exceptions import ClientError


class DatabaseConfig(object):
    def __init__(self, env_setting):
        self.env_setting = env_setting
        
        # Try to get RDS connection info from environment variables first
        rds_host = os.environ.get('RDS_DB_HOST')
        rds_port = os.environ.get('RDS_DB_PORT')
        rds_dbname = os.environ.get('RDS_DB_NAME')
        rds_username = os.environ.get('RDS_DB_USERNAME')
        db_secret_arn = os.environ.get('DB_SECRET_ARN')
        
        if rds_host and rds_port and rds_dbname and rds_username:
            # Use RDS environment variables (new approach)
            print(f"Using RDS configuration for environment: {env_setting}")
            
            # Get password from Secrets Manager
            secret_password = None
            if db_secret_arn:
                secret_data = self._get_secret_by_arn(db_secret_arn)
                if secret_data:
                    secret_password = secret_data.get('password')
            
            if not secret_password:
                print("Warning: Could not retrieve password from Secrets Manager, falling back to environment variable")
                secret_password = os.environ.get('RDS_DB_PASSWORD', '')
            
            self.POSTGRES_USER = rds_username
            self.POSTGRES_PW = secret_password
            self.POSTGRES_URL = rds_host  # Just the hostname, not host:port
            self.POSTGRES_DB = rds_dbname
            self.POSTGRES_PORT = rds_port
            
        else:
            # Fallback to legacy environment variables
            print(f"Using legacy environment variables for environment: {env_setting}")
            if env_setting == 'dev':
                self.POSTGRES_USER = os.environ.get('POSTGRES_DEV_USER')
                self.POSTGRES_PW = os.environ.get('POSTGRES_DEV_PW')
                self.POSTGRES_URL = os.environ.get('POSTGRES_DEV_URL')
                self.POSTGRES_DB = os.environ.get('POSTGRES_DEV_DB')
                self.POSTGRES_PORT = os.environ.get('POSTGRES_DEV_PORT')         
            elif env_setting == 'test':
                self.POSTGRES_USER = os.environ.get('POSTGRES_TEST_USER')
                self.POSTGRES_PW = os.environ.get('POSTGRES_TEST_PW')
                self.POSTGRES_URL = os.environ.get('POSTGRES_TEST_URL')
                self.POSTGRES_DB = os.environ.get('POSTGRES_TEST_DB')
                self.POSTGRES_PORT = os.environ.get('POSTGRES_TEST_PORT')
            elif env_setting == 'prod':
                self.POSTGRES_USER = os.environ.get('POSTGRES_PROD_USERNAME')
                self.POSTGRES_PW = os.environ.get('POSTGRES_PROD_PASSWORD')
                self.POSTGRES_URL = os.environ.get('POSTGRES_PROD_HOST')
                self.POSTGRES_DB = os.environ.get('POSTGRES_PROD_DB')
                self.POSTGRES_PORT = os.environ.get('POSTGRES_PROD_PORT')
        
        # Validate that we have all required parameters
        if not all([self.POSTGRES_USER, self.POSTGRES_PW, self.POSTGRES_URL, self.POSTGRES_DB]):
            missing = []
            if not self.POSTGRES_USER: missing.append('username')
            if not self.POSTGRES_PW: missing.append('password')
            if not self.POSTGRES_URL: missing.append('host/URL')
            if not self.POSTGRES_DB: missing.append('database name')
            
            raise ValueError(f"Missing required database configuration: {', '.join(missing)}")
        
        self.db_url = self.create_db_url(
            self.POSTGRES_USER, self.POSTGRES_PW, 
            self.POSTGRES_URL, self.POSTGRES_DB
        )
    
    def _get_secret_by_arn(self, secret_arn):
        """
        Retrieve secret from AWS Secrets Manager by ARN.
        """
        try:
            # Extract region from ARN
            # ARN format: arn:aws:secretsmanager:region:account-id:secret:name
            region = secret_arn.split(':')[3]
            
            session = boto3.session.Session()
            client = session.client('secretsmanager', region_name=region)
            
            response = client.get_secret_value(SecretId=secret_arn)
            return json.loads(response['SecretString'])
            
        except ClientError as e:
            print(f"Error retrieving secret from Secrets Manager: {e}")
            return None
        except Exception as e:
            print(f"Unexpected error retrieving secret: {e}")
            return None

    def create_db_url(self, user: str, pw: str, url: str, db: str) -> str:
        """
        Create URL to connect to PostgreSQL, with psycopg2 as the driver.
        'user' and 'pw' are the user's database credentials.
        'url' is the name of the host and the port number. e.g. hostname:5432
        'db' is the name of the database.
        """
        from urllib.parse import quote_plus
        
        # URL-encode password to handle special characters
        encoded_password = quote_plus(pw)
        
        return f"postgresql+psycopg2://{user}:{encoded_password}@{url}/{db}"