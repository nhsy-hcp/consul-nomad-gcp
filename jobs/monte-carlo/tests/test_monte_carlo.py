import pytest
import numpy as np
import pandas as pd
import sys
from pathlib import Path

# Add src directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from monte_carlo import MonteCarloSimulator


class TestMonteCarloSimulator:
    
    @pytest.fixture
    def simulator(self):
        return MonteCarloSimulator()
    
    @pytest.fixture
    def sample_prices(self):
        # Create sample price data
        dates = pd.date_range('2023-01-01', periods=100, freq='D')
        prices = 100 + np.cumsum(np.random.randn(100) * 0.5)  # Simple random walk
        return pd.Series(prices, index=dates, name='Close')
    
    @pytest.fixture
    def sample_dataframe(self, sample_prices):
        return pd.DataFrame({'Close': sample_prices})
    
    def test_calculate_returns(self, simulator, sample_prices):
        returns = simulator.calculate_returns(sample_prices)
        
        # Check that returns are calculated correctly
        assert len(returns) == len(sample_prices) - 1
        assert not returns.isna().any()
        
        # Check first return calculation manually
        expected_first_return = (sample_prices.iloc[1] - sample_prices.iloc[0]) / sample_prices.iloc[0]
        assert abs(returns.iloc[0] - expected_first_return) < 1e-10
    
    def test_estimate_parameters(self, simulator, sample_prices):
        returns = simulator.calculate_returns(sample_prices)
        params = simulator.estimate_parameters(returns)
        
        # Check that all required parameters are present
        required_keys = ['annual_drift', 'annual_volatility', 'daily_drift', 'daily_volatility']
        for key in required_keys:
            assert key in params
            assert isinstance(params[key], (int, float))
        
        # Check that daily parameters are roughly annual/252
        assert abs(params['daily_drift'] * 252 - params['annual_drift']) < 1e-10
        assert abs(params['daily_volatility'] * np.sqrt(252) - params['annual_volatility']) < 1e-6
    
    def test_geometric_brownian_motion(self, simulator):
        S0 = 100.0
        mu = 0.0001  # Daily drift
        sigma = 0.01  # Daily volatility
        T = 10  # 10 days
        N = 100  # 100 simulations
        
        paths = simulator.geometric_brownian_motion(S0, mu, sigma, T, N)
        
        # Check dimensions
        assert paths.shape == (N, T + 1)
        
        # Check initial prices
        assert np.all(paths[:, 0] == S0)
        
        # Check that prices are positive
        assert np.all(paths > 0)
    
    def test_calculate_var(self, simulator):
        final_prices = np.array([90, 95, 100, 105, 110])
        initial_price = 100.0
        confidence_levels = [0.05, 0.95]
        
        var_results = simulator.calculate_var(final_prices, initial_price, confidence_levels)
        
        # Check that VaR values are returned for each confidence level
        assert len(var_results) == 2
        assert 0.05 in var_results
        assert 0.95 in var_results
        
        # VaR (5%) represents upside potential (95th percentile)
        # VaR (95%) represents downside risk (5th percentile)
        assert var_results[0.05] >= var_results[0.95]
    
    def test_calculate_statistics(self, simulator):
        final_prices = np.array([90, 95, 100, 105, 110])
        
        stats = simulator.calculate_statistics(final_prices)
        
        # Check that all required statistics are present
        required_stats = ['mean', 'median', 'std', 'min', 'max', 'q25', 'q75', 'skewness', 'kurtosis']
        for stat in required_stats:
            assert stat in stats
            assert isinstance(stats[stat], (int, float, np.integer, np.floating))
        
        # Check some basic properties
        assert stats['mean'] == 100.0
        assert stats['median'] == 100.0
        assert stats['min'] == 90
        assert stats['max'] == 110
        assert stats['q25'] == 95.0
        assert stats['q75'] == 105.0
    
    def test_run_simulation_basic(self, simulator, sample_dataframe):
        results = simulator.run_simulation(
            historical_data=sample_dataframe,
            days=10,
            simulations=100,
            confidence_levels=[0.05, 0.95]
        )
        
        # Check that all required results are present
        required_keys = ['paths', 'final_prices', 'statistics', 'var', 'parameters', 
                        'initial_price', 'simulations', 'days']
        for key in required_keys:
            assert key in results
        
        # Check dimensions
        assert results['paths'].shape == (11, 100)  # 10 days + initial = 11 rows, 100 simulations
        assert len(results['final_prices']) == 100
        
        # Check that initial price is set correctly
        assert results['initial_price'] == sample_dataframe['Close'].iloc[-1]
        
        # Check that parameters are estimated
        assert isinstance(results['parameters'], dict)
        
        # Check VaR results
        assert len(results['var']) == 2
    
    def test_run_simulation_insufficient_data(self, simulator):
        # Create DataFrame with insufficient data (< 30 days)
        short_data = pd.DataFrame({
            'Close': [100, 101, 102]
        })
        
        with pytest.raises(ValueError, match="Insufficient historical data"):
            simulator.run_simulation(
                historical_data=short_data,
                days=10,
                simulations=100,
                confidence_levels=[0.95]
            )
    
    def test_run_simulation_missing_close_column(self, simulator):
        # DataFrame without 'Close' column
        bad_data = pd.DataFrame({
            'Price': [100, 101, 102, 103]
        })
        
        with pytest.raises(ValueError, match="Historical data must contain 'Close' column"):
            simulator.run_simulation(
                historical_data=bad_data,
                days=10,
                simulations=100,
                confidence_levels=[0.95]
            )
    
    def test_skewness_calculation(self, simulator):
        # Test with symmetric data (should have near-zero skewness)
        symmetric_data = np.array([1, 2, 3, 4, 5])
        skewness = simulator._calculate_skewness(symmetric_data)
        assert abs(skewness) < 1e-10
        
        # Test with right-skewed data
        right_skewed = np.array([1, 1, 1, 5, 10])
        skewness = simulator._calculate_skewness(right_skewed)
        assert skewness > 0
    
    def test_kurtosis_calculation(self, simulator):
        # Test kurtosis calculation (excess kurtosis, so normal distribution should be ~0)
        normal_like = np.random.normal(0, 1, 1000)
        kurtosis = simulator._calculate_kurtosis(normal_like)
        # Should be close to 0 for normal distribution (excess kurtosis)
        assert -1 < kurtosis < 1