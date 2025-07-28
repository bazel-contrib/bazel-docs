"""
Hugo Generator Module
Handles generation of Hugo site structure and configuration
"""

import os
import logging
from pathlib import Path
from typing import Dict, List, Optional
import yaml
from jinja2 import Environment, FileSystemLoader

logger = logging.getLogger(__name__)

TUTORIALS_DESCRIPTION = 'Tutorials to guide you through Bazel specific examples'
HOW_TO_GUIDES_DESCRIPTION = 'Guides for specific tasks and issues your will encounter'
EXPLANATIONS_DESCRIPTION = 'Understanding Bazel concepts and features'
REFERENCE_DESCRIPTION = 'Reference materials, API documentation, and good information for rules authors'

class HugoGenerator:
    """Generator for Hugo site structure and configuration"""
    
    def __init__(self, config: Dict):
        """Initialize generator with configuration"""
        self.config = config
        self.template_env = Environment(loader=FileSystemLoader('templates'))
        
    def generate_config(self, output_path: str) -> bool:
        """
        Generate Hugo configuration file
        
        Args:
            devsite_structure: Parsed Devsite structure
            output_path: Output directory path
            
        Returns:
            True if successful, False otherwise
        """
        try:
            output_dir = Path(output_path)
                        
            with open(Path('config.yaml'), 'r') as f:
                context = yaml.safe_load(f)
            # Render Hugo configuration
            template = self.template_env.get_template('hugo_config.yaml.jinja2')
            config_content = template.render(context)
            
            # Write configuration file
            config_file = output_dir / 'hugo.yaml'
            with open(config_file, 'w', encoding='utf-8') as f:
                f.write(config_content)
            
            logger.info(f"Generated Hugo configuration: {config_file}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to generate Hugo configuration: {e}")
            return False
    
    def generate_section_indices(self, devsite_structure: Dict, output_path: str) -> bool:
        """
        Generate _index.md files for Hugo sections
        
        Args:
            devsite_structure: Parsed Devsite structure
            output_path: Output directory path
            
        Returns:
            True if successful, False otherwise
        """
        try:
            output_dir = Path(output_path)
            content_dir = output_dir / 'content'
            
            # Generate main index
            self._generate_main_index(content_dir, devsite_structure)
            
            # Generate section indices
            for section in devsite_structure['sections']:
                self._generate_section_index(content_dir, section)
            
            logger.info("Generated section index files")
            return True
            
        except Exception as e:
            logger.error(f"Failed to generate section indices: {e}")
            return False
    
    def generate_layouts(self, output_path: str) -> bool:
        """
        Generate Hugo layout templates
        
        Args:
            output_path: Output directory path
            
        Returns:
            True if successful, False otherwise
        """
        try:
            output_dir = Path(output_path)
            layouts_dir = output_dir / 'layouts'
            layouts_dir.mkdir(parents=True, exist_ok=True)
            
            # Generate base layout
            self._generate_base_layout(layouts_dir)
            
            # Generate default layouts
            self._generate_default_layouts(layouts_dir)
            
            # Generate shortcodes
            self._generate_shortcodes(layouts_dir)
            
            logger.info("Generated Hugo layout templates")
            return True
            
        except Exception as e:
            logger.error(f"Failed to generate layouts: {e}")
            return False
    
    def _generate_main_index(self, content_dir: Path, devsite_structure: Dict) -> None:
        """Generate main _index.md file"""
        # Prepare context for main index
        context = {
            'title': self.config['hugo']['title'],
            'description': self.config['hugo']['description'],
            'sections': devsite_structure['sections'],
            'type': 'docs',
            'weight': 1
        }
        
        # Create the 4 main categories
        categories = [
            {
                'title': 'Tutorials',
                'path': '/tutorials/',
                'description': TUTORIALS_DESCRIPTION,
                'weight': 10
            },
            {
                'title': 'How-To Guides',
                'path': '/how-to-guides/',
                'description': HOW_TO_GUIDES_DESCRIPTION,
                'weight': 20
            },
            {
                'title': 'Explanations',
                'path': '/explanations/',
                'description': EXPLANATIONS_DESCRIPTION,
                'weight': 30
            },
            {
                'title': 'Reference',
                'path': '/reference/',
                'description': REFERENCE_DESCRIPTION,
                'weight': 40
            }
        ]
        
        # Render main index
        template = self.template_env.get_template('section_index.jinja2')
        index_content = template.render({
            'section': {
                'title': context['title'],
                'description': context['description'],
                'type': 'docs',
                'weight': 1,
                'subsections': categories
            }
        })
        
        # Write main index file
        index_file = content_dir / '_index.md'
        index_file.parent.mkdir(parents=True, exist_ok=True)
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write(index_content)
        
        # Generate category index files
        self._generate_category_indices(content_dir, devsite_structure)
        
        logger.debug(f"Generated main index: {index_file}")
    
    def _generate_category_indices(self, content_dir: Path, devsite_structure: Dict) -> None:
        """Generate _index.md files for the 4 main categories"""
        categories = {
            'tutorials': {
                'title': 'Tutorials',
                'description': TUTORIALS_DESCRIPTION,
                'weight': 10,
                'sections': []
            },
            'how-to-guides': {
                'title': 'How-To Guides', 
                'description': HOW_TO_GUIDES_DESCRIPTION,
                'weight': 20,
                'sections': []
            },
            'explanations': {
                'title': 'Explanations',
                'description': EXPLANATIONS_DESCRIPTION,
                'weight': 30,
                'sections': []
            },
            'reference': {
                'title': 'Reference',
                'description': REFERENCE_DESCRIPTION,
                'weight': 40,
                'sections': []
            }
        }
        
        # Group sections by category
        for section in devsite_structure['sections']:
            section_name = section['name']
            if section_name in self.config['content_mapping']:
                mapping = self.config['content_mapping'][section_name]
                category_type = mapping['type']
                if category_type in categories:
                    categories[category_type]['sections'].append(section)
        
        # Generate index file for each category
        for category_type, category_info in categories.items():
            category_dir = content_dir / category_type
            category_dir.mkdir(parents=True, exist_ok=True)
            
            # Prepare subsections
            subsections = []
            for section in category_info['sections']:
                subsections.append({
                    'title': section['title'],
                    'path': f"/{category_type}/{section['name']}/",
                    'description': f"{section['title']} documentation"
                })
            
            # Render category index
            template = self.template_env.get_template('section_index.jinja2')
            index_content = template.render({
                'section': {
                    'title': category_info['title'],
                    'description': category_info['description'],
                    'type': 'docs',
                    'weight': category_info['weight'],
                    'subsections': subsections
                }
            })
            
            # Write category index file
            index_file = category_dir / '_index.md'
            with open(index_file, 'w', encoding='utf-8') as f:
                f.write(index_content)
            
            logger.debug(f"Generated category index: {index_file}")
    
    def _generate_section_index(self, content_dir: Path, section: Dict) -> None:
        """Generate _index.md file for a section"""
        # Determine the category for this section
        section_name = section['name']
        category_type = 'docs'  # default
        
        if section_name in self.config['content_mapping']:
            mapping = self.config['content_mapping'][section_name]
            category_type = mapping['type']
        
        # Create section directory under its category
        section_dir = content_dir / category_type / section['name']
        section_dir.mkdir(parents=True, exist_ok=True)
        
        # Prepare subsections list
        subsections = []
        for file_info in section['files']:
            if file_info['name'] != '_index.md':
                subsections.append({
                    'title': file_info['title'],
                    'path': file_info['relative_path'].replace('.md', ''),
                    'description': f"{file_info['title']} documentation"
                })
        
        # Add subsections from subdirectories
        for subsection_name, subsection_info in section['subsections'].items():
            subsections.append({
                'title': subsection_name.replace('-', ' ').title(),
                'path': f"{subsection_name}/",
                'description': f"{subsection_name} documentation"
            })
        
        # Prepare context
        context = {
            'section': {
                'title': section['title'],
                'linkTitle': section['title'],
                'type': section['type'],
                'weight': section['weight'],
                'description': f"{section['title']} documentation and guides",
                'subsections': subsections
            }
        }
        
        # Render section index
        template = self.template_env.get_template('section_index.jinja2')
        index_content = template.render(context)
        
        # Write section index file
        index_file = section_dir / '_index.md'
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write(index_content)
        
        logger.debug(f"Generated section index: {index_file}")
        
        # Generate subsection indices recursively
        for subsection_name, subsection_info in section['subsections'].items():
            self._generate_subsection_index(section_dir, subsection_name, subsection_info)
    
    def _generate_subsection_index(self, parent_dir: Path, subsection_name: str, 
                                  subsection_info: Dict) -> None:
        """Generate _index.md file for a subsection"""
        subsection_dir = parent_dir / subsection_name
        subsection_dir.mkdir(parents=True, exist_ok=True)
        
        # Prepare subsections list
        subsections = []
        for file_info in subsection_info['files']:
            if file_info['name'] != '_index.md':
                subsections.append({
                    'title': file_info['title'],
                    'path': file_info['relative_path'].replace('.md', ''),
                    'description': f"{file_info['title']} documentation"
                })
        
        # Prepare context
        context = {
            'section': {
                'title': subsection_name.replace('-', ' ').title(),
                'linkTitle': subsection_name.replace('-', ' ').title(),
                'type': 'docs',
                'weight': 1,
                'description': f"{subsection_name} documentation and guides",
                'subsections': subsections
            }
        }
        
        # Render subsection index
        template = self.template_env.get_template('section_index.jinja2')
        index_content = template.render(context)
        
        # Write subsection index file
        index_file = subsection_dir / '_index.md'
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write(index_content)
        
        logger.debug(f"Generated subsection index: {index_file}")
    
    def generate_layouts(self, output_path: str) -> bool:
        """
        Generate Hugo layout templates
        
        Args:
            output_path: Output directory path
            
        Returns:
            True if successful, False otherwise
        """
        try:
            output_dir = Path(output_path)
            layouts_dir = output_dir / 'layouts'
            layouts_dir.mkdir(parents=True, exist_ok=True)
            
            # Generate base layout
            self._generate_base_layout(layouts_dir)
            
            # Generate default layouts
            self._generate_default_layouts(layouts_dir)
            
            # Generate shortcodes
            self._generate_shortcodes(layouts_dir)
            
            logger.info("Generated Hugo layout templates")
            return True
            
        except Exception as e:
            logger.error(f"Failed to generate layouts: {e}")
            return False
    
    def _generate_base_layout(self, layouts_dir: Path) -> None:
        """Generate base layout template"""
        baseof_content = '''<!DOCTYPE html>
<html lang="{{ .Site.LanguageCode | default "en" }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ .Title }} | {{ .Site.Title }}</title>
    <meta name="description" content="{{ .Description | default .Site.Params.description }}">
    <link rel="stylesheet" href="{{ $style.RelPermalink }}">
</head>
<body>
    <header>
        <div class="header-content">
            <a href="/" class="logo">{{ .Site.Title }}</a>
            <p class="tagline">{{ .Site.Params.description }}</p>
        </div>
    </header>
    
    <nav>
        <a href="/">Home</a>
        {{ range .Site.Menus.main }}
        <a href="{{ .URL }}">{{ .Name }}</a>
        {{ end }}
    </nav>
    
    <main class="content">
        {{ block "main" . }}{{ end }}
    </main>
    
    <footer>
        <p>&copy; {{ now.Year }} {{ .Site.Title }}. Documentation licensed under CC BY 4.0.</p>
    </footer>
</body>
</html>'''
        
        default_dir = layouts_dir / '_default'
        default_dir.mkdir(parents=True, exist_ok=True)
        
        baseof_file = default_dir / 'baseof.html'
        with open(baseof_file, 'w', encoding='utf-8') as f:
            f.write(baseof_content)
    
    def _generate_default_layouts(self, layouts_dir: Path) -> None:
        """Generate default layout templates"""
        default_dir = layouts_dir / '_default'
        default_dir.mkdir(parents=True, exist_ok=True)
        
        # Single page layout
        single_content = '''{{ define "main" }}
<h1>{{ .Title }}</h1>

{{ if .Description }}
<div class="description">
    <p>{{ .Description }}</p>
</div>
{{ end }}

<div class="content">
    {{ .Content }}
</div>
{{ end }}'''
        
        single_file = default_dir / 'single.html'
        with open(single_file, 'w', encoding='utf-8') as f:
            f.write(single_content)
        
        # List page layout
        list_content = '''{{ define "main" }}
<h1>{{ .Title }}</h1>

{{ if .Description }}
<div class="description">
    {{ .Content }}
    <h2>Pages in this section:</h2>
    <ul class="section-list">
    {{ range .Pages }}
        <li>
            <a href="{{ .RelPermalink }}">{{ .Title }}</a>
            {{ if .Description }}
            <p>{{ .Description }}</p>
            {{ end }}
        </li>
    {{ end }}
    </ul>
</div>
{{ else }}
<div class="content">
    {{ .Content }}
</div>
{{ end }}
{{ end }}'''
        
        list_file = default_dir / 'list.html'
        with open(list_file, 'w', encoding='utf-8') as f:
            f.write(list_content)
        
        # Home page layout
        index_content = '''{{ define "main" }}
<h1>{{ .Title }}</h1>

<div class="content">
    {{ .Content }}
    
    <h2>Documentation Sections</h2>
    <div class="section-grid">
    {{ range .Site.Menus.main }}
        <div class="section-card">
            <h3><a href="{{ .URL }}">{{ .Name }}</a></h3>
            <p>{{ .Post }}</p>
        </div>
    {{ end }}
    </div>
</div>
{{ end }}'''
        
        index_file = layouts_dir / 'index.html'
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write(index_content)
    
    def _generate_shortcodes(self, layouts_dir: Path) -> None:
        """Generate Hugo shortcodes"""
        shortcodes_dir = layouts_dir / 'shortcodes'
        shortcodes_dir.mkdir(parents=True, exist_ok=True)
        
        # TOC shortcode
        toc_content = '''<div class="toc">
    <h3>Table of Contents</h3>
    {{ .Page.TableOfContents }}
</div>'''
        
        toc_file = shortcodes_dir / 'toc.html'
        with open(toc_file, 'w', encoding='utf-8') as f:
            f.write(toc_content)
    
    def generate_menu_configuration(self, devsite_structure: Dict) -> Dict:
        """Generate Hugo menu configuration from Devsite structure"""
        menu_config = {
            'main': []
        }
        
        # Generate main menu from sections
        for section in devsite_structure['sections']:
            menu_item = {
                'name': section['title'],
                'url': f"/{section['name']}/",
                'weight': section['weight']
            }
            menu_config['main'].append(menu_item)
        
        return menu_config
