prawn-svg
=========

An SVG renderer for the Prawn PDF library.

This will take an SVG file as input and render it into your PDF.  Find out more about the Prawn PDF library at:

  http://wiki.github.com/sandal/prawn/

Using prawn-svg
---------------

```ruby
Prawn::Document.generate("svg.pdf") do
  svg svg_data, :at => [x, y], :width => w
end
```
  
<tt>:at</tt> must be specified.

<tt>:width</tt>, <tt>:height</tt>, or neither may be specified; if neither is present,
the resolution specified in the SVG will be used.

<tt>:cache_images</tt>, if set to true, will cache images per document based on their URL.

Supported features
------------------

prawn-svg is in its infancy and does not support the full SVG specifications.  It currently supports:

 - <tt>line</tt> tag
 - <tt>polyline</tt> tag
 - <tt>polygon</tt> tag
 - <tt>circle</tt> tag
 - <tt>ellipse</tt> tag (although this seems to be buggy)
 
 - <tt>rect</tt> tag
   supports rounded rects, but only one radius is applied to all corners
 
 - <tt>path</tt> tag
   supports moveto, closepath, lineto, horiz lineto, vert lineto, curveto, smooth curveto, quad curveto, smooth quad curveto
   does not support elliptical arc
 
 - <tt>text</tt> and <tt>tspan</tt> tags
   attributes: size, text-anchor, font-family, font-weight, dx, dy
   
 - <tt>svg</tt>, <tt>g</tt> and <tt>symbol</tt> tags
   
 - <tt>use</tt> tag
   
 - <tt>style</tt> tag, if css_parser gem is installed on the system (see CSS section below)

 - <tt>image</tt> tag, only with http/https schemes; does not support 'slice' preserveAspectRatio
   
 - attributes/styles: <tt>fill</tt>, <tt>stroke</tt>, <tt>stroke-width</tt>, <tt>opacity</tt>, <tt>fill-opacity</tt>, <tt>stroke-opacity</tt>, <tt>transform</tt>
 
 - transform methods: <tt>translate</tt>, <tt>rotate</tt>, <tt>scale</tt>, <tt>matrix</tt>
 
 - colors: HTML standard names, <tt>#xxx</tt>, <tt>#xxxxxx</tt>, <tt>rgb(1, 2, 3)</tt>, <tt>rgb(1%, 2%, 3%)</tt>
 
 - measurements specified in <tt>pt</tt>, <tt>cm</tt>, <tt>dm</tt>, <tt>ft</tt>, <tt>in</tt>, <tt>m</tt>, <tt>mm</tt>, <tt>yd</tt>, <tt>%</tt>
 
 - fonts: generic CSS fonts, built in PDF fonts, and any TTF fonts in your fonts path

By default, prawn-svg has a fonts path of <tt>["/Library/Fonts", "/usr/share/fonts/truetype/**"]</tt> to catch
Mac OS X and Debian Linux users.  You can add to the font path:

```ruby
  Prawn::Svg.font_path << "/my/font/directory"
```

CSS
---

If the css_parser gem is installed, it will handle CSS style definitions, but only simple tag, class or id definitions.  It's very basic
so do not expect too much of it.

Not supported
-------------

prawn-svg does NOT support external references, measurements in en or em, sub-viewports, gradients/patterns or markers.

--
Copyright Roger Nesbitt <roger@seriousorange.com>.  MIT licence.
