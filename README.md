# prawn-svg

[![Gem Version](https://badge.fury.io/rb/prawn-svg.svg)](https://badge.fury.io/rb/prawn-svg)
![Build Status](https://github.com/mogest/prawn-svg/actions/workflows/test.yml/badge.svg?branch=main)

An SVG renderer for the [Prawn PDF library](https://github.com/prawnpdf/prawn).

This will take an SVG document as input and render it into your PDF, along with whatever else you build with Prawn.

prawn-svg is compatible with all versions of Prawn from 0.11.1 onwards, including the 1.x and 2.x series, although
you'll need version 2.2.0 onwards if you want color gradients.  The minimum Ruby version required is 2.7.

## Using prawn-svg

```ruby
Prawn::Document.generate("test.pdf") do
  svg '<svg><rect width="100" height="100" fill="red"></rect></svg>'
end
```

prawn-svg will do something sensible if you call it with only an SVG document, but you can also
pass the following options to tailor its operation:

Option      | Data type | Description
----------- | --------- | -----------
:at         | [integer, integer] | Specify the location on the page you want the SVG to appear.
:position   | :left, :center, :right, integer | If :at not specified, specifies the horizontal position to show the SVG.  Defaults to :left.
:vposition  | :top, :center, :bottom, integer | If :at not specified, specifies the vertical position to show the SVG.  Defaults to current cursor position.
:width      | integer   | Desired width of the SVG.  Defaults to horizontal space available.
:height     | integer   | Desired height of the SVG.  Defaults to vertical space available.
:enable_web_requests | boolean | If true, prawn-svg will make http and https requests to fetch images.  Defaults to true.
:enable_file_requests_with_root | string | If not nil, prawn-svg will serve `file:` URLs from your local disk if the file is located under the specified directory. It is very dangerous to specify the root path ("/") if you're not fully in control of your input SVG.  Defaults to `nil` (off).
:cache_images | boolean   | If true, prawn-svg will cache the result of all URL requests. Defaults to false.
:fallback_font_name | string | A font name which will override the default fallback font of Times-Roman.  If this value is set to `nil`, prawn-svg will ignore a request for an unknown font and log a warning.
:color_mode | :rgb, :cmyk | Output color mode.  Defaults to :rgb.

## Examples

```ruby
  # Render the logo contained in the file logo.svg at 100, 100 with a width of 300
  svg IO.read("logo.svg"), at: [100, 100], width: 300

  # Render the logo at the current Y cursor position, centered in the current bounding box
  svg IO.read("logo.svg"), position: :center

  # Render the logo at the current Y cursor position, and serve file: links relative to its directory
  root_path = "/apps/myapp/current/images"
  svg IO.read("#{root_path}/logo.svg"), enable_file_requests_with_root: root_path
```

## Supported features

prawn-svg supports most of the full SVG 1.1 specification.  It currently supports:

 - `<line>`, `<polyline>`, `<rect>`, `<polygon>`, `<circle>` and `<ellipse>`

 - `<path>`

 - `<text>`, `<tspan>`, `<tref>` and `<textPath>` with attributes `x`, `y`, `dx`, `dy`, `rotate`, `textLength`,
   `lengthAdjust`, and with extra properties `text-anchor`, `text-decoration`, `font`, `font-size`, `font-family`,
   `font-weight`, `font-style`, `font-stretch`, `kerning`, `letter-spacing`, `word-spacing`, `dominant-baseline`, `alignment-baseline`, `baseline-shift`.
   `<textPath>` supports `href`/`xlink:href` and `startOffset`.

 - `<svg>`, `<g>` and `<symbol>`

 - `<use>`

 - `<style>` (see CSS section below)

 - `<image>` referencing a JPEG, PNG, or SVG image,  with `http:`, `https:`, `data:image/jpeg;base64`,
   `data:image/png;base64`, `data:image/svg+xml;base64` and `file:` schemes (`file:` is disabled by default for
   security reasons, see Options section above)

 - `<clipPath>` with `clipPathUnits` attribute and text content

 - `<mask>` with attributes `maskUnits` and `maskContentUnits`

 - `<marker>`

 - `<linearGradient>` and `<radialGradient>` are implemented on Prawn 2.2.0+ with attributes `gradientUnits` and
   `gradientTransform`

 - `<pattern>` with attributes `patternUnits`, `patternContentUnits`, `patternTransform`, `viewBox`,
   `preserveAspectRatio`, and `href` inheritance.  Patterns can be used for both fill and stroke.
   Nested patterns (a pattern whose content references another pattern) are not supported.

 - `<switch>` and `<foreignObject>`, although prawn-svg cannot handle any data that is not SVG so `<foreignObject>`
   tags are always ignored.

 - properties: `clip-path`, `clip-rule`, `color`, `display`, `fill`, `fill-opacity`, `fill-rule`, `opacity`, `overflow`,
   `stroke`, `stroke-dasharray`, `stroke-dashoffset`, `stroke-linecap`, `stroke-linejoin`, `stroke-miterlimit`, `stroke-opacity`, `stroke-width`,
   `visibility`

 - properties on lines, polylines, polygons and paths: `marker-end`, `marker-mid`, `marker-start`

 - attributes on all elements: `class`, `id`, `style`, `transform`, `xml:space`

 - the `viewBox` attribute on `<svg>` and `<marker>` elements

 - the `preserveAspectRatio` attribute on `<svg>`, `<image>` and `<marker>` elements

 - transform methods: `translate`, `translateX`, `translateY`, `rotate`, `scale`, `skewX`, `skewY`, `matrix`

 - colors: HTML standard names, `#xxx`, `#xxxxxx`, `rgb(1, 2, 3)`, `rgb(1%, 2%, 3%)`, and also the non-standard
   `device-cmyk(1, 2, 3, 4)` for CMYK colors

 - measurements specified in `pt`, `cm`, `dm`, `ft`, `in`, `m`, `mm`, `yd`, `pc`, `%`

 - fonts: generic CSS fonts, built-in PDF fonts, and any TTF or TTC fonts in your fonts path, specified in any of
   the measurements above plus `em` or `rem`

## CSS

prawn-svg supports CSS, both in `<style>` blocks and `style` attributes.

In CSS selectors you can use element names, IDs, classes, attributes (existence, `=`, `^=`, `$=`, `*=`, `~=`, `|=`)
and all combinators (` `, `>`, `+`, `~`).
The pseudo-classes `:first-child`, `:last-child` and `:nth-child(n)` (where n is a number) also work.
`!important` is supported.

Pseudo-elements and the other pseudo-classes are not supported.

## Not supported

prawn-svg will not support filters, as rasterised effects is not something the PDF format was designed to handle.

Not yet implemented but intending to build: `<switch>`
conditional processing, `@font-face`, external `<use>` refs, marker shorthand, `<a>` target, `<view>`, CSS
@import/@media, `:lang` pseudo-class.

writing-mode, direction, and unicode-bidi are not supported.  It would be a lot of work to implement
non-LTR directions, and no-one has asked for it yet.

Will probably never be supported because either they don't make sense for PDF, they were deprecated in SVG 2, or
they are rarely used: filters, SVG fonts, altGlyph, font-size-adjust, glyph-orientation, rendering hints, ICC color
profiles, color-interpolation, enable-background, deprecated CSS clip.

## Configuration

### Fonts

By default, prawn-svg has a fonts path of `["/Library/Fonts", "/System/Library/Fonts",
"#{ENV["HOME"]}/Library/Fonts", "/usr/share/fonts/truetype"]` to catch MacOS and Debian Linux users.  You can add
to the font path:

```ruby
  Prawn::SVG::FontRegistry.font_path << "/my/font/directory"
```

### Using with prawn-rails

In your Gemfile, put `gem 'prawn-svg'` before `gem 'prawn-rails'` so that prawn-rails can see the prawn-svg extension.

## Licence

MIT licence.  Copyright Mog Nesbitt.
