# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Python-based tool that converts Google Devsite documentation (from bazel.build/docs) into Hugo/Docsy format for easier navigation and modification. The converter transforms Devsite frontmatter, directory layout, and styling to be compatible with the Hugo static site generator and Docsy theme.

## Core Commands

### Running the Converter
```bash
# Basic conversion
python cli.py convert --source /path/to/devsite/source --output /path/to/hugo/output

# With dry run validation
python cli.py convert --source /path/to/devsite/source --output /path/to/hugo/output --dry-run

# Incremental conversion (only changed files)
python cli.py convert --source /path/to/devsite/source --output /path/to/hugo/output --incremental

# View converter info
python cli.py info
```

### Environment Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Or using the project setup
pip install -e .
```

### Docker Usage
```bash
# Run the Docker container
docker run -it -p 1313:1313 alan707/bazel-docs:latest bash

# Inside container: convert docs
python /app/cli.py convert --source /app/work/bazel-source/site/en/ --output /app/docs/

# Inside container: setup Hugo modules and run server
cd /app/docs
hugo mod init github.com/alan707/bazel-docs && \
    hugo mod get github.com/google/docsy@v0.12.0 && \
    hugo mod tidy
hugo server --bind 0.0.0.0 --baseURL "http://localhost:1313"
```

## Architecture

### Core Components

1. **CLI Interface (`cli.py`)**: Click-based command line interface with convert and info commands
2. **Main Converter (`devsite_to_hugo_converter.py`)**: Orchestrates the conversion process using parser and generator
3. **Devsite Parser (`utils/devsite_parser.py`)**: Parses Google Devsite structure, including `_book.yaml` and `_index.yaml` files
4. **Hugo Generator (`utils/hugo_generator.py`)**: Generates Hugo site structure and configuration using Jinja2 templates

### Configuration System

The `config.yaml` file controls all aspects of the conversion:

- **Content Mapping**: Maps Devsite sections to Hugo categories (tutorials, how-to-guides, explanations, reference)
- **External Links**: Handles redirects to legacy Bazel API documentation
- **Code Language Detection**: Automatic language detection for code blocks using pattern matching
- **CSS Conversion**: Transforms CSS/SCSS for Docsy theme compatibility
- **File Patterns**: Controls which files are included/excluded during conversion

### Template System

Uses Jinja2 templates in the `templates/` directory:
- `hugo_config.yaml.jinja2`: Generates Hugo site configuration
- `section_index.jinja2`: Creates section index pages

### Content Organization

The converter maps Devsite sections to Hugo content types:
- Tutorials → tutorials category (weight 1-3)
- Install/Configure/Build guides → how-to-guides category
- Concepts/Extending → explanations category
- Reference materials → reference category

## Development Notes

### Code Language Detection
The system automatically detects programming languages for code blocks without explicit language identifiers using pattern matching defined in `config.yaml`. Supports Starlark (Bazel), Bash, Python, C++, Java, JavaScript, TypeScript, and more.

### Link Conversion
The converter handles both internal link conversion within the Hugo site and external link redirection to maintain compatibility with existing Bazel API documentation.

### CSS/SCSS Processing
PostCSS and Autoprefixer are used for CSS processing (see package.json dependencies), though the main conversion logic is in Python.