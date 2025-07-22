import os
import json
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime
import mimetypes

try:
    from google.cloud import storage
    from google.cloud.exceptions import GoogleCloudError
    GCS_AVAILABLE = True
except ImportError:
    GCS_AVAILABLE = False
    storage = None
    GoogleCloudError = Exception


class GCSUploader:
    """Handles uploading simulation results to Google Cloud Storage"""
    
    def __init__(self, credentials_path: Optional[str] = None):
        """
        Initialize GCS uploader
        
        Parameters:
        credentials_path: Path to service account JSON file (optional)
                         If not provided, uses Application Default Credentials
        """
        if not GCS_AVAILABLE:
            raise ImportError("google-cloud-storage library is required for GCS functionality")
        
        self.credentials_path = credentials_path
        
        # Initialize the client
        if credentials_path and os.path.exists(credentials_path):
            self.client = storage.Client.from_service_account_json(credentials_path)
        else:
            # Use Application Default Credentials (ADC)
            self.client = storage.Client()
    
    def parse_gcs_url(self, gcs_url: str) -> tuple:
        """
        Parse GCS URL into bucket name and prefix
        
        Examples:
        gs://my-bucket -> ('my-bucket', '')
        gs://my-bucket/path -> ('my-bucket', 'path')
        gs://my-bucket/path/to/folder -> ('my-bucket', 'path/to/folder')
        """
        if not gcs_url.startswith('gs://'):
            raise ValueError(f"Invalid GCS URL format: {gcs_url}. Must start with 'gs://'")
        
        # Remove gs:// prefix
        path_part = gcs_url[5:]
        
        # Split bucket and path
        if '/' in path_part:
            bucket_name, prefix = path_part.split('/', 1)
        else:
            bucket_name = path_part
            prefix = ''
        
        return bucket_name, prefix
    
    def get_content_type(self, file_path: str) -> str:
        """Get MIME content type for file"""
        content_type, _ = mimetypes.guess_type(file_path)
        if content_type is None:
            # Default content types for common simulation files
            extension = Path(file_path).suffix.lower()
            content_type_map = {
                '.csv': 'text/csv',
                '.png': 'image/png',
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.json': 'application/json',
                '.yaml': 'application/x-yaml',
                '.yml': 'application/x-yaml',
                '.txt': 'text/plain',
                '.log': 'text/plain'
            }
            content_type = content_type_map.get(extension, 'application/octet-stream')
        
        return content_type
    
    def upload_file(self, local_file_path: str, bucket_name: str, 
                   object_name: str, metadata: Optional[Dict] = None) -> str:
        """
        Upload a single file to GCS
        
        Parameters:
        local_file_path: Path to local file
        bucket_name: GCS bucket name
        object_name: Object name in bucket (key/path)
        metadata: Optional metadata dictionary
        
        Returns:
        GCS URL of uploaded file
        """
        if not os.path.exists(local_file_path):
            raise FileNotFoundError(f"Local file not found: {local_file_path}")
        
        try:
            # Get bucket
            bucket = self.client.bucket(bucket_name)
            
            # Create blob
            blob = bucket.blob(object_name)
            
            # Set content type
            content_type = self.get_content_type(local_file_path)
            
            # Set metadata
            if metadata:
                blob.metadata = metadata
            
            # Upload file
            print(f"  Uploading {local_file_path} -> gs://{bucket_name}/{object_name}")
            
            with open(local_file_path, 'rb') as file_obj:
                blob.upload_from_file(file_obj, content_type=content_type)
            
            # Return GCS URL
            gcs_url = f"gs://{bucket_name}/{object_name}"
            return gcs_url
            
        except GoogleCloudError as e:
            raise Exception(f"Failed to upload {local_file_path} to GCS: {e}")
    
    def upload_results_directory(self, local_dir: str, bucket_url: str, 
                               prefix: str = "monte-carlo-results") -> Dict[str, str]:
        """
        Upload entire results directory to GCS
        
        Parameters:
        local_dir: Local directory containing results
        bucket_url: GCS bucket URL (gs://bucket/path)
        prefix: Object prefix for uploaded files
        
        Returns:
        Dictionary mapping local file paths to GCS URLs
        """
        if not os.path.exists(local_dir):
            raise FileNotFoundError(f"Local directory not found: {local_dir}")
        
        # Parse GCS URL
        bucket_name, base_prefix = self.parse_gcs_url(bucket_url)
        
        # Combine prefixes
        if base_prefix:
            full_prefix = f"{base_prefix}/{prefix}"
        else:
            full_prefix = prefix
        
        # Add timestamp to prefix
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        full_prefix = f"{full_prefix}/{timestamp}"
        
        uploaded_files = {}
        local_path = Path(local_dir)
        
        # Create metadata for the upload
        upload_metadata = {
            'upload_timestamp': datetime.now().isoformat(),
            'upload_source': 'monte-carlo-simulation',
            'local_directory': str(local_path.absolute())
        }
        
        # Find all files in the directory
        for file_path in local_path.rglob('*'):
            if file_path.is_file():
                # Calculate relative path from local_dir
                relative_path = file_path.relative_to(local_path)
                
                # Create GCS object name
                object_name = f"{full_prefix}/{relative_path}"
                
                try:
                    # Upload file
                    gcs_url = self.upload_file(
                        local_file_path=str(file_path),
                        bucket_name=bucket_name,
                        object_name=object_name,
                        metadata=upload_metadata
                    )
                    
                    uploaded_files[str(relative_path)] = gcs_url
                    
                except Exception as e:
                    print(f"  Warning: Failed to upload {file_path}: {e}")
                    continue
        
        # Create and upload a manifest file
        manifest = {
            'upload_info': {
                'timestamp': datetime.now().isoformat(),
                'local_directory': str(local_path.absolute()),
                'gcs_bucket': bucket_name,
                'gcs_prefix': full_prefix,
                'total_files': len(uploaded_files)
            },
            'files': uploaded_files
        }
        
        # Save manifest locally and upload
        manifest_file = local_path / 'upload_manifest.json'
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        try:
            manifest_gcs_url = self.upload_file(
                local_file_path=str(manifest_file),
                bucket_name=bucket_name,
                object_name=f"{full_prefix}/upload_manifest.json",
                metadata=upload_metadata
            )
            uploaded_files['upload_manifest.json'] = manifest_gcs_url
        except Exception as e:
            print(f"  Warning: Failed to upload manifest: {e}")
        
        return uploaded_files
    
    def list_bucket_contents(self, bucket_name: str, prefix: str = "") -> List[str]:
        """List objects in GCS bucket with optional prefix"""
        try:
            bucket = self.client.bucket(bucket_name)
            blobs = bucket.list_blobs(prefix=prefix)
            return [blob.name for blob in blobs]
        except GoogleCloudError as e:
            raise Exception(f"Failed to list bucket contents: {e}")
    
    def download_file(self, bucket_name: str, object_name: str, 
                     local_file_path: str) -> None:
        """Download a file from GCS to local filesystem"""
        try:
            bucket = self.client.bucket(bucket_name)
            blob = bucket.blob(object_name)
            
            # Create local directory if it doesn't exist
            local_path = Path(local_file_path)
            local_path.parent.mkdir(parents=True, exist_ok=True)
            
            print(f"  Downloading gs://{bucket_name}/{object_name} -> {local_file_path}")
            blob.download_to_filename(local_file_path)
            
        except GoogleCloudError as e:
            raise Exception(f"Failed to download {object_name}: {e}")
    
    def get_bucket_info(self, bucket_name: str) -> Dict:
        """Get information about a GCS bucket"""
        try:
            bucket = self.client.bucket(bucket_name)
            bucket.reload()  # Fetch latest bucket metadata
            
            return {
                'name': bucket.name,
                'location': bucket.location,
                'storage_class': bucket.storage_class,
                'created': bucket.time_created.isoformat() if bucket.time_created else None,
                'updated': bucket.updated.isoformat() if bucket.updated else None,
                'versioning_enabled': bucket.versioning_enabled,
                'lifecycle_rules': len(bucket.lifecycle_rules) if bucket.lifecycle_rules else 0
            }
        except GoogleCloudError as e:
            raise Exception(f"Failed to get bucket info: {e}")
    
    @staticmethod
    def is_gcs_available() -> bool:
        """Check if GCS client library is available"""
        return GCS_AVAILABLE
    
    def test_connection(self) -> bool:
        """Test connection to GCS"""
        try:
            # Try to list buckets as a connection test
            list(self.client.list_buckets(max_results=1))
            return True
        except Exception:
            return False