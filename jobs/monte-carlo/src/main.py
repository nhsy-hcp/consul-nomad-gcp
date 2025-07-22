#!/usr/bin/env python3

import argparse
import yaml
import sys
import os
from pathlib import Path

from monte_carlo import MonteCarloSimulator
from data_fetcher import DataFetcher
from visualizer import Visualizer
from gcs_uploader import GCSUploader


def load_config(config_path):
    """Load configuration from YAML file"""
    try:
        with open(config_path, 'r') as file:
            return yaml.safe_load(file)
    except FileNotFoundError:
        print(f"Config file not found: {config_path}")
        return {}
    except yaml.YAMLError as e:
        print(f"Error parsing config file: {e}")
        return {}


def get_default_dirs():
    """Get default directories based on execution environment"""
    # Check if we're running in Docker container
    if os.path.exists('/app') and os.path.exists('/app/config'):
        # Running in Docker container
        return {
            'config': '/app/config/simulation.yaml',
            'output': '/app/results',
            'cache': '/app/data'
        }
    else:
        # Running locally - use current directory subfolders
        current_dir = Path.cwd()
        return {
            'config': str(current_dir / 'config' / 'simulation.yaml'),
            'output': str(current_dir / 'results'),
            'cache': str(current_dir / 'data')
        }


def main():
    # Get environment-appropriate default directories
    defaults = get_default_dirs()
    
    parser = argparse.ArgumentParser(description='Monte Carlo Stock Price Simulation')
    
    parser.add_argument('--tickers', '-t', nargs='+', 
                       help='Stock ticker symbols (e.g., AAPL MSFT GOOGL)')
    parser.add_argument('--days', '-d', type=int, default=252,
                       help='Number of days to simulate (default: 252)')
    parser.add_argument('--simulations', '-s', type=int, default=10000,
                       help='Number of Monte Carlo simulations (default: 10000)')
    parser.add_argument('--config', '-c', 
                       default=defaults['config'],
                       help='Path to configuration file')
    parser.add_argument('--output-dir', '-o', 
                       default=defaults['output'],
                       help='Output directory for results')
    parser.add_argument('--cache-dir', 
                       default=defaults['cache'],
                       help='Directory for data cache')
    parser.add_argument('--no-plots', action='store_true',
                       help='Skip generating plots')
    parser.add_argument('--confidence-levels', nargs='+', type=float,
                       default=[0.05, 0.95],
                       help='Confidence levels for VaR calculation')
    parser.add_argument('--gcs-bucket', 
                       help='Google Cloud Storage bucket URL (e.g., gs://bucket/path)')
    parser.add_argument('--gcs-prefix', default='monte-carlo-results',
                       help='GCS object prefix for uploaded files')
    
    args = parser.parse_args()
    
    # Load configuration file
    config = load_config(args.config)
    
    # Override config with command line arguments
    if args.tickers:
        config['tickers'] = args.tickers
    if not config.get('tickers'):
        print("Error: No ticker symbols provided. Use --tickers or specify in config file.")
        sys.exit(1)
    
    config['days'] = args.days
    config['simulations'] = args.simulations
    config['output_dir'] = args.output_dir
    config['cache_dir'] = args.cache_dir
    config['confidence_levels'] = args.confidence_levels
    
    # Ensure output directories exist
    os.makedirs(args.output_dir, exist_ok=True)
    os.makedirs(args.cache_dir, exist_ok=True)
    
    print(f"Starting Monte Carlo simulation for: {', '.join(config['tickers'])}")
    print(f"Simulations: {config['simulations']}, Days: {config['days']}")
    
    try:
        # Initialize components
        data_fetcher = DataFetcher(cache_dir=args.cache_dir, config=config)
        simulator = MonteCarloSimulator()
        
        results = {}
        
        for ticker in config['tickers']:
            print(f"\nProcessing {ticker}...")
            
            # Fetch historical data
            historical_data, is_from_cache = data_fetcher.fetch_ticker_data(ticker, period="2y")
            if historical_data.empty:
                print(f"Warning: No data found for {ticker}, skipping...")
                continue
            
            # Run Monte Carlo simulation
            simulation_results = simulator.run_simulation(
                historical_data=historical_data,
                days=config['days'],
                simulations=config['simulations'],
                confidence_levels=config['confidence_levels']
            )
            
            results[ticker] = simulation_results
            
            # Save results to CSV
            output_file = os.path.join(args.output_dir, f"{ticker}_simulation.csv")
            simulation_results['paths'].to_csv(output_file, index=False)
            print(f"Results saved to: {output_file}")
            
            # Print summary statistics
            stats = simulation_results['statistics']
            print(f"Final Price Statistics:")
            print(f"  Mean: ${stats['mean']:.2f}")
            print(f"  Median: ${stats['median']:.2f}")
            print(f"  Std Dev: ${stats['std']:.2f}")
            
            var_stats = simulation_results['var']
            for level, var_value in var_stats.items():
                print(f"  VaR ({level*100:.0f}%): ${var_value:.2f}")
        
        # Generate visualizations
        if not args.no_plots and results:
            print("\nGenerating visualizations...")
            visualizer = Visualizer()
            
            for ticker, result in results.items():
                print(f"Creating plots for {ticker}...")
                visualizer.create_simulation_plots(
                    ticker=ticker,
                    results=result,
                    output_dir=args.output_dir
                )
        
        # Upload results to Google Cloud Storage if bucket is specified
        if args.gcs_bucket and results:
            print(f"\nUploading results to GCS bucket: {args.gcs_bucket}")
            try:
                gcs_uploader = GCSUploader()
                uploaded_files = gcs_uploader.upload_results_directory(
                    local_dir=args.output_dir,
                    bucket_url=args.gcs_bucket,
                    prefix=args.gcs_prefix
                )
                
                print(f"Successfully uploaded {len(uploaded_files)} files to GCS:")
                for local_file, gcs_url in uploaded_files.items():
                    print(f"  {local_file} -> {gcs_url}")
                    
            except Exception as gcs_error:
                print(f"Warning: Failed to upload results to GCS: {gcs_error}")
                print("Results are still available locally.")

        print(f"\nSimulation completed successfully!")
        if args.gcs_bucket:
            print(f"Results uploaded to: {args.gcs_bucket}")
        print(f"Local results available in: {args.output_dir}")
        
    except Exception as e:
        print(f"Error during simulation: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()