"""
CSS Converter Module
Handles conversion of CSS files to Hugo-compatible SCSS
"""

import os
import re
import logging
from pathlib import Path
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

class CSSConverter:
    """Converter for CSS files to Hugo-compatible SCSS"""
    
    def __init__(self, config: Dict):
        """Initialize converter with configuration"""
        self.config = config
        self.conversion_config = config.get('css_conversion', {})
        
    def convert_css_file(self, css_file: Path, output_dir: Path) -> bool:
        """
        Convert a CSS file to SCSS format
        
        Args:
            css_file: Path to source CSS file
            output_dir: Output directory for SCSS files
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Read source CSS
            with open(css_file, 'r', encoding='utf-8') as f:
                css_content = f.read()
            
            # Convert to SCSS
            scss_content = self._convert_css_to_scss(css_content)
            
            # Determine output file path
            output_file = output_dir / f"_{css_file.stem}.scss"
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Write SCSS file
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(scss_content)
            
            logger.debug(f"Converted CSS to SCSS: {css_file} -> {output_file}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to convert CSS file {css_file}: {e}")
            return False
    
    def _convert_css_to_scss(self, css_content: str) -> str:
        """Convert CSS content to SCSS format"""
        scss_content = css_content
        
        # Add SCSS header comment
        header = """// Converted from Devsite CSS to SCSS for Hugo/Docsy
// Generated automatically by devsite-to-hugo-converter

"""
        
        # Convert CSS custom properties to SCSS variables if configured
        if self.conversion_config.get('preserve_custom_properties', True):
            scss_content = self._convert_custom_properties(scss_content)
        
        # Add vendor prefixes handling
        scss_content = self._add_vendor_prefix_mixins(scss_content)
        
        # Convert color values to SCSS variables
        scss_content = self._extract_color_variables(scss_content)
        
        # Convert font definitions to SCSS variables
        scss_content = self._extract_font_variables(scss_content)
        
        # Add responsive breakpoint support
        scss_content = self._add_responsive_mixins(scss_content)
        
        return header + scss_content
    
    def _convert_custom_properties(self, css_content: str) -> str:
        """Convert CSS custom properties to SCSS variables"""
        # Find all CSS custom properties
        custom_prop_pattern = r'--([a-zA-Z0-9-]+):\s*([^;]+);'
        custom_props = re.findall(custom_prop_pattern, css_content)
        
        if not custom_props:
            return css_content
        
        # Generate SCSS variables section
        scss_vars = "\n// SCSS Variables (converted from CSS custom properties)\n"
        for prop_name, prop_value in custom_props:
            scss_var_name = prop_name.replace('-', '_')
            scss_vars += f"${scss_var_name}: {prop_value.strip()};\n"
        
        # Replace CSS custom property usage with SCSS variables
        modified_content = css_content
        for prop_name, _ in custom_props:
            css_var_usage = f"var(--{prop_name})"
            scss_var_usage = f"${prop_name.replace('-', '_')}"
            modified_content = modified_content.replace(css_var_usage, scss_var_usage)
        
        return scss_vars + "\n" + modified_content
    
    def _add_vendor_prefix_mixins(self, scss_content: str) -> str:
        """Add SCSS mixins for vendor prefixes"""
        mixins = """
// Vendor prefix mixins
@mixin transform($value) {
  -webkit-transform: $value;
  -moz-transform: $value;
  -ms-transform: $value;
  transform: $value;
}

@mixin transition($value) {
  -webkit-transition: $value;
  -moz-transition: $value;
  -ms-transition: $value;
  transition: $value;
}

@mixin box-shadow($value) {
  -webkit-box-shadow: $value;
  -moz-box-shadow: $value;
  box-shadow: $value;
}

@mixin border-radius($value) {
  -webkit-border-radius: $value;
  -moz-border-radius: $value;
  border-radius: $value;
}

"""
        return mixins + scss_content
    
    def _extract_color_variables(self, scss_content: str) -> str:
        """Extract color values and convert to SCSS variables"""
        # Find color values (hex, rgb, rgba, hsl, hsla)
        color_patterns = [
            r'#[0-9a-fA-F]{3,6}',
            r'rgb\([^)]+\)',
            r'rgba\([^)]+\)',
            r'hsl\([^)]+\)',
            r'hsla\([^)]+\)'
        ]
        
        colors = set()
        for pattern in color_patterns:
            colors.update(re.findall(pattern, scss_content))
        
        if not colors:
            return scss_content
        
        # Generate color variables
        color_vars = "\n// Color variables\n"
        color_map = {}
        
        for i, color in enumerate(sorted(colors)):
            var_name = f"$color-{i + 1}"
            color_vars += f"{var_name}: {color};\n"
            color_map[color] = var_name
        
        # Replace color values with variables
        modified_content = scss_content
        for color, var_name in color_map.items():
            modified_content = modified_content.replace(color, var_name)
        
        return color_vars + "\n" + modified_content
    
    def _extract_font_variables(self, scss_content: str) -> str:
        """Extract font definitions and convert to SCSS variables"""
        # Find font-family declarations
        font_pattern = r'font-family:\s*([^;]+);'
        fonts = set(re.findall(font_pattern, scss_content))
        
        if not fonts:
            return scss_content
        
        # Generate font variables
        font_vars = "\n// Font variables\n"
        font_map = {}
        
        for i, font in enumerate(sorted(fonts)):
            var_name = f"$font-family-{i + 1}"
            font_vars += f"{var_name}: {font};\n"
            font_map[font] = var_name
        
        # Replace font declarations with variables
        modified_content = scss_content
        for font, var_name in font_map.items():
            modified_content = modified_content.replace(f"font-family: {font};", f"font-family: {var_name};")
        
        return font_vars + "\n" + modified_content
    
    def _add_responsive_mixins(self, scss_content: str) -> str:
        """Add responsive breakpoint mixins"""
        responsive_mixins = """
// Responsive breakpoint mixins
$breakpoints: (
  mobile: 576px,
  tablet: 768px,
  desktop: 992px,
  large: 1200px
);

@mixin respond-to($breakpoint) {
  @if map-has-key($breakpoints, $breakpoint) {
    @media (min-width: map-get($breakpoints, $breakpoint)) {
      @content;
    }
  } @else {
    @warn "Unknown breakpoint: #{$breakpoint}.";
  }
}

@mixin respond-below($breakpoint) {
  @if map-has-key($breakpoints, $breakpoint) {
    @media (max-width: map-get($breakpoints, $breakpoint) - 1px) {
      @content;
    }
  } @else {
    @warn "Unknown breakpoint: #{$breakpoint}.";
  }
}

"""
        return responsive_mixins + scss_content
    
    def convert_devsite_styles(self, source_dir: Path, output_dir: Path) -> bool:
        """
        Convert all Devsite CSS files to Hugo-compatible SCSS
        
        Args:
            source_dir: Source directory containing CSS files
            output_dir: Output directory for SCSS files
            
        Returns:
            True if successful, False otherwise
        """
        try:
            css_files = list(source_dir.rglob('*.css'))
            
            if not css_files:
                logger.info("No CSS files found to convert")
                return True
            
            scss_dir = output_dir / 'scss'
            scss_dir.mkdir(parents=True, exist_ok=True)
            
            success_count = 0
            for css_file in css_files:
                if self.convert_css_file(css_file, scss_dir):
                    success_count += 1
            
            # Generate main SCSS file that imports all converted files
            self._generate_main_scss(scss_dir, css_files)
            
            logger.info(f"Converted {success_count}/{len(css_files)} CSS files to SCSS")
            return success_count == len(css_files)
            
        except Exception as e:
            logger.error(f"Failed to convert Devsite styles: {e}")
            return False
    
    def _generate_main_scss(self, scss_dir: Path, css_files: List[Path]) -> None:
        """Generate main SCSS file that imports all converted files"""
        main_scss = "// Main SCSS file for Bazel documentation\n"
        main_scss += "// Imports all converted Devsite CSS files\n\n"
        
        for css_file in css_files:
            import_name = css_file.stem
            main_scss += f"@import '{import_name}';\n"
        
        main_scss_file = scss_dir / '_main.scss'
        with open(main_scss_file, 'w', encoding='utf-8') as f:
            f.write(main_scss)
        
        logger.debug(f"Generated main SCSS file: {main_scss_file}")
