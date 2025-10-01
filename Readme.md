 # Palette and LUT Generator

A utility written in zig for generating color palettes and lookup tables from PNG images.

## Overview

PngToPalette extracts color information from PNG files and generates color palettes and/or lookup tables (LUTs) that can be used in graphics programming, game development, or image processing applications.

## Features

- Extract color palettes from PNG images
- ~~Generate lookup tables for color mapping~~ work in progress
- ~~Support for various output formats~~
- ~~Configurable output options~~

## Installation

### Prerequisites
- Zig 0.15.1

### Building from Source

```bash
git clone https://github.com/FColor04/palette-and-lut-generator.git
cd PngToPalette
zig build
```

## Usage

```bash
./PngToPalette -p input.png
```

### Available Flags

- `-p, -path`: Path to the input PNG file
- `-d, -data`: Raw data input (alternative to providing a file path)
- `-o, -output`: Path for the output file

### Examples

```bash
# Generate a palette from a PNG file
./pngtopalette -p sprites.png -o game_palette.pal

# Generate a LUT with specific options
./pngtopalette -p colormap.png -o lookup.lut
```

## Output Formats

The tool can generate outputs in various formats suitable for different use cases:

- ~~Color palette files (`.pal`)~~
- ~~Lookup tables (`.lut`)~~
- ~~Raw color data (`.bin`)~~

## License

This project is licensed under the MIT License - see the LICENSE file for details.