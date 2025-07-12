# Devsite to Hugo/Docsy Converter

A Python utility that converts Google Devsite documentation to Hugo/Docsy format with dual GitHub Actions workflows for monitoring and site generation.

## Overview

This tool specifically converts the Bazel documentation from its source format at `https://github.com/bazelbuild/bazel/tree/master/site/en` to a Hugo static site using the Docsy theme. The conversion includes:

-   Devsite-specific frontmatter to Hugo frontmatter conversion
-   Directory structure transformation for Hugo/Docsy compatibility
-   CSS/SCSS conversion for theme integration
-   Automated GitHub Actions workflows for continuous updates
-   Comprehensive validation and error handling

## Usage
