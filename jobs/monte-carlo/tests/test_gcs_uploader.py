import pytest
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import json
import sys

# Add src directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from gcs_uploader import GCSUploader


class TestGCSUploader:
    
    @pytest.fixture
    def temp_dir(self):
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)
    
    @pytest.fixture
    def sample_files(self, temp_dir):
        # Create some test files
        files = {
            'results.csv': 'ticker,price,return\nAAPL,150.0,0.05\n',
            'plot.png': b'fake_png_data',
            'summary.json': '{"mean": 150.0, "std": 10.0}'
        }
        
        for filename, content in files.items():
            file_path = Path(temp_dir) / filename
            mode = 'w' if isinstance(content, str) else 'wb'
            with open(file_path, mode) as f:
                f.write(content)
        
        return files
    
    def test_is_gcs_available(self):
        # This test depends on whether google-cloud-storage is installed
        result = GCSUploader.is_gcs_available()
        assert isinstance(result, bool)
    
    def test_parse_gcs_url_basic(self):
        uploader = GCSUploader.__new__(GCSUploader)  # Create without __init__
        
        bucket, prefix = uploader.parse_gcs_url("gs://my-bucket")
        assert bucket == "my-bucket"
        assert prefix == ""
    
    def test_parse_gcs_url_with_path(self):
        uploader = GCSUploader.__new__(GCSUploader)
        
        bucket, prefix = uploader.parse_gcs_url("gs://my-bucket/path/to/folder")
        assert bucket == "my-bucket"
        assert prefix == "path/to/folder"
    
    def test_parse_gcs_url_invalid(self):
        uploader = GCSUploader.__new__(GCSUploader)
        
        with pytest.raises(ValueError, match="Invalid GCS URL format"):
            uploader.parse_gcs_url("invalid-url")
        
        with pytest.raises(ValueError, match="Invalid GCS URL format"):
            uploader.parse_gcs_url("s3://bucket/path")
    
    def test_get_content_type(self):
        uploader = GCSUploader.__new__(GCSUploader)
        
        # Test known file types
        assert uploader.get_content_type("test.csv") == "text/csv"
        assert uploader.get_content_type("test.png") == "image/png"
        assert uploader.get_content_type("test.json") == "application/json"
        assert uploader.get_content_type("test.yaml") == "application/x-yaml"
        assert uploader.get_content_type("test.unknown") == "application/octet-stream"
    
    @patch('gcs_uploader.storage')
    def test_upload_file_success(self, mock_storage, temp_dir, sample_files):
        # Create mock client and blob
        mock_client = Mock()
        mock_bucket = Mock()
        mock_blob = Mock()
        
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_storage.Client.return_value = mock_client
        
        # Initialize uploader
        uploader = GCSUploader()
        
        # Test file upload
        local_file = Path(temp_dir) / 'results.csv'
        result_url = uploader.upload_file(
            str(local_file), 
            "test-bucket", 
            "path/results.csv"
        )
        
        # Verify calls
        mock_client.bucket.assert_called_once_with("test-bucket")
        mock_bucket.blob.assert_called_once_with("path/results.csv")
        mock_blob.upload_from_file.assert_called_once()
        
        # Check result
        assert result_url == "gs://test-bucket/path/results.csv"
    
    @patch('gcs_uploader.storage')
    def test_upload_file_not_found(self, mock_storage):
        mock_client = Mock()
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        
        with pytest.raises(FileNotFoundError):
            uploader.upload_file("/nonexistent/file.csv", "bucket", "object")
    
    @patch('gcs_uploader.storage')
    def test_upload_results_directory(self, mock_storage, temp_dir, sample_files):
        # Mock GCS client
        mock_client = Mock()
        mock_bucket = Mock()
        mock_blob = Mock()
        
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        
        # Mock the upload_file method to avoid actual file operations in the loop
        original_upload_file = uploader.upload_file
        uploader.upload_file = Mock(side_effect=lambda local_file_path, bucket_name, object_name, metadata=None: f"gs://{bucket_name}/{object_name}")
        
        uploaded_files, success = uploader.upload_results_directory(
            local_dir=temp_dir,
            bucket_url="gs://test-bucket/results",
            prefix="monte-carlo"
        )
        
        # Should have uploaded all files plus manifest
        assert len(uploaded_files) == len(sample_files) + 1  # +1 for manifest
        assert 'upload_manifest.json' in uploaded_files
        assert success is True
        
        # Check that files were "uploaded"
        for filename in sample_files.keys():
            assert filename in uploaded_files
            assert uploaded_files[filename].startswith("gs://test-bucket/")
    
    @patch('gcs_uploader.storage')
    def test_list_bucket_contents(self, mock_storage):
        mock_client = Mock()
        mock_bucket = Mock()
        mock_blob1 = Mock()
        mock_blob1.name = "file1.csv"
        mock_blob2 = Mock()
        mock_blob2.name = "file2.png"
        
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.list_blobs.return_value = [mock_blob1, mock_blob2]
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        result = uploader.list_bucket_contents("test-bucket", prefix="data/")
        
        mock_bucket.list_blobs.assert_called_once_with(prefix="data/")
        assert result == ["file1.csv", "file2.png"]
    
    @patch('gcs_uploader.storage')
    def test_get_bucket_info(self, mock_storage):
        mock_client = Mock()
        mock_bucket = Mock()
        mock_bucket.name = "test-bucket"
        mock_bucket.location = "US"
        mock_bucket.storage_class = "STANDARD"
        mock_bucket.time_created = None
        mock_bucket.updated = None
        mock_bucket.versioning_enabled = False
        mock_bucket.lifecycle_rules = None
        
        mock_client.bucket.return_value = mock_bucket
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        info = uploader.get_bucket_info("test-bucket")
        
        assert info['name'] == "test-bucket"
        assert info['location'] == "US"
        assert info['storage_class'] == "STANDARD"
        assert info['versioning_enabled'] == False
    
    @patch('gcs_uploader.storage')
    def test_test_connection_success(self, mock_storage):
        mock_client = Mock()
        mock_client.list_buckets.return_value = iter([])  # Empty iterator
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        assert uploader.test_connection() == True
    
    @patch('gcs_uploader.storage')
    def test_test_connection_failure(self, mock_storage):
        mock_client = Mock()
        mock_client.list_buckets.side_effect = Exception("Connection failed")
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        assert uploader.test_connection() == False
    
    @patch('gcs_uploader.storage')
    def test_download_file(self, mock_storage, temp_dir):
        mock_client = Mock()
        mock_bucket = Mock()
        mock_blob = Mock()
        
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        local_path = Path(temp_dir) / "downloaded.csv"
        
        uploader.download_file("test-bucket", "data/file.csv", str(local_path))
        
        mock_bucket.blob.assert_called_once_with("data/file.csv")
        mock_blob.download_to_filename.assert_called_once_with(str(local_path))
    
    def test_init_without_gcs_library(self):
        # Test behavior when google-cloud-storage is not available
        with patch('gcs_uploader.GCS_AVAILABLE', False):
            with pytest.raises(ImportError, match="google-cloud-storage library is required"):
                GCSUploader()
    
    @patch('gcs_uploader.storage')
    @patch('gcs_uploader.os.path.exists')
    def test_init_with_credentials_file(self, mock_exists, mock_storage):
        mock_exists.return_value = True
        mock_client = Mock()
        mock_storage.Client.from_service_account_json.return_value = mock_client
        
        uploader = GCSUploader(credentials_path="/path/to/service-account.json")
        
        mock_storage.Client.from_service_account_json.assert_called_once_with("/path/to/service-account.json")
        assert uploader.client == mock_client
    
    @patch('gcs_uploader.storage')
    def test_init_with_default_credentials(self, mock_storage):
        mock_client = Mock()
        mock_storage.Client.return_value = mock_client
        
        uploader = GCSUploader()
        
        mock_storage.Client.assert_called_once()
        assert uploader.client == mock_client