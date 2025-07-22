import numpy as np
import pandas as pd
from typing import Dict, List, Any
import warnings
warnings.filterwarnings('ignore')


class MonteCarloSimulator:
    """Monte Carlo simulation engine for stock price modeling"""
    
    def __init__(self):
        self.random_state = np.random.RandomState(42)  # For reproducible results
    
    def calculate_returns(self, prices: pd.Series) -> pd.Series:
        """Calculate daily returns from price series"""
        return prices.pct_change().dropna()
    
    def estimate_parameters(self, returns: pd.Series) -> Dict[str, float]:
        """Estimate drift and volatility from historical returns"""
        daily_returns = returns.dropna()
        
        # Calculate annualized parameters
        mu = daily_returns.mean() * 252  # Annualized drift
        sigma = daily_returns.std() * np.sqrt(252)  # Annualized volatility
        
        # Daily parameters for simulation
        daily_mu = mu / 252
        daily_sigma = sigma / np.sqrt(252)
        
        return {
            'annual_drift': mu,
            'annual_volatility': sigma,
            'daily_drift': daily_mu,
            'daily_volatility': daily_sigma
        }
    
    def geometric_brownian_motion(self, S0: float, mu: float, sigma: float, 
                                 T: int, N: int) -> np.ndarray:
        """
        Generate stock price paths using Geometric Brownian Motion
        
        Parameters:
        S0: Initial stock price
        mu: Daily drift
        sigma: Daily volatility
        T: Number of time steps (days)
        N: Number of simulations
        """
        dt = 1  # Daily time step
        
        # Generate random normal variables
        dW = self.random_state.normal(0, np.sqrt(dt), size=(N, T))
        
        # Initialize price paths
        paths = np.zeros((N, T + 1))
        paths[:, 0] = S0
        
        # Generate price paths using GBM formula
        for t in range(1, T + 1):
            paths[:, t] = paths[:, t-1] * np.exp(
                (mu - 0.5 * sigma**2) * dt + sigma * dW[:, t-1]
            )
        
        return paths
    
    def calculate_var(self, final_prices: np.ndarray, initial_price: float, 
                      confidence_levels: List[float]) -> Dict[float, float]:
        """Calculate Value at Risk (VaR) for given confidence levels"""
        var_results = {}
        
        for confidence in confidence_levels:
            var_percentile = (1 - confidence) * 100
            var_value = np.percentile(final_prices, var_percentile)
            var_results[confidence] = var_value
        
        return var_results
    
    def calculate_statistics(self, final_prices: np.ndarray) -> Dict[str, float]:
        """Calculate summary statistics for final prices"""
        return {
            'mean': np.mean(final_prices),
            'median': np.median(final_prices),
            'std': np.std(final_prices),
            'min': np.min(final_prices),
            'max': np.max(final_prices),
            'q25': np.percentile(final_prices, 25),
            'q75': np.percentile(final_prices, 75),
            'skewness': self._calculate_skewness(final_prices),
            'kurtosis': self._calculate_kurtosis(final_prices)
        }
    
    def _calculate_skewness(self, data: np.ndarray) -> float:
        """Calculate skewness of the data"""
        mean = np.mean(data)
        std = np.std(data)
        return np.mean(((data - mean) / std) ** 3)
    
    def _calculate_kurtosis(self, data: np.ndarray) -> float:
        """Calculate kurtosis of the data"""
        mean = np.mean(data)
        std = np.std(data)
        return np.mean(((data - mean) / std) ** 4) - 3
    
    def run_simulation(self, historical_data: pd.DataFrame, days: int, 
                      simulations: int, confidence_levels: List[float]) -> Dict[str, Any]:
        """
        Run complete Monte Carlo simulation
        
        Parameters:
        historical_data: DataFrame with 'Close' price column
        days: Number of days to simulate
        simulations: Number of Monte Carlo paths
        confidence_levels: List of confidence levels for VaR
        """
        
        # Extract closing prices
        if 'Close' not in historical_data.columns:
            raise ValueError("Historical data must contain 'Close' column")
        
        prices = historical_data['Close'].dropna()
        if len(prices) < 30:  # Minimum data requirement
            raise ValueError("Insufficient historical data (need at least 30 days)")
        
        # Calculate returns and estimate parameters
        returns = self.calculate_returns(prices)
        params = self.estimate_parameters(returns)
        
        # Get initial price (most recent closing price)
        initial_price = prices.iloc[-1]
        
        print(f"  Initial Price: ${initial_price:.2f}")
        print(f"  Annual Drift: {params['annual_drift']:.4f}")
        print(f"  Annual Volatility: {params['annual_volatility']:.4f}")
        
        # Run Monte Carlo simulation
        price_paths = self.geometric_brownian_motion(
            S0=initial_price,
            mu=params['daily_drift'],
            sigma=params['daily_volatility'],
            T=days,
            N=simulations
        )
        
        # Extract final prices
        final_prices = price_paths[:, -1]
        
        # Calculate statistics
        statistics = self.calculate_statistics(final_prices)
        var_results = self.calculate_var(final_prices, initial_price, confidence_levels)
        
        # Create results DataFrame
        paths_df = pd.DataFrame(price_paths.T)
        paths_df.columns = [f'Simulation_{i+1}' for i in range(simulations)]
        paths_df.index.name = 'Day'
        
        return {
            'paths': paths_df,
            'final_prices': final_prices,
            'statistics': statistics,
            'var': var_results,
            'parameters': params,
            'initial_price': initial_price,
            'simulations': simulations,
            'days': days
        }