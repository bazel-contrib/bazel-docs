"""
Command Line Interface for Devsite to Hugo Converter
"""

import sys
import logging
import click
from pathlib import Path
from devsite_to_hugo_converter import DevsiteToHugoConverter

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@click.group()
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose logging')
@click.option('--config', '-c', default='config.yaml', help='Configuration file path')
@click.pass_context
def cli(ctx, verbose, config):
    """Devsite to Hugo/Docsy Converter CLI"""
    if verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Ensure context object exists
    ctx.ensure_object(dict)
    ctx.obj['config'] = config
    ctx.obj['verbose'] = verbose

@cli.command()
@click.option('--source', '-s', required=True, help='Source directory containing Devsite documentation')
@click.option('--output', '-o', required=True, help='Output directory for Hugo site')
@click.option('--dry-run', is_flag=True, help='Validate conversion without writing files')
@click.option('--incremental', is_flag=True, help='Only convert changed files')
@click.pass_context
def convert(ctx, source, output, dry_run, incremental):
    """Convert Devsite documentation to Hugo format"""
    try:
        # Initialize converter
        converter = DevsiteToHugoConverter(ctx.obj['config'])
        
        # Validate source directory
        if not Path(source).exists():
            click.echo(f"Error: Source directory does not exist: {source}", err=True)
            sys.exit(1)
        
        # Create output directory if it doesn't exist
        if not dry_run:
            Path(output).mkdir(parents=True, exist_ok=True)
        
        click.echo(f"Converting Devsite documentation from {source} to {output}")
        if dry_run:
            click.echo("Running in dry-run mode - no files will be written")
        if incremental:
            click.echo("Running in incremental mode - only changed files will be converted")
        
        # Perform conversion
        success = converter.convert_documentation(source, output, dry_run, incremental)
        
        if success:
            click.echo("✅ Conversion completed successfully!")
            if not dry_run:
                click.echo(f"Hugo site generated at: {output}")
        else:
            click.echo("❌ Conversion failed!", err=True)
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"Conversion failed: {e}")
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

@cli.command()
@click.pass_context
def info(ctx):
    """Display converter information and configuration"""
    try:
        converter = DevsiteToHugoConverter(ctx.obj['config'])
        
        click.echo("Devsite to Hugo Converter")
        click.echo("=" * 40)
        click.echo(f"Configuration file: {ctx.obj['config']}")
        click.echo(f"Target Hugo site: {converter.config['hugo']['title']}")
        click.echo(f"Base URL: {converter.config['hugo']['baseURL']}")
        click.echo(f"Source repository: {converter.config['source_repo']['owner']}/{converter.config['source_repo']['name']}")
        click.echo(f"Source branch: {converter.config['source_repo']['branch']}")
        click.echo(f"Source path: {converter.config['source_repo']['path']}")
        click.echo()
        click.echo("Content mapping:")
        for section, mapping in converter.config['content_mapping'].items():
            click.echo(f"  {section}: {mapping['type']} (weight: {mapping['weight']})")
        
    except Exception as e:
        logger.error(f"Info command failed: {e}")
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

if __name__ == '__main__':
    cli()
