"""
Devsite to Hugo/Docsy Converter
Main conversion utility for transforming Google Devsite documentation to Hugo format
"""

import logging
import shutil
from pathlib import Path
from typing import Dict, Tuple
import yaml
import re
from utils.devsite_parser import DevsiteParser
from utils.hugo_generator import HugoGenerator
from utils.css_converter import CSSConverter

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class DevsiteToHugoConverter:
    """Main converter class for transforming Devsite documentation to Hugo/Docsy format"""

    def __init__(self, config_path: str = "config.yaml"):
        """
        Initialize the converter with configuration
        
        Args:
            config_path: Path to configuration file
        """
        self.config_path = config_path
        self.config = self._load_config()
        self.devsite_parser = DevsiteParser(self.config)
        self.hugo_generator = HugoGenerator(self.config)
        self.css_converter = CSSConverter(self.config)

    def _load_config(self) -> Dict:
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as file:
                config = yaml.safe_load(file)
                logger.info(f"Configuration loaded from {self.config_path}")
                return config
        except FileNotFoundError:
            logger.error(f"Configuration file {self.config_path} not found")
            raise
        except yaml.YAMLError as e:
            logger.error(f"Error parsing configuration file: {e}")
            raise

    def convert_documentation(self,
                              source_path: str,
                              output_path: str,
                              dry_run: bool = False,
                              incremental: bool = False) -> bool:
        """
        Convert Devsite documentation to Hugo format
        
        Args:
            source_path: Path to Devsite documentation source
            output_path: Path where Hugo site should be generated
            dry_run: If True, only validate without writing files
            incremental: If True, only convert changed files
            
        Returns:
            True if conversion successful, False otherwise
        """
        try:
            logger.info(
                f"Starting conversion from {source_path} to {output_path}")
            logger.info(f"Dry run: {dry_run}, Incremental: {incremental}")

            # Validate source path
            if not self._validate_source_path(source_path):
                return False

            # Create output directory structure
            if not dry_run:
                self._create_output_structure(output_path)

            # Parse Devsite structure
            devsite_structure = self.devsite_parser.parse_structure(
                source_path)
            if not devsite_structure:
                logger.error("Failed to parse Devsite structure")
                return False

            # Convert content files
            conversion_stats = self._convert_content_files(
                devsite_structure, source_path, output_path, dry_run,
                incremental)

            # Convert CSS and static assets
            if not dry_run:
                self._convert_assets(source_path, output_path)

            # Generate Hugo configuration
            if not dry_run:
                self._generate_hugo_config(devsite_structure, output_path)
                # Skip custom layouts when using Docsy theme
                # self._generate_layouts(output_path)
                self._generate_section_indices(devsite_structure, output_path)

            logger.info(f"Conversion completed successfully")
            logger.info(f"Conversion stats: {conversion_stats}")

            return True

        except Exception as e:
            logger.error(f"Conversion failed: {e}")
            return False

    def _validate_source_path(self, source_path: str) -> bool:
        """Validate that source path contains expected Devsite structure"""
        source_dir = Path(source_path)

        if not source_dir.exists():
            logger.error(f"Source path does not exist: {source_path}")
            return False

        # Check for key Devsite files
        expected_files = ['_book.yaml', '_index.yaml']
        for file_name in expected_files:
            file_path = source_dir / file_name
            if not file_path.exists():
                logger.warning(f"Expected Devsite file not found: {file_path}")

        return True

    def _create_output_structure(self, output_path: str) -> None:
        """Create Hugo site directory structure"""
        output_dir = Path(output_path)

        # Create main Hugo directories
        directories = [
            'content', 'static', 'assets', 'data', 'layouts', 'archetypes',
            'i18n'
        ]

        for directory in directories:
            dir_path = output_dir / directory
            dir_path.mkdir(parents=True, exist_ok=True)
            logger.debug(f"Created directory: {dir_path}")

    def _convert_content_files(self, devsite_structure: Dict, source_path: str,
                               output_path: str, dry_run: bool,
                               incremental: bool) -> Dict:
        """Convert all content files from Devsite to Hugo format"""
        conversion_stats = {
            'total_files': 0,
            'converted_files': 0,
            'skipped_files': 0,
            'error_files': 0
        }

        source_dir = Path(source_path)
        output_dir = Path(output_path)

        # Process each markdown file
        for md_file in source_dir.rglob('*.md'):
            conversion_stats['total_files'] += 1

            try:
                # Calculate relative path from source
                relative_path = md_file.relative_to(source_dir)

                # Skip if incremental and file hasn't changed
                if incremental and not self._file_needs_conversion(
                        md_file, output_dir / 'content' / relative_path):
                    conversion_stats['skipped_files'] += 1
                    continue

                # Convert file
                if self._convert_single_file(
                        md_file, output_dir / 'content' / relative_path,
                        devsite_structure, dry_run):
                    conversion_stats['converted_files'] += 1
                else:
                    conversion_stats['error_files'] += 1

            except Exception as e:
                logger.error(f"Error converting {md_file}: {e}")
                conversion_stats['error_files'] += 1

        return conversion_stats

    def _convert_single_file(self, source_file: Path, output_file: Path,
                             devsite_structure: Dict, dry_run: bool) -> bool:
        """Convert a single markdown file from Devsite to Hugo format"""
        try:
            # Read source file
            with open(source_file, 'r', encoding='utf-8') as f:
                content = f.read()

            # Parse frontmatter and content
            frontmatter, body = self._parse_markdown_file(content)

            # Convert frontmatter to Hugo format
            hugo_frontmatter = self._convert_frontmatter(
                frontmatter, source_file, devsite_structure)

            # Extract title from H1 if not present in frontmatter
            title_from_h1 = None
            h1_match = re.search(r'^# (.+)$', body, re.MULTILINE)
            if h1_match:
                title_from_h1 = h1_match.group(1).strip()

            # Use H1 title if no frontmatter title exists
            if 'title' not in hugo_frontmatter and title_from_h1:
                hugo_frontmatter['title'] = title_from_h1

            # Convert body content
            hugo_body = self._convert_body_content(body)

            # Remove duplicate H1 title if it matches frontmatter title
            if 'title' in hugo_frontmatter:
                hugo_body = self._remove_duplicate_h1_title(
                    hugo_body, hugo_frontmatter['title'])

            # Generate Hugo markdown file
            hugo_content = self._generate_hugo_markdown(
                hugo_frontmatter, hugo_body)

            if not dry_run:
                # Ensure output directory exists
                output_file.parent.mkdir(parents=True, exist_ok=True)

                # Write converted file
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(hugo_content)

                logger.debug(f"Converted: {source_file} -> {output_file}")

            return True

        except Exception as e:
            logger.error(f"Error converting file {source_file}: {e}")
            return False

    def _parse_markdown_file(self, content: str) -> Tuple[Dict, str]:
        """Parse markdown file to extract frontmatter and body"""
        # Look for YAML frontmatter
        frontmatter_pattern = r'^---\n(.*?)\n---\n(.*)'
        match = re.match(frontmatter_pattern, content, re.DOTALL)

        if match:
            frontmatter_yaml = match.group(1)
            body = match.group(2)

            try:
                frontmatter = yaml.safe_load(frontmatter_yaml)
                return frontmatter or {}, body
            except yaml.YAMLError:
                logger.warning("Failed to parse YAML frontmatter")
                return {}, content

        return {}, content

    def _convert_frontmatter(self, frontmatter: Dict, source_file: Path,
                             devsite_structure: Dict) -> Dict:
        """Convert Devsite frontmatter to Hugo format"""
        hugo_frontmatter = {}

        # Map common fields
        field_mapping = {
            'title': 'title',
            'description': 'description',
            'project_path': 'project_path',
            'book_path': 'book_path',
            'toc': 'toc'
        }

        for devsite_field, hugo_field in field_mapping.items():
            if devsite_field in frontmatter:
                hugo_frontmatter[hugo_field] = frontmatter[devsite_field]

        # Add Hugo-specific fields
        hugo_frontmatter['type'] = 'docs'  # Default to docs template
        hugo_frontmatter['weight'] = frontmatter.get('weight', 1)

        # Add title from H1 if not present in frontmatter
        if 'title' not in hugo_frontmatter:
            # Extract title from first H1 in body content if available
            # This will be passed from the body parameter later in the process
            pass

        # Determine linkTitle from title if not present
        if 'title' in hugo_frontmatter and 'linkTitle' not in hugo_frontmatter:
            hugo_frontmatter['linkTitle'] = hugo_frontmatter['title']

        # Add date if not present
        if 'date' not in hugo_frontmatter:
            hugo_frontmatter['date'] = '2024-01-01'

        return hugo_frontmatter

    def _convert_body_content(self, body: str) -> str:
        """Convert Devsite-specific content to Hugo format"""
        # Remove [TOC] directive (let Docsy handle TOC automatically)
        body = re.sub(r'\[TOC\]', '', body)

        # Remove Devsite-specific anchor ID syntax {: #anchor-name }
        body = re.sub(r'\s*\{:\s*#[^}]+\s*\}', '', body)

        # Remove Devsite-specific attribute syntax {:.class-name}
        body = re.sub(r'\s*\{:\s*\.[^}]+\s*\}', '', body)

        # Remove Jekyll include statements
        body = re.sub(r'\{\%\s*include\s+[^%]+\%\}', '', body)

        # Remove devsite-mathjax directives
        body = re.sub(r'<devsite-mathjax[^>]*>.*?</devsite-mathjax>',
                      '',
                      body,
                      flags=re.DOTALL)

        # Remove Project and Book references
        body = re.sub(r'^Project:\s*.*$', '', body, flags=re.MULTILINE)
        body = re.sub(r'^Book:\s*.*$', '', body, flags=re.MULTILINE)

        # Clean up extra whitespace and empty lines
        body = re.sub(r'\n\s*\n\s*\n', '\n\n',
                      body)  # Replace multiple empty lines with single
        body = re.sub(r'^\s*\n', '', body)  # Remove leading empty lines
        body = body.strip()  # Remove trailing whitespace

        # Convert internal links
        body = self._convert_internal_links(body)

        # Fix directory structure formatting
        body = self._fix_directory_structures(body)

        # Add language identifiers to code blocks to prevent KaTeX rendering
        body = self._add_language_identifiers_to_code_blocks(body)

        return body

    def _remove_duplicate_h1_title(self, body: str,
                                   frontmatter_title: str) -> str:
        """Remove H1 header if it matches the frontmatter title"""
        if not frontmatter_title:
            return body

        lines = body.strip().split('\n')
        if not lines:
            return body

        # Look for the first H1 in the content (not necessarily the first line)
        for i, line in enumerate(lines):
            stripped_line = line.strip()
            if stripped_line.startswith('# '):
                h1_title = stripped_line[2:].strip()

                # If titles match, remove the H1 line and any immediately following empty lines
                if h1_title.lower() == frontmatter_title.lower():
                    # Remove the H1 line
                    remaining_lines = lines[:i] + lines[i + 1:]

                    # Remove any empty lines immediately following where the H1 was
                    while i < len(remaining_lines
                                  ) and remaining_lines[i].strip() == '':
                        remaining_lines.pop(i)

                    return '\n'.join(remaining_lines)
                break  # Stop after finding the first H1

        return body

    def _convert_internal_links(self, content: str) -> str:
        """Convert internal links to Hugo format"""
        # Pattern for markdown links - handle multi-line links
        link_pattern = r'\[([^\]]+)\]\(([^)]+)\)'

        def replace_link(match):
            link_text = match.group(1)
            link_url = match.group(2)

            # Clean up any whitespace and newlines in the URL
            link_url = re.sub(r'\s+', '', link_url)

            # Skip external links
            if link_url.startswith(
                ('http://', 'https://', 'mailto:', 'tel:', 'ftp://')):
                return match.group(0)

            # Skip anchor links
            if link_url.startswith('#'):
                return match.group(0)

            # Handle relative links to .md files
            if link_url.endswith('.md'):
                # Normalize the path
                normalized_path = link_url.replace('.md', '')
                # Remove leading './' if present
                if normalized_path.startswith('./'):
                    normalized_path = normalized_path[2:]
                # Remove leading '/' if present (absolute paths within site)
                if normalized_path.startswith('/'):
                    normalized_path = normalized_path[1:]

                # Use simple relative links to avoid shortcode issues
                return f'[{link_text}](/{normalized_path}/)'

            # Handle relative links to directories (assume they have index pages)
            if '/' in link_url and not '.' in link_url.split('/')[-1]:
                # This looks like a directory link, convert to Hugo section link
                normalized_path = link_url.rstrip('/')
                if normalized_path.startswith('./'):
                    normalized_path = normalized_path[2:]
                if normalized_path.startswith('/'):
                    normalized_path = normalized_path[1:]

                return f'[{link_text}](/{normalized_path}/)'

            # Return original for other cases (images, other assets, etc.)
            return match.group(0)

        return re.sub(link_pattern, replace_link, content, flags=re.DOTALL)

    def _fix_directory_structures(self, content: str) -> str:
        """Fix directory structure formatting to use proper code blocks"""
        # Pattern to match directory structures with Unicode tree characters
        tree_pattern = r'(following directory structure:?\s*(?:\n|```?)?\s*)(└.*?(?:\n.*?[├└│].*?)*)'

        def replace_tree(match):
            intro = match.group(1).strip()
            tree_content = match.group(2).strip()

            # Use plain text code block without syntax highlighting
            return f"{intro}\n\n```text\n{tree_content}\n```"

        content = re.sub(tree_pattern,
                         replace_tree,
                         content,
                         flags=re.DOTALL | re.MULTILINE)

        # Also handle cases where tree structures are inline without proper formatting
        inline_tree_pattern = r'(```\s*)(└.*?(?:\n.*?[├└│].*?)*)(```)'

        def fix_inline_tree(match):
            start = "```text"
            tree_content = match.group(2)
            end = "```"

            # Clean up the tree content
            tree_content = tree_content.strip()

            return f"{start}\n{tree_content}\n{end}"

        content = re.sub(inline_tree_pattern,
                         fix_inline_tree,
                         content,
                         flags=re.DOTALL)

        return content

    def _add_language_identifiers_to_code_blocks(self, content: str) -> str:
        """Add language identifiers to code blocks without them to prevent KaTeX rendering issues"""

        def determine_language(code_content):
            """Determine appropriate language identifier based on code content"""
            code_lower = code_content.lower().strip()

            # Check for common patterns
            if 'load(' in code_content or 'cc_library(' in code_content or 'java_library(' in code_content:
                return 'starlark'  # Bazel/Starlark (was incorrectly 'python')
            elif code_content.startswith('/') or 'BUILD' in code_content:
                return 'text'  # File paths and directory structures
            elif any(keyword in code_lower
                     for keyword in ['def ', 'class ', 'import ', 'from ']):
                return 'python'
            elif any(keyword in code_lower
                     for keyword in ['function', 'var ', 'const ', 'let ']):
                return 'javascript'
            elif any(keyword in code_lower
                     for keyword in ['#include', 'int main', 'std::']):
                return 'cpp'
            elif any(keyword in code_lower
                     for keyword in ['public class', 'import java']):
                return 'java'
            elif '$' in code_content or 'echo' in code_lower or code_content.startswith(
                    '#!/'):
                return 'bash'
            else:
                return 'text'  # Default for unknown content

        # Clean up any text that appears after closing backticks
        # This ensures nothing ever appears after ```
        content = re.sub(r'```[^\n\r]*(\n|$)', '```\n', content)

        # Pattern to match code blocks that start with ``` followed by only whitespace and newline
        # This ensures we only match code blocks WITHOUT language identifiers
        pattern = r'```\s*\n(.*?)\n```'

        def replace_code_block(match):
            code_content = match.group(1)
            language = determine_language(code_content)
            return f'```{language}\n{code_content}\n```'

        # Apply the replacement using multiline and dotall flags
        result = re.sub(pattern,
                        replace_code_block,
                        content,
                        flags=re.MULTILINE | re.DOTALL)

        return result

    def _generate_hugo_markdown(self, frontmatter: Dict, body: str) -> str:
        """Generate Hugo markdown file with frontmatter and body"""
        # Convert frontmatter to YAML
        frontmatter_yaml = yaml.dump(frontmatter, default_flow_style=False)

        return f"---\n{frontmatter_yaml}---\n\n{body}"

    def _file_needs_conversion(self, source_file: Path,
                               output_file: Path) -> bool:
        """Check if file needs conversion (for incremental updates)"""
        if not output_file.exists():
            return True

        # Compare modification times
        return source_file.stat().st_mtime > output_file.stat().st_mtime

    def _convert_assets(self, source_path: str, output_path: str) -> None:
        """Convert CSS and static assets"""
        source_dir = Path(source_path)
        output_dir = Path(output_path)

        # Convert CSS files
        css_files = list(source_dir.rglob('*.css'))
        for css_file in css_files:
            self.css_converter.convert_css_file(css_file,
                                                output_dir / 'assets' / 'scss')

        # Copy static assets (images, etc.)
        static_extensions = ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico']
        for ext in static_extensions:
            for asset_file in source_dir.rglob(f'*{ext}'):
                relative_path = asset_file.relative_to(source_dir)
                output_asset = output_dir / 'static' / relative_path
                output_asset.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(asset_file, output_asset)
                logger.debug(f"Copied asset: {asset_file} -> {output_asset}")

    def _generate_hugo_config(self, devsite_structure: Dict,
                              output_path: str) -> None:
        """Generate Hugo configuration file"""
        self.hugo_generator.generate_config(devsite_structure, output_path)

    def _generate_layouts(self, output_path: str) -> None:
        """Generate Hugo layout templates"""
        self.hugo_generator.generate_layouts(output_path)

    def _generate_section_indices(self, devsite_structure: Dict,
                                  output_path: str) -> None:
        """Generate _index.md files for Hugo sections"""
        self.hugo_generator.generate_section_indices(devsite_structure,
                                                     output_path)

    def validate_conversion(self, output_path: str) -> bool:
        """Validate the converted Hugo site structure"""
        output_dir = Path(output_path)

        # Check required files exist
        required_files = ['hugo.yaml', 'content/_index.md']

        for file_path in required_files:
            if not (output_dir / file_path).exists():
                logger.error(f"Required file missing: {file_path}")
                return False

        # Check content directory structure
        content_dir = output_dir / 'content'
        if not content_dir.exists():
            logger.error("Content directory missing")
            return False

        logger.info("Validation passed")
        return True
