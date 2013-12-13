# prawn-svg

An SVG renderer for the Prawn PDF library.

This will take an SVG file as input and render it into your PDF.  Find out more about the Prawn PDF library at:

  http://wiki.github.com/sandal/prawn/

## Using prawn-svg

```ruby
Prawn::Document.generate("svg.pdf") do
  svg svg_data, :at => [x, y], :width => w
end
```

<tt>:at</tt> must be specified.

<tt>:width</tt>, <tt>:height</tt>, or neither may be specified; if neither is present,
the resolution specified in the SVG will be used.

<tt>:cache_images</tt>, if set to true, will cache images per document based on their URL.

<tt>:fallback_font_name</tt> takes a font name which will override the default fallback font of Times-Roman.
If this value is set to <tt>nil</tt>, prawn-svg will ignore a request for an unknown font and log a warning.

## Supported features

prawn-svg does not support the full SVG specification.  It currently supports:

 - <tt>&lt;line&gt;</tt>, <tt>&lt;polyline&gt;</tt>, <tt>&lt;polygon&gt;</tt>, and <tt>&lt;circle&gt;</tt>

 - <tt>&lt;ellipse&gt;</tt>

 - <tt>&lt;rect&gt;</tt>.  Rounded rects are supported, but only one radius is applied to all corners.

 - <tt>&lt;path&gt;</tt> supports all commands defined in SVG 1.1, although the
   implementation of elliptical arc is a bit rough at the moment.

 - <tt>&lt;text&gt;</tt> and <tt>&lt;tspan&gt;</tt> with attributes
   <tt>size</tt>, <tt>text-anchor</tt>, <tt>font-family</tt>, <tt>font-weight</tt>, <tt>dx</tt>, <tt>dy</tt>

 - <tt>&lt;svg&gt;</tt>, <tt>&lt;g&gt;</tt> and <tt>&lt;symbol&gt;</tt>

 - <tt>&lt;use&gt;</tt>

 - <tt>&lt;style&gt;</tt>, if css_parser gem is installed on the system (see CSS section below)

 - <tt>&lt;image&gt;</tt> with <tt>http:</tt>, <tt>https:</tt> and <tt>data:image/*;base64</tt> schemes

 - <tt>&lt;clipPath&gt;</tt>

 - attributes/styles: <tt>fill</tt>, <tt>stroke</tt>, <tt>stroke-width</tt>, <tt>opacity</tt>, <tt>fill-opacity</tt>, <tt>stroke-opacity</tt>, <tt>transform</tt>, <tt>clip-path</tt>

 - transform methods: <tt>translate</tt>, <tt>rotate</tt>, <tt>scale</tt>, <tt>matrix</tt>

 - colors: HTML standard names, <tt>#xxx</tt>, <tt>#xxxxxx</tt>, <tt>rgb(1, 2, 3)</tt>, <tt>rgb(1%, 2%, 3%)</tt>

 - measurements specified in <tt>pt</tt>, <tt>cm</tt>, <tt>dm</tt>, <tt>ft</tt>, <tt>in</tt>, <tt>m</tt>, <tt>mm</tt>, <tt>yd</tt>, <tt>%</tt>

 - fonts: generic CSS fonts, built in PDF fonts, and any TTF fonts in your fonts path

## CSS

If the css_parser gem is installed, it will handle CSS style definitions, but only simple tag, class or id definitions.  It's very basic
so do not expect too much of it.

## Not supported

prawn-svg does not support external references, measurements in <tt>en</tt> or <tt>em</tt>, sub-viewports, gradients/patterns or markers.

## Configuration

### Fonts

By default, prawn-svg has a fonts path of <tt>["/Library/Fonts", "/System/Library/Fonts", "#{ENV["HOME"]}/Library/Fonts", "/usr/share/fonts/truetype"]</tt> to catch
Mac OS X and Debian Linux users.  You can add to the font path:

```ruby
  Prawn::Svg::Interface.font_path << "/my/font/directory"
```


--
Copyright Roger Nesbitt <roger@seriousorange.com>.  MIT licence.
