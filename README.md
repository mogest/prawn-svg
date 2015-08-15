# prawn-svg

An SVG renderer for the Prawn PDF library.

This will take an SVG file as input and render it into your PDF.  Find out more about the Prawn PDF library at:

  http://wiki.github.com/sandal/prawn/

prawn-svg is compatible with all versions of Prawn from 0.8.4 onwards, including the 1.x and 2.x series.

## Using prawn-svg

```ruby
Prawn::Document.generate("svg.pdf") do
  svg svg_data, :at => [x, y], :width => w
end
```

Supply <tt>:at</tt> if you want to render it at a specific location on the page.
Use <tt>:position</tt> with a value of <tt>:left</tt>, <tt>:center</tt>, <tt>:right</tt> or a number to render it at the current cursor position, or use <tt>:vposition</tt> with a value
of <tt>:top</tt>, <tt>:center</tt>, <tt>:bottom</tt> or a number to specify its Y position too.

Either <tt>:width</tt>, <tt>:height</tt>, or neither may be specified; if neither is present,
the dimensions specified in the SVG will be used, or if the dimensions aren't specified, it'll
fit to the space available on the page.

<tt>:cache_images</tt>, if set to true, will cache images per document based on their URL.

<tt>:fallback_font_name</tt> takes a font name which will override the default fallback font of Times-Roman.
If this value is set to <tt>nil</tt>, prawn-svg will ignore a request for an unknown font and log a warning.

## Supported features

prawn-svg supports most but not all of the full SVG 1.1 specification.  It currently supports:

 - <tt>&lt;line&gt;</tt>, <tt>&lt;polyline&gt;</tt>, <tt>&lt;polygon&gt;</tt>, <tt>&lt;circle&gt;</tt> and <tt>&lt;ellipse&gt;</tt>

 - <tt>&lt;rect&gt;</tt>.  Rounded rects are supported, but only one radius is applied to all corners.

 - <tt>&lt;path&gt;</tt> supports all commands defined in SVG 1.1, although the
   implementation of elliptical arc is a bit rough at the moment.

 - <tt>&lt;text&gt;</tt> and <tt>&lt;tspan&gt;</tt> with attributes
   <tt>text-anchor</tt>, <tt>font-size</tt>, <tt>font-family</tt>, <tt>font-weight</tt>, <tt>font-style</tt>, <tt>letter-spacing</tt>, <tt>dx</tt>, <tt>dy</tt>

 - <tt>&lt;svg&gt;</tt>, <tt>&lt;g&gt;</tt> and <tt>&lt;symbol&gt;</tt>

 - <tt>&lt;use&gt;</tt>

 - <tt>&lt;style&gt;</tt> plus <tt>id</tt>, <tt>class</tt> and <tt>style</tt> attributes (see CSS section below)

 - <tt>&lt;image&gt;</tt> with <tt>http:</tt>, <tt>https:</tt> and <tt>data:image/\*;base64</tt> schemes

 - <tt>&lt;clipPath&gt;</tt>

 - <tt>&lt;linearGradient&gt;</tt> but only with Prawn 2.0.3+. gradientTransform, spreadMethod and stop-opacity are
   unimplemented.

 - attributes/styles: <tt>fill</tt>, <tt>stroke</tt>, <tt>stroke-width</tt>, <tt>stroke-linecap</tt>, <tt>stroke-dasharray</tt>, <tt>opacity</tt>, <tt>fill-opacity</tt>, <tt>stroke-opacity</tt>, <tt>transform</tt>, <tt>clip-path</tt>, <tt>display</tt>

 - the <tt>viewBox</tt> attribute on the <tt>&lt;svg&gt;</tt> tag

 - the <tt>preserveAspectRatio</tt> attribute on the <tt>&lt;svg&gt;</tt> and <tt>&lt;image&gt;</tt> tags

 - transform methods: <tt>translate</tt>, <tt>rotate</tt>, <tt>scale</tt>, <tt>matrix</tt>

 - colors: HTML standard names, <tt>#xxx</tt>, <tt>#xxxxxx</tt>, <tt>rgb(1, 2, 3)</tt>, <tt>rgb(1%, 2%, 3%)</tt>

 - measurements specified in <tt>pt</tt>, <tt>cm</tt>, <tt>dm</tt>, <tt>ft</tt>, <tt>in</tt>, <tt>m</tt>, <tt>mm</tt>, <tt>yd</tt>, <tt>pc</tt>, <tt>%</tt>

 - fonts: generic CSS fonts, built-in PDF fonts, and any TTF fonts in your fonts path

## CSS

prawn-svg uses the css_parser gem to parse CSS <tt>&lt;style&gt;</tt> blocks.  It only handles simple tag, class or id selectors; attribute and other advanced selectors are not supported.

## Not supported

prawn-svg does not support external <tt>url()</tt> references, measurements in <tt>en</tt> or <tt>em</tt>, sub-viewports, radial gradients, patterns or markers.

## Configuration

### Fonts

By default, prawn-svg has a fonts path of <tt>["/Library/Fonts", "/System/Library/Fonts", "#{ENV["HOME"]}/Library/Fonts", "/usr/share/fonts/truetype"]</tt> to catch
Mac OS X and Debian Linux users.  You can add to the font path:

```ruby
  Prawn::SVG::Interface.font_path << "/my/font/directory"
```


--
Copyright Roger Nesbitt <roger@seriousorange.com>.  MIT licence.
