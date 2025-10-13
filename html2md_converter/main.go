package main

import (
	"archive/zip"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	md "github.com/JohannesKaufmann/html-to-markdown"
)

func main() {
	zipPath := flag.String("zip", "", "Path to the zip file containing HTML files")
	outputDir := flag.String("output", "output", "Output directory for markdown files")
	flag.Parse()

	if *zipPath == "" {
		fmt.Println("Error: -zip flag is required")
		flag.Usage()
		os.Exit(1)
	}

	if err := convertZipToMarkdown(*zipPath, *outputDir); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Conversion completed successfully!")
}

func convertZipToMarkdown(zipPath, outputDir string) error {
	// Open the zip file
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return fmt.Errorf("failed to open zip file: %w", err)
	}
	defer r.Close()

	// Create markdown converter
	converter := md.NewConverter("", true, nil)

	// Process each file in the zip
	for _, f := range r.File {
		if err := processZipFile(f, outputDir, converter); err != nil {
			return fmt.Errorf("failed to process %s: %w", f.Name, err)
		}
	}

	return nil
}

func processZipFile(f *zip.File, outputDir string, converter *md.Converter) error {
	// Skip directories
	if f.FileInfo().IsDir() {
		return nil
	}

	// Handle markdown files - copy them as-is
	if isMarkdownFile(f.Name) {
		return copyMarkdownFile(f, outputDir)
	}

	// Only process HTML files
	if !isHTMLFile(f.Name) {
		fmt.Printf("Skipping file: %s\n", f.Name)
		return nil
	}

	fmt.Printf("Processing: %s\n", f.Name)

	// Open the file from zip
	rc, err := f.Open()
	if err != nil {
		return fmt.Errorf("failed to open file in zip: %w", err)
	}
	defer rc.Close()

	// Read HTML content
	htmlBytes, err := io.ReadAll(rc)
	if err != nil {
		return fmt.Errorf("failed to read HTML content: %w", err)
	}

	// Convert HTML to Markdown
	markdown, err := converter.ConvertString(string(htmlBytes))
	if err != nil {
		return fmt.Errorf("failed to convert HTML to markdown: %w", err)
	}

	// Create output path (replace .html with .md)
	outputPath := filepath.Join(outputDir, changeExtension(f.Name, ".md"))

	// Create directory structure
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Write markdown file
	if err := os.WriteFile(outputPath, []byte(markdown), 0644); err != nil {
		return fmt.Errorf("failed to write markdown file: %w", err)
	}

	fmt.Printf("  -> Created: %s\n", outputPath)
	return nil
}

func isHTMLFile(filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	return ext == ".html" || ext == ".htm"
}

func isMarkdownFile(filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	return ext == ".md" || ext == ".markdown"
}

func isYAMLFile(filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	return ext == ".yaml" || ext == ".yml"
}

func copyMarkdownFile(f *zip.File, outputDir string) error {
	fmt.Printf("Copying markdown file: %s\n", f.Name)
	return copyFile(f, outputDir, f.Name)
}

func copyYAMLFile(f *zip.File, outputDir string) error {
	fmt.Printf("Copying YAML file: %s\n", f.Name)
	return copyFile(f, outputDir, f.Name)
}

func copyFile(f *zip.File, outputDir string, outputPath string) error {
	// Open the file from zip
	rc, err := f.Open()
	if err != nil {
		return fmt.Errorf("failed to open file in zip: %w", err)
	}
	defer rc.Close()

	// Read content
	content, err := io.ReadAll(rc)
	if err != nil {
		return fmt.Errorf("failed to read content: %w", err)
	}

	// Create output path
	fullOutputPath := filepath.Join(outputDir, outputPath)

	// Create directory structure
	if err := os.MkdirAll(filepath.Dir(fullOutputPath), 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Write file
	if err := os.WriteFile(fullOutputPath, content, 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	fmt.Printf("  -> Created: %s\n", fullOutputPath)
	return nil
}

func changeExtension(filename, newExt string) string {
	ext := filepath.Ext(filename)
	return filename[:len(filename)-len(ext)] + newExt
}
