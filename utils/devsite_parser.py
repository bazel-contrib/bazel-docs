"""
Devsite Parser Module
Handles parsing of Google Devsite documentation structure
"""

import yaml
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any

logger = logging.getLogger(__name__)

class DevsiteParser:
    """Parser for Google Devsite documentation structure"""
    
    def __init__(self, config: Dict):
        """Initialize parser with configuration"""
        self.config = config
        
    def parse_structure(self, source_path: str) -> Optional[Dict]:
        """
        Parse the entire Devsite structure
        
        Args:
            source_path: Path to Devsite source directory
            
        Returns:
            Dictionary containing parsed structure or None if parsing fails
        """
        try:
            source_dir = Path(source_path)
            
            # Parse main navigation files
            book_config = self._parse_book_yaml(source_dir / '_book.yaml')
            index_config = self._parse_index_yaml(source_dir / '_index.yaml')
            
            # Discover content structure
            content_structure = self._discover_content_structure(source_dir)
            
            # Build unified structure
            structure = {
                'book_config': book_config,
                'index_config': index_config,
                'content_structure': content_structure,
                'sections': self._extract_sections(content_structure),
                'navigation': self._build_navigation_tree(book_config, content_structure)
            }
            
            logger.info(f"Parsed Devsite structure with {len(structure['sections'])} sections")
            return structure
            
        except Exception as e:
            logger.error(f"Failed to parse Devsite structure: {e}")
            return None
    
    def _parse_book_yaml(self, file_path: Path) -> Dict:
        """Parse _book.yaml file"""
        if not file_path.exists():
            logger.warning(f"Book config file not found: {file_path}")
            return {}
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
                logger.debug(f"Parsed book config: {file_path}")
                return config or {}
        except Exception as e:
            logger.error(f"Error parsing book config {file_path}: {e}")
            return {}
    
    def _parse_index_yaml(self, file_path: Path) -> Dict:
        """Parse _index.yaml file"""
        if not file_path.exists():
            logger.warning(f"Index config file not found: {file_path}")
            return {}
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
                logger.debug(f"Parsed index config: {file_path}")
                return config or {}
        except Exception as e:
            logger.error(f"Error parsing index config {file_path}: {e}")
            return {}
    
    def _discover_content_structure(self, source_dir: Path) -> Dict:
        """Discover the content structure by scanning directories"""
        structure = {}
        
        # Scan all directories
        for item in source_dir.iterdir():
            if item.is_dir() and not item.name.startswith('.'):
                section_info = self._analyze_section(item)
                if section_info:
                    structure[item.name] = section_info
        
        return structure
    
    def _analyze_section(self, section_dir: Path) -> Optional[Dict]:
        """Analyze a section directory"""
        section_info = {
            'path': str(section_dir),
            'name': section_dir.name,
            'files': [],
            'subsections': {},
            'config': {}
        }
        
        # Look for section-specific config files
        section_book = section_dir / '_book.yaml'
        section_index = section_dir / '_index.yaml'
        
        if section_book.exists():
            section_info['config']['book'] = self._parse_book_yaml(section_book)
        
        if section_index.exists():
            section_info['config']['index'] = self._parse_index_yaml(section_index)
        
        # Scan for markdown files
        for md_file in section_dir.rglob('*.md'):
            relative_path = md_file.relative_to(section_dir)
            file_info = {
                'path': str(md_file),
                'relative_path': str(relative_path),
                'name': md_file.name,
                'title': self._extract_title_from_file(md_file)
            }
            section_info['files'].append(file_info)
        
        # Scan for subsections
        for item in section_dir.iterdir():
            if item.is_dir() and not item.name.startswith('.'):
                subsection_info = self._analyze_section(item)
                if subsection_info:
                    section_info['subsections'][item.name] = subsection_info
        
        return section_info
    
    def _extract_title_from_file(self, file_path: Path) -> str:
        """Extract title from markdown file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Look for YAML frontmatter title
            if content.startswith('---\n'):
                end_pos = content.find('\n---\n', 4)
                if end_pos != -1:
                    frontmatter_content = content[4:end_pos]
                    try:
                        frontmatter = yaml.safe_load(frontmatter_content)
                        if frontmatter and 'title' in frontmatter:
                            return frontmatter['title']
                    except yaml.YAMLError:
                        pass
            
            # Look for first H1 heading
            lines = content.split('\n')
            for line in lines:
                if line.startswith('# '):
                    return line[2:].strip()
            
            # Fallback to filename
            return file_path.stem.replace('-', ' ').replace('_', ' ').title()
            
        except Exception as e:
            logger.debug(f"Could not extract title from {file_path}: {e}")
            return file_path.stem.replace('-', ' ').replace('_', ' ').title()
    
    def _extract_sections(self, content_structure: Dict) -> List[Dict]:
        """Extract section information for Hugo mapping"""
        sections = []
        
        for section_name, section_info in content_structure.items():
            # Get mapping from config
            mapping = self.config.get('content_mapping', {}).get(section_name, {})
            
            section_data = {
                'name': section_name,
                'title': section_info.get('config', {}).get('index', {}).get('title', 
                                                                               section_name.replace('-', ' ').title()),
                'type': mapping.get('type', 'docs'),
                'weight': mapping.get('weight', 100),
                'path': section_info['path'],
                'files': section_info['files'],
                'subsections': section_info['subsections']
            }
            
            sections.append(section_data)
        
        # Sort by weight
        sections.sort(key=lambda x: x['weight'])
        
        return sections
    
    def _build_navigation_tree(self, book_config: Dict, content_structure: Dict) -> Dict:
        """Build navigation tree from book config and content structure"""
        navigation = {
            'main': [],
            'sections': {}
        }
        
        # Process book configuration if available
        if 'toc' in book_config:
            navigation['main'] = self._process_toc_entries(book_config['toc'])
        
        # Process sections
        for section_name, section_info in content_structure.items():
            nav_entry = {
                'title': section_info.get('config', {}).get('index', {}).get('title', 
                                                                               section_name.replace('-', ' ').title()),
                'path': f'/{section_name}/',
                'children': []
            }
            
            # Add files to navigation
            for file_info in section_info['files']:
                if file_info['name'] != '_index.md':
                    nav_entry['children'].append({
                        'title': file_info['title'],
                        'path': f"/{section_name}/{file_info['relative_path'].replace('.md', '')}"
                    })
            
            navigation['sections'][section_name] = nav_entry
        
        return navigation
    
    def _process_toc_entries(self, toc_entries: List[Any]) -> List[Dict]:
        """Process table of contents entries from book config"""
        processed_entries = []
        
        for entry in toc_entries:
            if isinstance(entry, dict):
                processed_entry = {
                    'title': entry.get('title', 'Untitled'),
                    'path': entry.get('path', ''),
                    'children': []
                }
                
                if 'section' in entry:
                    processed_entry['children'] = self._process_toc_entries(entry['section'])
                
                processed_entries.append(processed_entry)
        
        return processed_entries
