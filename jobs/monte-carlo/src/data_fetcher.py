import pandas as pd
import os
import json
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, Any
from alpha_vantage.timeseries import TimeSeries
from alpha_vantage.fundamentaldata import FundamentalData
import queue
import threading


class RateLimiter:
    """Rate limiter for API calls"""
    
    def __init__(self, calls_per_minute: int = 5, daily_limit: int = 25):
        self.calls_per_minute = calls_per_minute
        self.daily_limit = daily_limit
        self.call_times = queue.Queue()
        self.daily_calls = 0
        self.last_reset = datetime.now().date()
        self.lock = threading.Lock()
    
    def wait_if_needed(self):
        """Wait if rate limit would be exceeded"""
        with self.lock:
            now = datetime.now()
            
            # Reset daily counter if new day
            if now.date() > self.last_reset:
                self.daily_calls = 0
                self.last_reset = now.date()
            
            # Check daily limit
            if self.daily_calls >= self.daily_limit:
                raise Exception(f"Daily API limit of {self.daily_limit} calls exceeded")
            
            # Clean old call times (older than 1 minute)
            cutoff_time = now - timedelta(minutes=1)
            temp_queue = queue.Queue()
            
            while not self.call_times.empty():
                call_time = self.call_times.get()
                if call_time > cutoff_time:
                    temp_queue.put(call_time)
            
            self.call_times = temp_queue
            
            # Wait if per-minute limit would be exceeded
            if self.call_times.qsize() >= self.calls_per_minute:
                oldest_call = None
                temp_calls = []
                
                while not self.call_times.empty():
                    call_time = self.call_times.get()
                    temp_calls.append(call_time)
                    if oldest_call is None:
                        oldest_call = call_time
                
                for call_time in temp_calls:
                    self.call_times.put(call_time)
                
                if oldest_call:
                    wait_time = 60 - (now - oldest_call).total_seconds()
                    if wait_time > 0:
                        print(f"  Rate limit: waiting {wait_time:.1f} seconds...")
                        time.sleep(wait_time)
            
            # Record this call
            self.call_times.put(now)
            self.daily_calls += 1


class DataFetcher:
    """Handles fetching and caching of ticker data using Alpha Vantage API"""
    
    def __init__(self, cache_dir: str = "/app/data", config: Dict[str, Any] = None):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        # Configuration
        self.config = config or {}
        data_config = self.config.get('data', {})
        
        # Cache settings
        self.cache_duration_days = data_config.get('cache_duration_days', 1)
        
        # API configuration
        self.api_key = self._get_api_key(data_config)
        
        # Initialize Alpha Vantage clients only if API key is available
        if self.api_key:
            # Rate limiter
            calls_per_minute = data_config.get('api_rate_limit_per_minute', 5)
            daily_limit = data_config.get('api_daily_limit', 25)
            self.rate_limiter = RateLimiter(calls_per_minute, daily_limit)
            
            # Alpha Vantage clients
            self.ts = TimeSeries(key=self.api_key, output_format='pandas')
            self.fd = FundamentalData(key=self.api_key, output_format='pandas')
            
            print(f"  Initialized Alpha Vantage client with rate limit: {calls_per_minute}/min, {daily_limit}/day")
        else:
            self.rate_limiter = None
            self.ts = None
            self.fd = None
            print("  No API key provided - will use cached data only if available")
        
    def _get_api_key(self, data_config: Dict[str, Any]) -> Optional[str]:
        """Get API key from config or environment variable"""
        # Try config first
        api_key = data_config.get('alpha_vantage_api_key')
        if api_key and api_key not in ['null', None, 'None', '']:
            return str(api_key)
        
        # Fall back to environment variable
        return os.getenv('ALPHA_VANTAGE_API_KEY')
    
    def _get_cache_path(self, ticker: str, period: str) -> Path:
        """Get cache file path for ticker and period"""
        return self.cache_dir / f"{ticker}_{period}_data.csv"
    
    def _get_cache_meta_path(self, ticker: str, period: str) -> Path:
        """Get cache metadata file path"""
        return self.cache_dir / f"{ticker}_{period}_meta.json"
    
    def _is_cache_valid(self, ticker: str, period: str) -> bool:
        """Check if cached data is still valid"""
        meta_path = self._get_cache_meta_path(ticker, period)
        
        if not meta_path.exists():
            return False
        
        try:
            with open(meta_path, 'r') as f:
                meta = json.load(f)
            
            cached_time = datetime.fromisoformat(meta['cached_at'])
            expiry_time = cached_time + timedelta(days=self.cache_duration_days)
            
            return datetime.now() < expiry_time
        
        except (json.JSONDecodeError, KeyError, ValueError):
            return False
    
    def _save_to_cache(self, ticker: str, period: str, data: pd.DataFrame):
        """Save data to cache with metadata"""
        cache_path = self._get_cache_path(ticker, period)
        meta_path = self._get_cache_meta_path(ticker, period)
        
        # Save data
        data.to_csv(cache_path)
        
        # Save metadata
        meta = {
            'ticker': ticker,
            'period': period,
            'cached_at': datetime.now().isoformat(),
            'rows': len(data),
            'columns': list(data.columns),
            'data_source': 'alpha_vantage'
        }
        
        with open(meta_path, 'w') as f:
            json.dump(meta, f, indent=2)
        
        print(f"  Cached {len(data)} rows for {ticker}")
    
    def _load_from_cache(self, ticker: str, period: str) -> Optional[pd.DataFrame]:
        """Load data from cache"""
        cache_path = self._get_cache_path(ticker, period)
        
        if not cache_path.exists():
            return None
        
        try:
            data = pd.read_csv(cache_path, index_col=0, parse_dates=True)
            print(f"  Loaded {len(data)} rows from cache for {ticker}")
            return data
        
        except Exception as e:
            print(f"  Error loading cache for {ticker}: {e}")
            return None
    
    def _validate_data(self, data: pd.DataFrame, ticker: str) -> pd.DataFrame:
        """Validate and clean fetched data"""
        if data.empty:
            raise ValueError(f"No data available for ticker {ticker}")
        
        # Check if data is already in renamed format (from cache) or Alpha Vantage format (fresh)
        has_alpha_vantage_columns = '1. open' in data.columns
        has_renamed_columns = 'Open' in data.columns
        
        if has_alpha_vantage_columns:
            # Fresh data from Alpha Vantage - validate and rename columns
            required_columns = ['1. open', '2. high', '3. low', '4. close', '5. volume']
            missing_columns = [col for col in required_columns if col not in data.columns]
            
            if missing_columns:
                raise ValueError(f"Missing Alpha Vantage columns for {ticker}: {missing_columns}")
            
            # Rename columns to match expected format
            data = data.rename(columns={
                '1. open': 'Open',
                '2. high': 'High', 
                '3. low': 'Low',
                '4. close': 'Close',
                '5. volume': 'Volume'
            })
            
        elif has_renamed_columns:
            # Data from cache - validate renamed columns
            required_columns = ['Open', 'High', 'Low', 'Close', 'Volume']
            missing_columns = [col for col in required_columns if col not in data.columns]
            
            if missing_columns:
                raise ValueError(f"Missing columns for {ticker}: {missing_columns}")
                
        else:
            raise ValueError(f"Unrecognized data format for {ticker}. Expected either Alpha Vantage or cached format.")
        
        # Remove rows with missing Close prices
        initial_rows = len(data)
        data = data.dropna(subset=['Close'])
        
        if len(data) != initial_rows:
            print(f"  Removed {initial_rows - len(data)} rows with missing Close prices")
        
        if len(data) < 30:
            raise ValueError(f"Insufficient data for {ticker}: only {len(data)} valid rows")
        
        # Sort by date (newest first from Alpha Vantage, reverse to oldest first)
        data = data.sort_index()
        
        return data
    
    def _map_period_to_alpha_vantage(self, period: str) -> str:
        """Map period to Alpha Vantage outputsize parameter"""
        # Alpha Vantage supports 'compact' (100 data points) or 'full' (20+ years)
        long_periods = ['2y', '5y', '10y', 'max']
        return 'full' if period in long_periods else 'compact'
    
    def fetch_ticker_data(self, ticker: str, period: str = "2y", 
                         force_refresh: bool = False) -> tuple[pd.DataFrame, bool]:
        """
        Fetch ticker data with caching using Alpha Vantage API
        
        Parameters:
        ticker: Stock ticker symbol (e.g., 'AAPL')
        period: Time period ('1d', '5d', '1mo', '3mo', '6mo', '1y', '2y', '5y', '10y', 'ytd', 'max')
        force_refresh: Force refresh of cached data
        
        Returns:
        tuple: (DataFrame, is_from_cache) - Data and boolean indicating if from cache
        """
        
        ticker = ticker.upper()
        
        print(f"  Fetching data for {ticker} (period: {period})")
        
        # Check cache first
        if not force_refresh and self._is_cache_valid(ticker, period):
            cached_data = self._load_from_cache(ticker, period)
            if cached_data is not None:
                return self._validate_data(cached_data, ticker), True
        
        # Check for cached data if no API key is available
        if not self.api_key:
            cached_data = self._load_from_cache(ticker, period)
            if cached_data is not None:
                print(f"  Using expired cached data for {ticker} (no API key available)")
                return self._validate_data(cached_data, ticker), True
            else:
                raise ValueError(f"No API key provided and no cached data available for {ticker}. Set ALPHA_VANTAGE_API_KEY environment variable or configure in simulation.yaml, or ensure cached data exists.")
        
        # Fetch fresh data from Alpha Vantage
        try:
            print(f"  Downloading fresh data for {ticker} from Alpha Vantage...")
            
            # Wait for rate limiting
            self.rate_limiter.wait_if_needed()
            
            # Map period to Alpha Vantage outputsize
            outputsize = self._map_period_to_alpha_vantage(period)
            
            # Fetch daily data (free tier doesn't support adjusted)
            data, meta_data = self.ts.get_daily(symbol=ticker, outputsize=outputsize)
            
            if data.empty:
                # Try compact if full failed
                if outputsize == 'full':
                    print(f"  Trying compact data for {ticker}...")
                    self.rate_limiter.wait_if_needed()
                    data, meta_data = self.ts.get_daily(symbol=ticker, outputsize='compact')
            
            # Process and validate data
            if not data.empty:
                
                validated_data = self._validate_data(data, ticker)
                
                # Filter data to requested period if needed
                if period not in ['max', 'full']:
                    validated_data = self._filter_by_period(validated_data, period)
                
                # Cache the data
                self._save_to_cache(ticker, period, validated_data)
                
                return validated_data, False
            else:
                raise ValueError(f"No data returned from Alpha Vantage for {ticker}")
            
        except Exception as e:
            print(f"  Error fetching data for {ticker}: {e}")
            
            # Try to return cached data as fallback
            cached_data = self._load_from_cache(ticker, period)
            if cached_data is not None:
                print(f"  Using cached data as fallback")
                return self._validate_data(cached_data, ticker), True
            
            # No data available
            return pd.DataFrame(), False
    
    def _filter_by_period(self, data: pd.DataFrame, period: str) -> pd.DataFrame:
        """Filter data to requested time period"""
        now = datetime.now()
        
        period_map = {
            '1d': timedelta(days=1),
            '5d': timedelta(days=5),
            '1mo': timedelta(days=30),
            '3mo': timedelta(days=90),
            '6mo': timedelta(days=180),
            '1y': timedelta(days=365),
            '2y': timedelta(days=730),
            '5y': timedelta(days=1825),
            '10y': timedelta(days=3650),
            'ytd': timedelta(days=(now - datetime(now.year, 1, 1)).days)
        }
        
        if period in period_map:
            cutoff_date = now - period_map[period]
            data = data[data.index >= cutoff_date]
        
        return data
    
    def get_ticker_info(self, ticker: str) -> Dict[str, Any]:
        """Get basic information about a ticker using Alpha Vantage company overview"""
        try:
            print(f"  Fetching company info for {ticker}...")
            
            # Wait for rate limiting
            self.rate_limiter.wait_if_needed()
            
            # Get company overview
            overview, _ = self.fd.get_company_overview(symbol=ticker.upper())
            
            if overview.empty:
                raise ValueError(f"No company info available for {ticker}")
            
            # Extract info from first row
            info = overview.iloc[0].to_dict()
            
            return {
                'symbol': ticker.upper(),
                'name': info.get('Name', 'N/A'),
                'sector': info.get('Sector', 'N/A'),
                'industry': info.get('Industry', 'N/A'),
                'market_cap': info.get('MarketCapitalization', 0),
                'currency': info.get('Currency', 'USD'),
                'exchange': info.get('Exchange', 'N/A'),
                'description': info.get('Description', 'N/A')
            }
        
        except Exception as e:
            print(f"  Error fetching info for {ticker}: {e}")
            return {'symbol': ticker.upper(), 'error': str(e)}
    
    def clear_cache(self, ticker: str = None, period: str = None):
        """Clear cache for specific ticker/period or all cache"""
        if ticker and period:
            # Clear specific ticker and period
            cache_path = self._get_cache_path(ticker.upper(), period)
            meta_path = self._get_cache_meta_path(ticker.upper(), period)
            
            if cache_path.exists():
                cache_path.unlink()
            if meta_path.exists():
                meta_path.unlink()
            
            print(f"Cleared cache for {ticker} ({period})")
        
        elif ticker:
            # Clear all periods for ticker
            ticker = ticker.upper()
            for file in self.cache_dir.glob(f"{ticker}_*"):
                file.unlink()
            print(f"Cleared all cache for {ticker}")
        
        else:
            # Clear all cache
            for file in self.cache_dir.glob("*"):
                if file.is_file():
                    file.unlink()
            print("Cleared all cache")
    
    def get_cache_info(self) -> Dict[str, Any]:
        """Get information about cached data"""
        cache_files = list(self.cache_dir.glob("*_data.csv"))
        meta_files = list(self.cache_dir.glob("*_meta.json"))
        
        total_size = sum(f.stat().st_size for f in cache_files) / (1024 * 1024)  # MB
        
        cached_tickers = set()
        for file in cache_files:
            parts = file.stem.split('_')
            if len(parts) >= 2:
                cached_tickers.add(parts[0])
        
        return {
            'cache_dir': str(self.cache_dir),
            'total_files': len(cache_files),
            'total_size_mb': round(total_size, 2),
            'cached_tickers': sorted(cached_tickers),
            'cache_duration_days': self.cache_duration_days,
            'api_calls_today': self.rate_limiter.daily_calls,
            'daily_limit': self.rate_limiter.daily_limit
        }