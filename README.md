# Devsite to Hugo/Docsy Converter

A comprehensive Python utility that converts Google Devsite documentation to Hugo/Docsy format with dual GitHub Actions workflows for monitoring and site generation.

## Overview

This tool specifically converts the Bazel documentation from its source format at `https://github.com/bazelbuild/bazel/tree/master/site/en` to a Hugo static site using the Docsy theme. The conversion includes:

- Devsite-specific frontmatter to Hugo frontmatter conversion
- Directory structure transformation for Hugo/Docsy compatibility
- CSS/SCSS conversion for theme integration
- Automated GitHub Actions workflows for continuous updates
- Comprehensive validation and error handling

## Features

### Core Conversion Features
- **Markdown Processing**: Converts Devsite markdown files with proper frontmatter transformation
- **Directory Structure Mapping**: Transforms Devsite sections to Hugo content structure
- **CSS/SCSS Conversion**: Converts existing CSS to Hugo-compatible SCSS with variables and mixins
- **Navigation Generation**: Creates Hugo menu structure from Devsite `_book.yaml` and `_index.yaml`
- **Asset Handling**: Processes images and static assets for Hugo compatibility
- **Link Conversion**: Transforms internal links to use Hugo's relref shortcodes

### GitHub Actions Integration
- **Listener Workflow**: Monitors Bazel repository for changes every 30 minutes
- **Generator Workflow**: Triggered automatically when changes are detected
- **Repository Dispatch**: Secure communication between workflows
- **Incremental Updates**: Only processes changed files for efficiency

### Command Line Interface
- **Convert Command**: Full conversion with dry-run and incremental modes
- **Validate Command**: Validates converted Hugo site structure
- **Monitor Command**: Manual repository monitoring
- **Full Pipeline**: Complete conversion, build, and serve workflow

## Installation

### Prerequisites
- Python 3.12+
- Hugo Extended 0.146.0+
- Node.js 18+ (for PostCSS)
- Git

### Python Dependencies
```bash
pip install PyYAML requests gitpython click jinja2 markdown
