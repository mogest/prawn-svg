# prawn-svg

[![Gem Version](https://badge.fury.io/rb/prawn-svg.svg)](https://badge.fury.io/rb/prawn-svg)
![Build Status](https://github.com/mogest/prawn-svg/actions/workflows/test.yml/badge.svg?branch=main)

An SVG renderer for the [Prawn PDF library](https://github.com/prawnpdf/prawn).

This will take an SVG document as input and render it into your PDF, along with whatever else you build with Prawn.

prawn-svg requires Prawn 2.3.0 or later, and Ruby 2.7 or later.

## Using prawn-svg

```ruby
Prawn::Document.generate("test.pdf") do
  svg '<svg><rect width="100" height="100" fill="red"></rect></svg>'
end
```

prawn-svg will do something sensible if you call it with only an SVG document, but you can also
pass the following options to tailor its operation.  Unknown options raise `ArgumentError`.

- **`:at`**\
  Type: `[x, y]` · Default: none\
  Location on the page to draw the SVG.

- **`:position`**\
  Type: `:left`, `:center`, `:right`, integer · Default: `:left`\
  Horizontal position, if `:at` isn't given.

- **`:vposition`**\
  Type: `:top`, `:center`, `:bottom`, integer · Default: current cursor position\
  Vertical position, if `:at` isn't given.

- **`:width`**\
  Type: integer · Default: horizontal space available\
  Desired width of the SVG.

- **`:height`**\
  Type: integer · Default: vertical space available\
  Desired height of the SVG.

- **`:web_requests`**\
  Type: boolean, callable · Default: `false`\
  If true, prawn-svg will fetch http and https URLs for images, `@font-face` fonts, `@import` stylesheets and external
  `<use>` references.  Requests go through [`ssrf_filter`](https://github.com/arkadiyt/ssrf_filter), which refuses
  private, loopback and link-local addresses.  Can also be a callable; see [Web requests](#web-requests).  `false`
  denies all web requests.

- **`:file_requests`**\
  Type: `false`, string, Pathname, callable · Default: `false`\
  If a directory path, prawn-svg will read `file:` URLs and relative paths for images, `@font-face` fonts, `@import`
  stylesheets and external `<use>` references from under that directory.  Can also be a callable; see
  [File requests](#file-requests).  Not available to SVGs loaded by `<image>`, or to content fetched from the web.
  `false` denies all file requests.

- **`:cache_requests`**\
  Type: Hash-like, `false` · Default: a new `Hash` for each render\
  Where responses are cached.  prawn-svg looks up each URL in it before making a request, and stores each successful
  response in it, so by default each URL is requested at most once per render.  To share the cache across renders, pass
  your own `Hash`, or any object with `[]` and `[]=` that returns `nil` for a missing key.  `false` turns caching off.
  Keys are URLs as written in the SVG.  Failed requests and `data:` URLs are not stored.  A cached response is returned
  without checking `:web_requests` or `:file_requests`.

- **`:fallback_font_name`**\
  Type: string, `nil` · Default: `"Times-Roman"`\
  Font used when the SVG asks for an unknown font.  If `nil`, prawn-svg will ignore a request for an unknown font and
  log a warning.

- **`:color_mode`**\
  Type: `:rgb`, `:cmyk` · Default: `:rgb`\
  Output color mode.

- **`:language`**\
  Type: string · Default: `"en"`\
  BCP 47 language tag for `<switch>` `systemLanguage` matching.

- **`:log_issues`**\
  Type: boolean · Default: `false`\
  If true, issues that occur when parsing/rendering the SVG are output to stderr via `warn`.  Use this when you're not
  getting the output you expect.

- **`:raise_on_issue`**\
  Type: boolean, symbol, array · Default: `false`\
  If true, raises `Prawn::SVG::IssueError` after rendering if any issues occurred.  If a category or array of
  categories, only issues in those categories raise, and an unknown category raises `ArgumentError`.  See
  [Issues](#issues).

- **`:max_work`**\
  Type: integer, `false` · Default: `1_000_000`\
  Limits how much work rendering may take, so that a small hostile SVG can't use excessive time or memory.  If exceeded,
  `Prawn::SVG::WorkLimitExceeded` is raised before anything is drawn.  One unit is roughly an element, a
  drawing call, a character of text, or a few hundred bytes of image data, counting every time `<use>`, markers,
  patterns, masks and clip paths repeat them.  Very large drawings, such as a path with millions of points, may need a
  higher value.  `false` turns the limit off.

## Examples

```ruby
  # Render the logo contained in the file logo.svg at 100, 100 with a width of 300
  svg IO.read("logo.svg"), at: [100, 100], width: 300

  # Render the logo at the current Y cursor position, centered in the current bounding box
  svg IO.read("logo.svg"), position: :center

  # Render the logo and allow loading of file: resources relative to its directory
  root_path = "/apps/myapp/current/images"
  svg IO.read("#{root_path}/logo.svg"), file_requests: root_path, log_issues: true
```

All options with their defaults:

```ruby
svg data,
  at:                 nil,           # [x, y]
  position:           :left,         # :left, :center, :right, integer
  vposition:          nil,           # :top, :center, :bottom, integer; nil = cursor
  width:              nil,           # nil = available width
  height:             nil,           # nil = available height
  web_requests:       false,         # true, callable
  file_requests:      false,         # directory path, callable
  cache_requests:     {},            # Hash-like, false; default is new per render
  fallback_font_name: "Times-Roman", # nil = skip unknown fonts
  color_mode:         :rgb,          # :rgb, :cmyk
  language:           "en",          # BCP 47 tag
  log_issues:         false,
  raise_on_issue:     false,         # true, category, [categories]
  max_work:           1_000_000      # false = unlimited
```

## Supported features

prawn-svg supports almost all of the full SVG 1.1 specification:

 - `<line>`, `<polyline>`, `<rect>`, `<polygon>`, `<circle>` and `<ellipse>`

 - `<path>`

 - `<text>`, `<tspan>`, `<tref>` and `<textPath>` with attributes `x`, `y`, `dx`, `dy`, `rotate`, `textLength`,
   `lengthAdjust`, and with extra properties `text-anchor`, `text-decoration`, `font`, `font-size`, `font-family`,
   `font-weight`, `font-style`, `font-stretch`, `kerning`, `letter-spacing`, `word-spacing`, `dominant-baseline`, `alignment-baseline`, `baseline-shift`.
   `<textPath>` supports `href`/`xlink:href` and `startOffset`.

 - `<svg>`, `<g>` and `<symbol>`

 - `<use>` with local and external references (e.g. `other.svg#elementId`), subject to `web_requests` and `file_requests`

 - `<style>` (see CSS section below)

 - `<image>` referencing a JPEG, PNG, or SVG image,  with `http:`, `https:`, `data:image/jpeg;base64`,
   `data:image/png;base64`, `data:image/svg+xml;base64` and `file:` schemes (`http:`, `https:` and `file:` are
   disabled by default for security reasons, see Options section above)

 - `<clipPath>` with `clipPathUnits` attribute and text content

 - `<mask>` with attributes `maskUnits` and `maskContentUnits`

 - `<marker>`

 - `<linearGradient>` and `<radialGradient>` are implemented with attributes `gradientUnits` and
   `gradientTransform`

 - `<pattern>` with attributes `patternUnits`, `patternContentUnits`, `patternTransform`, `viewBox`,
   `preserveAspectRatio`, and `href` inheritance.  Patterns can be used for both fill and stroke.
   Nested patterns (a pattern whose content references another pattern) are not supported.

 - `<switch>`, and conditional processing (`requiredFeatures`, `requiredExtensions`, `systemLanguage`)
   on the elements SVG 1.1 gives them to.
   `<foreignObject>` tags are ignored as prawn-svg cannot handle non-SVG data.

 - `<view>` element for defining named views.  Fragment identifiers (`#viewId` and `#svgView(...)`) on
   `<image>` hrefs select which view to render an external SVG with.

 - properties: `clip-path`, `clip-rule`, `color`, `display`, `fill`, `fill-opacity`, `fill-rule`, `opacity`, `overflow`,
   `stroke`, `stroke-dasharray`, `stroke-dashoffset`, `stroke-linecap`, `stroke-linejoin`, `stroke-miterlimit`, `stroke-opacity`, `stroke-width`,
   `visibility`

 - properties on lines, polylines, polygons and paths: `marker`, `marker-end`, `marker-mid`, `marker-start`

 - attributes on all elements: `class`, `id`, `style`, `transform`, `xml:space`

 - the `viewBox` attribute on `<svg>` and `<marker>` elements

 - the `preserveAspectRatio` attribute on `<svg>`, `<image>` and `<marker>` elements

 - transform methods: `translate`, `translateX`, `translateY`, `rotate`, `scale`, `skewX`, `skewY`, `matrix`

 - colors: HTML standard names, `#xxx`, `#xxxxxx`, `rgb(1, 2, 3)`, `rgb(1%, 2%, 3%)`, and also the non-standard
   `device-cmyk(1, 2, 3, 4)` for CMYK colors

 - measurements specified in `pt`, `cm`, `dm`, `ft`, `in`, `m`, `mm`, `yd`, `pc`, `%`

 - fonts: generic CSS fonts, built-in PDF fonts, and any TTF or TTC fonts in your fonts path, specified in any of
   the measurements above plus `em` or `rem`

 - `@font-face` in `<style>` blocks: `url()` sources (TTF/OTF formats) and `local()` references, with `font-weight`,
   `font-style` and `font-stretch` descriptors.  Font loading is subject to the `web_requests` and
   `file_requests` options.

## CSS

prawn-svg fully supports CSS2, both in `<style>` blocks and `style` attributes.

`@import` rules are supported for loading external stylesheets (requires `web_requests` or
`file_requests` options enabled).

In CSS selectors you can use element names, IDs, classes, attributes (existence, `=`, `^=`, `$=`, `*=`, `~=`, `|=`)
and all combinators (` `, `>`, `+`, `~`). The pseudo-classes `:first-child`, `:last-child`, `:link`, `:nth-child()`
and `:lang()` also work.  `:visited`, `:hover`, `:active`, and `:focus` are never matched. `!important` is
supported.

We made the call to ignore `@media` because it's not clear whether you're making a PDF to print it or show it on
the screen.

## Not supported

prawn-svg does not support filters, as rasterised effects is not something the PDF format was designed to handle.

writing-mode is partially supported: vertical-rl and vertical-lr (and SVG 1.1's tb-rl and tb) rotate the text 90 degrees, which
handles the common case of sideways Latin text.  CJK upright glyph orientation is not supported.

direction and unicode-bidi are not supported.

Features that will probably never be supported because either they don't make sense for PDF, they were deprecated
in SVG 2, and/or they are rarely used: filters, SVG fonts, altGlyph, font-size-adjust, glyph-orientation, rendering
hints, ICC color profiles, color-interpolation, enable-background, deprecated CSS clip, @media.

## Issues

When prawn-svg can't render something as a browser would, it records an issue and carries on.  `svg` returns them
in `result[:issues]` as `Prawn::SVG::Issue` objects, each with a `category` and `message`.  The categories are
`:unsupported` (a valid feature prawn-svg ignores), `:unknown` (a tag, attribute or property it doesn't recognise,
usually one browsers ignore too), `:invalid` (malformed SVG, such as an unusable value or a reference to a missing
element) and `:resource` (an image, font or stylesheet couldn't be loaded).

To reject SVGs that won't render as they would in a browser:

```ruby
  svg data, raise_on_issue: [:unsupported, :invalid, :resource]
```

SVG data that can't be parsed raises `Prawn::SVG::InvalidSVGData`.  prawn-svg's own errors, including
`Prawn::SVG::IssueError`, inherit from `Prawn::SVG::Error`.

## Configuration

### Web requests

`web_requests: true` uses `ssrf_filter` with Net::HTTP's default 60 second timeouts, giving up on any request that takes
longer than 30 seconds in total or whose response is larger than 20 MB after decompression.  To change how requests are made,
pass a callable as `:web_requests` instead.  prawn-svg provides two:

```ruby
  # ssrf_filter with your own options
  svg data, web_requests: Prawn::SVG::Requests::SsrfFilter.new(http_options: { open_timeout: 5 })

  # Net::HTTP with no address checks, for trusted SVGs that need internal hosts
  svg data, web_requests: Prawn::SVG::Requests::Unfiltered.new(open_timeout: 5)
```

`Requests::SsrfFilter` takes [ssrf_filter options](https://github.com/arkadiyt/ssrf_filter#options).  Setting a proxy in
`http_options` bypasses its address checks, and setting `verify_mode` can disable certificate checks.
`Requests::Unfiltered` takes `max_redirects` (default 10) and Net::HTTP options.  Both also take `total_timeout` in seconds
and `max_response_bytes`.

Your own callable is given a `URI` and returns the response body as a string.  If the resource can't be loaded, raise
`Prawn::SVG::Requests::Error` and it's reported as a `:resource` issue; any other error aborts rendering.
`Prawn::SVG::Requests::Http::EXPECTED_ERRORS` lists the network errors the provided callables rescue.

Content fetched from the web can only refer to other web or data URLs, which are resolved against its own URL, so it
can't read local files even when `:file_requests` is set.  Its `<use>` elements can't refer to data
URLs either.

### File requests

A directory path given as `:file_requests` reads files only from under that directory, resolving relative paths
against it and refusing paths that leave it, including through symlinks.  It is very dangerous to use `"/"` if you're
not fully in control of your input SVG.

```ruby
  # Read files from under a directory
  svg data, file_requests: "/apps/myapp/current/images"

  # Your own callable, here serving files from memory
  files = { "logo.png" => File.binread("logo.png") }
  svg data, file_requests: ->(path) { files.fetch(path) { raise Prawn::SVG::Requests::Error, "#{path} not found" } }
```

To change how files are read, pass a callable instead.  It is given the decoded path as a string, which may be
relative, and returns the file's contents as a binary string.  As with web requests, raise `Prawn::SVG::Requests::Error`
to report the file as a `:resource` issue.

### Fonts

By default, prawn-svg has a fonts path of `["/Library/Fonts", "/System/Library/Fonts",
"#{ENV["HOME"]}/Library/Fonts", "/usr/share/fonts/truetype"]` to catch MacOS and Debian Linux users.  You can add
to the font path:

```ruby
  Prawn::SVG::FontRegistry.font_path << "/my/font/directory"
```

### Using with prawn-rails

In your Gemfile, put `gem 'prawn-svg'` before `gem 'prawn-rails'` so that prawn-rails can see the prawn-svg extension.

### Deprecated options

These are still accepted from earlier versions.  If both a deprecated option and its replacement are given, the
replacement wins.

Deprecated | Replacement
---------- | -----------
`:enable_web_requests` | `:web_requests`.  Note that web requests are now off by default.
`:enable_file_requests_with_root` | `:file_requests`
`:cache_images` | `:cache_requests`.  `cache_images: true` is now the default; `cache_images: false` becomes `cache_requests: false`.
`:log_warnings` | `:log_issues`
`result[:warnings]` | `result[:issues]`, whose `message`s are the same strings
`Prawn::SVG::Document::InvalidSVGData` | `Prawn::SVG::InvalidSVGData`
`Prawn::SVG::Document::Error` | `Prawn::SVG::Error`

## Licence

MIT licence.  Copyright Mog Nesbitt.
