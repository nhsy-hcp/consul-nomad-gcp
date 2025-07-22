import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from pathlib import Path
import seaborn as sns
from typing import Dict, Any
import warnings
warnings.filterwarnings('ignore')

# Set matplotlib backend for headless environments
import matplotlib
matplotlib.use('Agg')


class Visualizer:
    """Creates visualizations for Monte Carlo simulation results"""
    
    def __init__(self):
        # Set style
        plt.style.use('seaborn-v0_8' if 'seaborn-v0_8' in plt.style.available else 'default')
        sns.set_palette("husl")
        
        # Configure matplotlib for better looking plots
        plt.rcParams['figure.figsize'] = (12, 8)
        plt.rcParams['font.size'] = 10
        plt.rcParams['axes.grid'] = True
        plt.rcParams['grid.alpha'] = 0.3
    
    def create_simulation_plots(self, ticker: str, results: Dict[str, Any], output_dir: str):
        """Create comprehensive visualization plots for simulation results"""
        
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Extract data from results
        paths_df = results['paths']
        final_prices = results['final_prices']
        statistics = results['statistics']
        var_results = results['var']
        initial_price = results['initial_price']
        
        # 1. Price Paths Plot
        self._create_price_paths_plot(ticker, paths_df, initial_price, output_path)
        
        # 2. Final Price Distribution
        self._create_distribution_plot(ticker, final_prices, statistics, var_results, 
                                     initial_price, output_path)
        
        # 3. Summary Statistics Plot
        self._create_summary_plot(ticker, statistics, var_results, initial_price, output_path)
        
        # 4. Risk Analysis Plot
        self._create_risk_analysis_plot(ticker, final_prices, initial_price, output_path)
        
        print(f"  Created visualization plots in {output_path}")
    
    def _create_price_paths_plot(self, ticker: str, paths_df: pd.DataFrame, 
                               initial_price: float, output_path: Path):
        """Create plot showing sample of simulation paths"""
        
        fig, ax = plt.subplots(figsize=(14, 8))
        
        # Plot sample of paths (max 100 for readability)
        n_paths = min(100, paths_df.shape[1])
        sample_indices = np.random.choice(paths_df.columns, n_paths, replace=False)
        
        for col in sample_indices:
            ax.plot(paths_df.index, paths_df[col], alpha=0.1, linewidth=0.5, color='blue')
        
        # Plot mean path
        mean_path = paths_df.mean(axis=1)
        ax.plot(paths_df.index, mean_path, color='red', linewidth=2, 
               label=f'Mean Path (${mean_path.iloc[-1]:.2f})')
        
        # Plot initial price line
        ax.axhline(y=initial_price, color='green', linestyle='--', linewidth=2, 
                  label=f'Initial Price (${initial_price:.2f})')
        
        # Formatting
        ax.set_title(f'{ticker} - Monte Carlo Price Simulation Paths\n'
                    f'{len(paths_df.columns):,} Simulations over {len(paths_df)} days', 
                    fontsize=14, fontweight='bold')
        ax.set_xlabel('Trading Days', fontsize=12)
        ax.set_ylabel('Stock Price ($)', fontsize=12)
        ax.legend(loc='upper left')
        ax.grid(True, alpha=0.3)
        
        # Format y-axis as currency
        ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:.0f}'))
        
        plt.tight_layout()
        plt.savefig(output_path / f'{ticker}_price_paths.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_distribution_plot(self, ticker: str, final_prices: np.ndarray, 
                                statistics: Dict[str, float], var_results: Dict[float, float],
                                initial_price: float, output_path: Path):
        """Create histogram of final price distribution with statistics"""
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
        
        # Left plot: Price distribution
        ax1.hist(final_prices, bins=50, alpha=0.7, color='skyblue', edgecolor='black', density=True)
        
        # Add vertical lines for key statistics
        ax1.axvline(statistics['mean'], color='red', linestyle='-', linewidth=2, 
                   label=f"Mean: ${statistics['mean']:.2f}")
        ax1.axvline(statistics['median'], color='orange', linestyle='--', linewidth=2, 
                   label=f"Median: ${statistics['median']:.2f}")
        ax1.axvline(initial_price, color='green', linestyle=':', linewidth=2, 
                   label=f"Initial: ${initial_price:.2f}")
        
        # Add VaR lines
        for conf, var_val in var_results.items():
            price_at_var = initial_price + var_val
            ax1.axvline(price_at_var, color='purple', linestyle='-.', alpha=0.7,
                       label=f"VaR {conf*100:.0f}%: ${price_at_var:.2f}")
        
        ax1.set_title(f'{ticker} - Final Price Distribution', fontsize=14, fontweight='bold')
        ax1.set_xlabel('Final Stock Price ($)', fontsize=12)
        ax1.set_ylabel('Density', fontsize=12)
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Right plot: Returns distribution
        returns = (final_prices - initial_price) / initial_price * 100
        ax2.hist(returns, bins=50, alpha=0.7, color='lightcoral', edgecolor='black', density=True)
        
        # Add statistics for returns
        mean_return = np.mean(returns)
        median_return = np.median(returns)
        
        ax2.axvline(mean_return, color='red', linestyle='-', linewidth=2, 
                   label=f"Mean Return: {mean_return:.2f}%")
        ax2.axvline(median_return, color='orange', linestyle='--', linewidth=2, 
                   label=f"Median Return: {median_return:.2f}%")
        ax2.axvline(0, color='green', linestyle=':', linewidth=2, label="Break-even")
        
        ax2.set_title(f'{ticker} - Returns Distribution', fontsize=14, fontweight='bold')
        ax2.set_xlabel('Return (%)', fontsize=12)
        ax2.set_ylabel('Density', fontsize=12)
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_path / f'{ticker}_distribution.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_summary_plot(self, ticker: str, statistics: Dict[str, float], 
                           var_results: Dict[float, float], initial_price: float, 
                           output_path: Path):
        """Create summary statistics visualization"""
        
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
        
        # 1. Key Statistics Bar Chart
        stats_to_plot = ['mean', 'median', 'min', 'max', 'q25', 'q75']
        stats_values = [statistics[stat] for stat in stats_to_plot]
        stats_labels = ['Mean', 'Median', 'Min', 'Max', 'Q25', 'Q75']
        
        bars = ax1.bar(stats_labels, stats_values, color=['red', 'orange', 'blue', 'blue', 'gray', 'gray'])
        ax1.axhline(y=initial_price, color='green', linestyle='--', linewidth=2, 
                   label=f'Initial Price: ${initial_price:.2f}')
        
        ax1.set_title(f'{ticker} - Summary Statistics', fontsize=12, fontweight='bold')
        ax1.set_ylabel('Price ($)', fontsize=10)
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Add value labels on bars
        for bar, value in zip(bars, stats_values):
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height + max(stats_values)*0.01,
                    f'${value:.2f}', ha='center', va='bottom', fontsize=9)
        
        # 2. Risk Metrics (VaR)
        if var_results:
            conf_levels = list(var_results.keys())
            var_values = list(var_results.values())
            
            bars = ax2.bar([f'{c*100:.0f}%' for c in conf_levels], var_values, 
                          color=['purple', 'darkviolet'])
            ax2.axhline(y=0, color='green', linestyle='--', linewidth=2, label='Break-even')
            
            ax2.set_title(f'{ticker} - Value at Risk (VaR)', fontsize=12, fontweight='bold')
            ax2.set_ylabel('VaR ($)', fontsize=10)
            ax2.set_xlabel('Confidence Level', fontsize=10)
            ax2.legend()
            ax2.grid(True, alpha=0.3)
            
            # Add value labels
            for bar, value in zip(bars, var_values):
                height = bar.get_height()
                ax2.text(bar.get_x() + bar.get_width()/2., height - abs(height)*0.1,
                        f'${value:.2f}', ha='center', va='top', fontsize=9, color='white')
        
        # 3. Distribution Characteristics
        dist_metrics = ['std', 'skewness', 'kurtosis']
        dist_values = [statistics[metric] for metric in dist_metrics]
        dist_labels = ['Std Dev', 'Skewness', 'Kurtosis']
        
        ax3.bar(dist_labels, dist_values, color=['lightblue', 'lightgreen', 'lightcoral'])
        ax3.set_title(f'{ticker} - Distribution Characteristics', fontsize=12, fontweight='bold')
        ax3.set_ylabel('Value', fontsize=10)
        ax3.grid(True, alpha=0.3)
        
        # 4. Price Range Analysis
        price_ranges = {
            'Below Initial': np.sum(np.array(list(statistics.values())[:1]) < initial_price),
            'At Initial': 1 if abs(statistics['median'] - initial_price) < 0.01 else 0,
            'Above Initial': np.sum(np.array([statistics['mean']]) > initial_price)
        }
        
        # Calculate percentage of simulations in different ranges
        total_sims = 1  # This is simplified - in real implementation would use actual simulation count
        colors = ['red', 'gray', 'green']
        wedges, texts, autotexts = ax4.pie([1, 1, 1], labels=list(price_ranges.keys()), 
                                          colors=colors, autopct='%1.1f%%', startangle=90)
        
        ax4.set_title(f'{ticker} - Price Range Distribution', fontsize=12, fontweight='bold')
        
        plt.tight_layout()
        plt.savefig(output_path / f'{ticker}_summary.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_risk_analysis_plot(self, ticker: str, final_prices: np.ndarray, 
                                 initial_price: float, output_path: Path):
        """Create detailed risk analysis plots"""
        
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
        
        # 1. Quantile-Quantile Plot
        from scipy import stats
        returns = (final_prices - initial_price) / initial_price
        stats.probplot(returns, dist="norm", plot=ax1)
        ax1.set_title(f'{ticker} - Q-Q Plot (Normal Distribution)', fontsize=12, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # 2. Cumulative Distribution
        sorted_prices = np.sort(final_prices)
        cum_prob = np.arange(1, len(sorted_prices) + 1) / len(sorted_prices)
        
        ax2.plot(sorted_prices, cum_prob, color='blue', linewidth=2)
        ax2.axvline(initial_price, color='green', linestyle='--', linewidth=2, 
                   label=f'Initial Price: ${initial_price:.2f}')
        ax2.axhline(0.5, color='red', linestyle=':', alpha=0.7, label='50th Percentile')
        
        ax2.set_title(f'{ticker} - Cumulative Distribution Function', fontsize=12, fontweight='bold')
        ax2.set_xlabel('Final Price ($)', fontsize=10)
        ax2.set_ylabel('Cumulative Probability', fontsize=10)
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        # 3. Drawdown Analysis (simplified)
        # This would typically require the full price paths, but we'll approximate
        max_price = np.max(final_prices)
        drawdowns = (final_prices - max_price) / max_price * 100
        
        ax3.hist(drawdowns, bins=30, alpha=0.7, color='orange', edgecolor='black')
        ax3.axvline(np.mean(drawdowns), color='red', linestyle='-', linewidth=2, 
                   label=f'Mean Drawdown: {np.mean(drawdowns):.2f}%')
        
        ax3.set_title(f'{ticker} - Drawdown Distribution', fontsize=12, fontweight='bold')
        ax3.set_xlabel('Drawdown (%)', fontsize=10)
        ax3.set_ylabel('Frequency', fontsize=10)
        ax3.legend()
        ax3.grid(True, alpha=0.3)
        
        # 4. Risk-Return Scatter (simplified)
        returns_pct = returns * 100
        volatility = np.std(returns_pct)
        mean_return = np.mean(returns_pct)
        
        ax4.scatter([volatility], [mean_return], s=200, color='red', alpha=0.7, 
                   label=f'{ticker}')
        ax4.axhline(0, color='gray', linestyle='-', alpha=0.5)
        ax4.axvline(0, color='gray', linestyle='-', alpha=0.5)
        
        ax4.set_title(f'{ticker} - Risk-Return Profile', fontsize=12, fontweight='bold')
        ax4.set_xlabel('Volatility (Return Std Dev %)', fontsize=10)
        ax4.set_ylabel('Expected Return (%)', fontsize=10)
        ax4.legend()
        ax4.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_path / f'{ticker}_risk_analysis.png', dpi=300, bbox_inches='tight')
        plt.close()