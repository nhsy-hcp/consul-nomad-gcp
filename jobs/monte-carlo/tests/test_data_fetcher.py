import pytest
import pandas as pd
import numpy as np
import tempfile
import shutil
import json
from pathlib import Path
from unittest.mock import Mock, patch
import sys

# Add src directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from data_fetcher import DataFetcher


class TestDataFetcher:
    
    @pytest.fixture
    def temp_cache_dir(self):
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)
    
    @pytest.fixture
    def mock_config(self):
        return {
            'data': {
                'alpha_vantage_api_key': 'TEST_API_KEY',
                'cache_duration_days': 1,
                'api_rate_limit_per_minute': 5,
                'api_daily_limit': 25
            }
        }
    
    @pytest.fixture
    def data_fetcher(self, temp_cache_dir, mock_config):
        with patch.dict('os.environ', {'ALPHA_VANTAGE_API_KEY': 'TEST_API_KEY'}):
            return DataFetcher(cache_dir=temp_cache_dir, config=mock_config)
    
    @pytest.fixture
    def sample_stock_data_renamed(self):
        """Sample data with renamed columns (as if from cache)"""
        dates = pd.date_range('2023-01-01', periods=50, freq='D')
        data = pd.DataFrame({
            'Open': 100 + np.random.randn(50) * 0.5,
            'High': 102 + np.random.randn(50) * 0.5,
            'Low': 98 + np.random.randn(50) * 0.5,
            'Close': 100 + np.random.randn(50) * 0.5,
            'Volume': 1000000 + np.random.randint(-100000, 100000, 50)
        }, index=dates)
        return data
    
    @pytest.fixture
    def sample_stock_data_alpha_vantage(self):
        """Sample data with Alpha Vantage column names (as if from API)"""
        # Use recent dates so they won't be filtered out by _filter_by_period
        from datetime import datetime, timedelta
        end_date = datetime.now() - timedelta(days=1)  # Yesterday
        start_date = end_date - timedelta(days=49)  # 50 days of data
        dates = pd.date_range(start_date, end_date, freq='D')
        data = pd.DataFrame({
            '1. open': 100 + np.random.randn(50) * 0.5,
            '2. high': 102 + np.random.randn(50) * 0.5,
            '3. low': 98 + np.random.randn(50) * 0.5,
            '4. close': 100 + np.random.randn(50) * 0.5,
            '5. volume': 1000000 + np.random.randint(-100000, 100000, 50)
        }, index=dates)
        return data
    
    def test_init(self, temp_cache_dir, mock_config):
        with patch.dict('os.environ', {'ALPHA_VANTAGE_API_KEY': 'TEST_API_KEY'}):
            fetcher = DataFetcher(cache_dir=temp_cache_dir, config=mock_config)
            assert fetcher.cache_dir == Path(temp_cache_dir)
            assert fetcher.cache_duration_days == 1
            assert fetcher.cache_dir.exists()
            assert fetcher.api_key == 'TEST_API_KEY'
    
    def test_get_cache_path(self, data_fetcher):
        cache_path = data_fetcher._get_cache_path("AAPL", "1y")
        expected = data_fetcher.cache_dir / "AAPL_1y_data.csv"
        assert cache_path == expected
    
    def test_save_and_load_cache(self, data_fetcher, sample_stock_data_renamed):
        ticker = "TEST"
        period = "1y"
        
        # Save to cache
        data_fetcher._save_to_cache(ticker, period, sample_stock_data_renamed)
        
        # Check that cache files exist
        cache_path = data_fetcher._get_cache_path(ticker, period)
        meta_path = data_fetcher._get_cache_meta_path(ticker, period)
        assert cache_path.exists()
        assert meta_path.exists()
        
        # Load from cache
        loaded_data = data_fetcher._load_from_cache(ticker, period)
        
        # Check that data matches
        assert loaded_data is not None
        assert len(loaded_data) == len(sample_stock_data_renamed)
        assert list(loaded_data.columns) == list(sample_stock_data_renamed.columns)
    
    def test_validate_data_renamed_columns(self, data_fetcher, sample_stock_data_renamed):
        """Test validation with renamed columns (from cache)"""
        validated = data_fetcher._validate_data(sample_stock_data_renamed, "TEST")
        assert len(validated) == len(sample_stock_data_renamed)
        assert 'Open' in validated.columns
        assert 'Close' in validated.columns
    
    def test_validate_data_alpha_vantage_columns(self, data_fetcher, sample_stock_data_alpha_vantage):
        """Test validation with Alpha Vantage column names (from API)"""
        validated = data_fetcher._validate_data(sample_stock_data_alpha_vantage, "TEST")
        assert len(validated) == len(sample_stock_data_alpha_vantage)
        # Should be renamed to standard format
        assert 'Open' in validated.columns
        assert 'Close' in validated.columns
        assert '1. open' not in validated.columns
    
    def test_validate_data_empty(self, data_fetcher):
        empty_data = pd.DataFrame()
        with pytest.raises(ValueError, match="No data available"):
            data_fetcher._validate_data(empty_data, "TEST")
    
    def test_validate_data_missing_columns_renamed(self, data_fetcher):
        """Test missing columns in renamed format"""
        bad_data = pd.DataFrame({
            'Open': [100, 101],
            'High': [102, 103]
            # Missing Low, Close, Volume
        })
        with pytest.raises(ValueError, match="Missing columns"):
            data_fetcher._validate_data(bad_data, "TEST")
    
    def test_validate_data_missing_columns_alpha_vantage(self, data_fetcher):
        """Test missing columns in Alpha Vantage format"""
        bad_data = pd.DataFrame({
            '1. open': [100, 101],
            '2. high': [102, 103]
            # Missing other Alpha Vantage columns
        })
        with pytest.raises(ValueError, match="Missing Alpha Vantage columns"):
            data_fetcher._validate_data(bad_data, "TEST")
    
    def test_validate_data_unrecognized_format(self, data_fetcher):
        """Test data with neither format"""
        bad_data = pd.DataFrame({
            'random_col1': [100, 101],
            'random_col2': [102, 103]
        })
        with pytest.raises(ValueError, match="Unrecognized data format"):
            data_fetcher._validate_data(bad_data, "TEST")
    
    def test_validate_data_insufficient_rows(self, data_fetcher):
        """Test insufficient data rows"""
        small_data = pd.DataFrame({
            'Open': [100],
            'High': [102],
            'Low': [98],
            'Close': [101],
            'Volume': [1000000]
        })
        with pytest.raises(ValueError, match="Insufficient data"):
            data_fetcher._validate_data(small_data, "TEST")
    
    @patch('data_fetcher.TimeSeries')
    def test_fetch_ticker_data_success(self, mock_ts_class, data_fetcher, sample_stock_data_alpha_vantage):
        """Test successful API fetch"""
        # Mock Alpha Vantage TimeSeries
        mock_ts = Mock()
        mock_ts.get_daily.return_value = (sample_stock_data_alpha_vantage, {})
        mock_ts_class.return_value = mock_ts
        data_fetcher.ts = mock_ts
        
        result, is_from_cache = data_fetcher.fetch_ticker_data("AAPL", period="1y")
        
        # Check that Alpha Vantage was called correctly
        mock_ts.get_daily.assert_called_once_with(symbol="AAPL", outputsize="compact")
        
        # Check result
        assert not result.empty
        assert len(result) == len(sample_stock_data_alpha_vantage)
        assert 'Open' in result.columns  # Should be renamed
        assert not is_from_cache  # Should be fresh data
    
    def test_fetch_ticker_data_with_cache(self, data_fetcher, sample_stock_data_renamed):
        """Test fetching with cached data"""
        ticker = "AAPL"
        period = "1y"
        
        # Pre-populate cache
        data_fetcher._save_to_cache(ticker, period, sample_stock_data_renamed)
        
        with patch.object(data_fetcher, 'rate_limiter') as mock_limiter:
            result, is_from_cache = data_fetcher.fetch_ticker_data(ticker, period)
            
            # Should not have called rate limiter (used cache instead)
            mock_limiter.wait_if_needed.assert_not_called()
            
            # Should return cached data
            assert not result.empty
            assert len(result) == len(sample_stock_data_renamed)
            assert is_from_cache  # Should be from cache
    
    @patch('data_fetcher.TimeSeries')
    def test_fetch_ticker_data_empty_response(self, mock_ts_class, data_fetcher):
        """Test empty API response"""
        # Mock empty response
        mock_ts = Mock()
        mock_ts.get_daily.return_value = (pd.DataFrame(), {})
        mock_ts_class.return_value = mock_ts
        data_fetcher.ts = mock_ts
        
        result, is_from_cache = data_fetcher.fetch_ticker_data("INVALID")
        
        # Should return empty DataFrame
        assert result.empty
        assert not is_from_cache
    
    @patch('data_fetcher.FundamentalData')
    def test_get_ticker_info(self, mock_fd_class, data_fetcher):
        """Test getting ticker info"""
        # Mock company overview data
        mock_overview = pd.DataFrame({
            'Name': ['Apple Inc.'],
            'Sector': ['Technology'],
            'Industry': ['Consumer Electronics'],
            'MarketCapitalization': [3000000000000],
            'Currency': ['USD'],
            'Exchange': ['NASDAQ']
        })
        
        mock_fd = Mock()
        mock_fd.get_company_overview.return_value = (mock_overview, {})
        mock_fd_class.return_value = mock_fd
        data_fetcher.fd = mock_fd
        
        result = data_fetcher.get_ticker_info("AAPL")
        
        # Check result
        assert result['symbol'] == 'AAPL'
        assert result['name'] == 'Apple Inc.'
        assert result['sector'] == 'Technology'
        assert result['market_cap'] == 3000000000000
    
    def test_clear_cache_specific(self, data_fetcher, sample_stock_data_renamed):
        """Test clearing specific ticker cache"""
        ticker = "AAPL"
        period = "1y"
        
        # Create cache
        data_fetcher._save_to_cache(ticker, period, sample_stock_data_renamed)
        
        cache_path = data_fetcher._get_cache_path(ticker, period)
        meta_path = data_fetcher._get_cache_meta_path(ticker, period)
        
        assert cache_path.exists()
        assert meta_path.exists()
        
        # Clear specific cache
        data_fetcher.clear_cache(ticker, period)
        
        assert not cache_path.exists()
        assert not meta_path.exists()
    
    def test_get_cache_info(self, data_fetcher, sample_stock_data_renamed):
        """Test getting cache information"""
        # Create some cached data
        data_fetcher._save_to_cache("AAPL", "1y", sample_stock_data_renamed)
        data_fetcher._save_to_cache("MSFT", "2y", sample_stock_data_renamed)
        
        info = data_fetcher.get_cache_info()
        
        assert 'cache_dir' in info
        assert 'total_files' in info
        assert 'cached_tickers' in info
        assert 'api_calls_today' in info
        assert 'daily_limit' in info
        assert info['total_files'] == 2
        assert 'AAPL' in info['cached_tickers']
        assert 'MSFT' in info['cached_tickers']
    
    def test_api_key_from_config(self, temp_cache_dir):
        """Test API key loaded from config"""
        config = {
            'data': {
                'alpha_vantage_api_key': 'CONFIG_API_KEY',
                'cache_duration_days': 1,
                'api_rate_limit_per_minute': 5,
                'api_daily_limit': 25
            }
        }
        
        fetcher = DataFetcher(cache_dir=temp_cache_dir, config=config)
        assert fetcher.api_key == 'CONFIG_API_KEY'
    
    def test_api_key_from_env(self, temp_cache_dir):
        """Test API key loaded from environment variable"""
        config = {'data': {}}
        
        with patch.dict('os.environ', {'ALPHA_VANTAGE_API_KEY': 'ENV_API_KEY'}):
            fetcher = DataFetcher(cache_dir=temp_cache_dir, config=config)
            assert fetcher.api_key == 'ENV_API_KEY'
    
    def test_no_api_key_allows_cache_only_mode(self, temp_cache_dir):
        """Test that missing API key allows initialization in cache-only mode"""
        config = {'data': {}}
        
        with patch.dict('os.environ', {}, clear=True):
            # Should not raise an error - allows cache-only mode
            fetcher = DataFetcher(cache_dir=temp_cache_dir, config=config)
            assert fetcher.api_key is None
            assert fetcher.ts is None
            assert fetcher.fd is None
    
    def test_fetch_without_api_key_no_cache_raises_error(self, temp_cache_dir):
        """Test that fetching without API key and no cache raises error"""
        config = {'data': {}}
        
        with patch.dict('os.environ', {}, clear=True):
            fetcher = DataFetcher(cache_dir=temp_cache_dir, config=config)
            
            with pytest.raises(ValueError, match="No API key provided and no cached data available"):
                fetcher.fetch_ticker_data('AAPL', '1y')