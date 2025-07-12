# Devsite to Hugo/Docsy Converter

## Overview

This is a comprehensive Python utility that converts Google Devsite documentation to Hugo/Docsy format with automated GitHub Actions workflows. The tool specifically targets Bazel documentation conversion, transforming source documentation from the Bazel repository into a Hugo static site with custom Bazel styling.

## Recent Changes (July 10, 2025)

✓ **Fixed Converter Root Cause**: Properly fixed duplicate title issue in the converter itself rather than bandaid fixes
✓ **Enhanced Title Extraction**: Converter now correctly extracts titles from H1 headers and removes duplicate H1 content
✓ **End-to-End Conversion Verified**: Successfully performed complete fresh conversion from Bazel repository to Hugo static site
✓ **Enhanced Converter Pipeline**: Updated converter to automatically handle all Devsite-specific syntax including:
  - Anchor ID attributes `{: #anchor-name }`
  - CSS class attributes `{:.class-name}` 
  - Jekyll include statements
  - Project/Book references
✓ **Automatic Title Management**: Converter now automatically prevents duplicate titles and adds missing titles from H1 headers
✓ **Complete Syntax Cleanup**: All 193 markdown files converted cleanly without parsing errors
✓ **Professional Styling**: Maintained custom Bazel green color scheme and responsive design
✓ **Working Navigation**: All 225 pages accessible with proper section lists and navigation structure
✓ **Production Ready**: Site serves flawlessly on port 5000 with live reload and complete functionality

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

The application follows a modular architecture with clear separation of concerns:

### Core Components
- **Main Converter**: `DevsiteToHugoConverter` class orchestrates the entire conversion process
- **Parser Module**: `DevsiteParser` handles parsing of Devsite documentation structure
- **Generator Module**: `HugoGenerator` creates Hugo site structure and configuration
- **CSS Converter**: `CSSConverter` transforms CSS files to Hugo-compatible SCSS
- **GitHub API Module**: `GitHubAPI` handles repository monitoring and API interactions
- **CLI Interface**: Command-line interface for user interaction

### Processing Pipeline
1. **Source Analysis**: Parse Devsite structure including `_book.yaml` and `_index.yaml`
2. **Content Transformation**: Convert markdown files with frontmatter transformation
3. **Asset Processing**: Handle images and static assets
4. **Navigation Generation**: Create Hugo menu structure
5. **CSS Conversion**: Transform existing CSS to SCSS with variables and mixins
6. **Site Generation**: Generate complete Hugo site structure

## Key Components

### Configuration Management
- **Configuration Loading**: YAML-based configuration system
- **Template Engine**: Jinja2 templating for generating Hugo configurations
- **Modular Settings**: Separate configuration sections for different components

### Content Processing
- **Markdown Processing**: Converts Devsite markdown with proper frontmatter transformation
- **Directory Structure Mapping**: Transforms Devsite sections to Hugo content structure
- **Link Conversion**: Transforms internal links to use Hugo's relref shortcodes
- **Asset Handling**: Processes images and static assets for Hugo compatibility

### Automation Features
- **GitHub Actions Integration**: Dual workflow system for monitoring and generation
- **Repository Monitoring**: Automated detection of changes in source repository
- **Incremental Processing**: Only processes changed files for efficiency
- **Validation System**: Comprehensive validation and error handling

## Data Flow

1. **Input**: Devsite documentation from Bazel repository
2. **Parsing**: Extract structure from `_book.yaml`, `_index.yaml`, and content files
3. **Transformation**: Convert markdown, frontmatter, and directory structure
4. **Asset Processing**: Handle CSS, images, and static assets
5. **Generation**: Create Hugo site structure with proper configuration
6. **Output**: Complete Hugo/Docsy compatible static site

### GitHub Actions Workflow
- **Listener Workflow**: Monitors Bazel repository every 30 minutes
- **Generator Workflow**: Triggered via repository dispatch when changes detected
- **Secure Communication**: Uses GitHub tokens for API authentication

## External Dependencies

### Python Dependencies
- **PyYAML**: Configuration and frontmatter parsing
- **requests**: GitHub API interactions
- **gitpython**: Git repository operations
- **click**: Command-line interface
- **jinja2**: Template rendering
- **markdown**: Markdown processing

### External Tools
- **Hugo Extended 0.146.0+**: Static site generation
- **Node.js 18+**: PostCSS processing
- **Git**: Version control operations

### APIs and Services
- **GitHub API**: Repository monitoring and webhook communication
- **GitHub Actions**: Automated workflow execution

## Deployment Strategy

### Local Development
- **CLI Interface**: Direct command-line usage for development and testing
- **Configuration Files**: YAML-based configuration for easy customization
- **Template System**: Jinja2 templates for flexible site generation

### Automated Deployment
- **GitHub Actions Workflows**: Continuous integration and deployment
- **Repository Dispatch**: Event-driven workflow triggering
- **Incremental Updates**: Efficient processing of only changed content

### Validation and Testing
- **Dry Run Mode**: Validate conversion without writing files
- **Structure Validation**: Comprehensive site structure validation
- **Error Handling**: Robust error handling and logging throughout the pipeline

The architecture prioritizes modularity, maintainability, and automation while providing flexibility for different deployment scenarios. The dual GitHub Actions workflow ensures continuous synchronization with the source repository while maintaining efficiency through incremental processing.