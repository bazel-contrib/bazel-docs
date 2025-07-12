"""
Command Line Interface for Devsite to Hugo Converter
"""

import os
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
@click.option('--path', '-p', required=True, help='Path to Hugo site to validate')
@click.pass_context
def validate(ctx, path):
    """Validate converted Hugo site structure"""
    try:
        # Initialize converter
        converter = DevsiteToHugoConverter(ctx.obj['config'])
        
        # Validate site
        click.echo(f"Validating Hugo site at: {path}")
        
        if not Path(path).exists():
            click.echo(f"Error: Path does not exist: {path}", err=True)
            sys.exit(1)
        
        success = converter.validate_conversion(path)
        
        if success:
            click.echo("✅ Validation passed!")
        else:
            click.echo("❌ Validation failed!", err=True)
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"Validation failed: {e}")
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

@cli.command()
@click.option('--owner', default='bazelbuild', help='GitHub repository owner')
@click.option('--repo', default='bazel', help='GitHub repository name')
@click.option('--branch', default='master', help='GitHub repository branch')
@click.option('--path', default='site/en', help='Path within repository to monitor')
@click.pass_context
def monitor(ctx, owner, repo, branch, path):
    """Monitor GitHub repository for changes"""
    try:
        from utils.github_api import GitHubAPI
        
        # Get GitHub token from environment
        token = os.getenv('GITHUB_TOKEN')
        if not token:
            click.echo("Error: GITHUB_TOKEN environment variable not set", err=True)
            sys.exit(1)
        
        # Initialize GitHub API
        github_api = GitHubAPI(token)
        
        click.echo(f"Monitoring {owner}/{repo} ({branch}) for changes in {path}")
        
        # Get latest commit
        latest_commit = github_api.get_latest_commit(owner, repo, branch, path)
        
        if latest_commit:
            click.echo(f"Latest commit: {latest_commit['sha']}")
            click.echo(f"Message: {latest_commit['message']}")
            click.echo(f"Author: {latest_commit['author']}")
            click.echo(f"Date: {latest_commit['date']}")
        else:
            click.echo("No commits found")
            
    except Exception as e:
        logger.error(f"Monitoring failed: {e}")
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

@cli.command()
@click.option('--source', '-s', required=True, help='Source directory containing Devsite documentation')
@click.option('--output', '-o', required=True, help='Output directory for Hugo site')
@click.option('--build', is_flag=True, help='Build Hugo site after conversion')
@click.option('--serve', is_flag=True, help='Serve Hugo site after conversion (implies --build)')
@click.pass_context
def full_pipeline(ctx, source, output, build, serve):
    """Run full conversion pipeline with optional build and serve"""
    try:
        # Initialize converter
        converter = DevsiteToHugoConverter(ctx.obj['config'])
        
        # Step 1: Convert
        click.echo("Step 1: Converting Devsite documentation to Hugo format")
        success = converter.convert_documentation(source, output, dry_run=False, incremental=False)
        
        if not success:
            click.echo("❌ Conversion failed!", err=True)
            sys.exit(1)
        
        click.echo("✅ Conversion completed successfully!")
        
        # Step 2: Validate
        click.echo("Step 2: Validating Hugo site structure")
        success = converter.validate_conversion(output)
        
        if not success:
            click.echo("❌ Validation failed!", err=True)
            sys.exit(1)
        
        click.echo("✅ Validation passed!")
        
        # Step 3: Build (if requested)
        if build or serve:
            click.echo("Step 3: Building Hugo site")
            
            import subprocess
            
            # Change to output directory
            os.chdir(output)
            
            # Initialize Hugo modules
            subprocess.run(['hugo', 'mod', 'init', 'github.com/example/bazel-docs'], check=True)
            subprocess.run(['hugo', 'mod', 'get', 'github.com/google/docsy@latest'], check=True)
            subprocess.run(['hugo', 'mod', 'get', 'github.com/google/docsy/dependencies@latest'], check=True)
            
            # Build site
            subprocess.run(['hugo', '--minify'], check=True)
            
            click.echo("✅ Hugo site built successfully!")
            
            # Step 4: Serve (if requested)
            if serve:
                click.echo("Step 4: Serving Hugo site")
                click.echo("Hugo site will be available at http://localhost:1313")
                click.echo("Press Ctrl+C to stop the server")
                
                subprocess.run(['hugo', 'server', '--bind', '0.0.0.0', '--port', '5000'], check=True)
                
    except subprocess.CalledProcessError as e:
        click.echo(f"❌ Hugo command failed: {e}", err=True)
        sys.exit(1)
    except Exception as e:
        logger.error(f"Pipeline failed: {e}")
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
