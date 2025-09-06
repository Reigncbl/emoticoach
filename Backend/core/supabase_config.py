"""
Supabase configuration and utilities
"""
import os
from dotenv import load_dotenv
from supabase import create_client, Client
from typing import Optional
import boto3
from botocore.config import Config

load_dotenv()

class SupabaseConfig:
    def __init__(self):
        self.url = os.getenv("SUPABASE_URL")
        self.service_key = os.getenv("SUPABASE_SERVICE_KEY")  # Service role key for storage
        self.anon_key = os.getenv("SUPABASE_ANON_KEY")  # Anon key
        self.storage_access_key = os.getenv("SUPABASE_STORAGE_ACCESS_KEY")
        self.storage_secret_key = os.getenv("SUPABASE_STORAGE_SECRET_KEY")
        
        if not self.url:
            raise ValueError("SUPABASE_URL environment variable is required")
        if not self.storage_access_key or not self.storage_secret_key:
            raise ValueError("SUPABASE_STORAGE_ACCESS_KEY and SUPABASE_STORAGE_SECRET_KEY environment variables are required")
    
    def get_client(self, use_service_key: bool = False) -> Client:
        """Get Supabase client with appropriate key"""
        key = self.service_key if use_service_key else self.anon_key
        if not key:
            raise ValueError("Supabase API key not configured")
        return create_client(self.url, key)
    
    def get_s3_client(self):
        """Get S3-compatible client for Supabase Storage"""
        # Extract project ID from URL
        project_id = self.url.replace("https://", "").replace(".supabase.co", "")
        endpoint_url = f"https://{project_id}.supabase.co/storage/v1/s3"
        
        return boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=self.storage_access_key,
            aws_secret_access_key=self.storage_secret_key,
            config=Config(
                region_name='us-east-1',  # Supabase default
                signature_version='s3v4'
            )
        )

class SupabaseStorage:
    def __init__(self, bucket_name: str = "scenario-configs"):
        self.config = SupabaseConfig()
        self.bucket_name = bucket_name
        self.s3_client = self.config.get_s3_client()
    
    def create_bucket_if_not_exists(self):
        """Create bucket if it doesn't exist"""
        try:
            # Try to check if bucket exists
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            print(f"Bucket '{self.bucket_name}' already exists")
        except Exception:
            # Bucket doesn't exist, create it
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
                print(f"Created bucket '{self.bucket_name}'")
            except Exception as e:
                print(f"Error creating bucket: {e}")
    
    def upload_yaml(self, file_name: str, yaml_content: str) -> bool:
        """Upload YAML content to Supabase Storage using S3 API"""
        try:
            # Upload file using S3 API
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=file_name,
                Body=yaml_content.encode('utf-8'),
                ContentType='application/yaml'
            )
            
            print(f"Successfully uploaded {file_name}")
            return True
                
        except Exception as e:
            print(f"Error uploading {file_name}: {e}")
            return False
    
    def download_yaml(self, file_name: str) -> Optional[str]:
        """Download YAML content from Supabase Storage using S3 API"""
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket_name,
                Key=file_name
            )
            
            content = response['Body'].read().decode('utf-8')
            return content
                
        except Exception as e:
            print(f"Error downloading {file_name}: {e}")
            return None
    
    def get_public_url(self, file_name: str) -> Optional[str]:
        """Get public URL for a file"""
        try:
            # Generate presigned URL (since bucket is private)
            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': file_name},
                ExpiresIn=3600  # 1 hour
            )
            return url
        except Exception as e:
            print(f"Error getting URL for {file_name}: {e}")
            return None
    
    def list_files(self) -> list:
        """List all files in the bucket"""
        try:
            response = self.s3_client.list_objects_v2(Bucket=self.bucket_name)
            
            if 'Contents' in response:
                return [obj['Key'] for obj in response['Contents']]
            else:
                return []
        except Exception as e:
            print(f"Error listing files: {e}")
            return []
