require 'spec_helper'

RSpec.describe Prawn::SVG::CSS::Stylesheets do
  describe 'typical usage' do
    let(:svg) { <<-SVG }
      <svg>
        <style>
          #inner rect { fill: #0000ff; }
          #outer { fill: #220000; }
          .hero > rect { fill: #00ff00; }
          rect { fill: #ff0000; }
          rect ~ rect { fill: #330000; }
          rect + rect { fill: #440000; }
          rect:first-child:last-child { fill: #441234; }

          circle:first-child { fill: #550000; }
          circle:nth-child(2) { fill: #660000; }
          circle:last-child { fill: #770000; }

          square[chocolate] { fill: #880000; }
          square[abc=def] { fill: #990000; }
          square[abc^=ghi] { fill: #aa0000; }
          square[abc$=jkl] { fill: #bb0000; }
          square[abc*=mno] { fill: #cc0000; }
          square[abc~=pqr] { fill: #dd0000; }
          square[abc|=stu] { fill: #ee0000; }
        </style>

        <rect width="1" height="1" />
        <rect width="2" height="2" id="outer" />

        <g class="hero large">
          <rect width="3" height="3" />
          <rect width="4" height="4" style="fill: #777777;" />
          <rect width="5" height="5" />

          <g id="inner">
            <rect width="6" height="6" />
          </g>

          <circle width="100" />

          <g id="circles">
            <circle width="7" />
            <circle width="8" />
            <circle width="9" />
          </g>
        </g>

        <square width="10" chocolate="hi there" />
        <square width="11" abc="def" />
        <square width="12" abc="ghidef" />
        <square width="13" abc="aghidefjkl" />
        <square width="14" abc="agmnohidefjklx" />
        <square width="15" abc="aeo cnj pqr" />
        <square width="16" abc="eij-stu-asd" />
      </svg>
    SVG

    it 'associates styles with elements' do
      result = Prawn::SVG::CSS::Stylesheets.new(CssParser::Parser.new, REXML::Document.new(svg)).load
      width_and_styles = result.map { |k, v| [k.attributes['width'].to_i, v] }.sort_by(&:first)

      expected = [
        [1, [['fill', '#ff0000', false]]],
        [2,
         [['fill', '#ff0000', false], ['fill', '#330000', false], ['fill', '#440000', false],
          ['fill', '#220000', false]]],
        [3, [['fill', '#ff0000', false], ['fill', '#00ff00', false]]],
        [4,
         [['fill', '#ff0000', false], ['fill', '#330000', false], ['fill', '#440000', false],
          ['fill', '#00ff00', false]]]
      ]

      expected << [5,
                   [['fill', '#ff0000', false], ['fill', '#330000', false], ['fill', '#440000', false],
                    ['fill', '#00ff00', false]]]

      expected.push(
        [6, [['fill', '#ff0000', false], ['fill', '#441234', false], ['fill', '#0000ff', false]]],
        [7, [['fill', '#550000', false]]],
        [8, [['fill', '#660000', false]]],
        [9, [['fill', '#770000', false]]],
        [10, [['fill', '#880000', false]]],
        [11, [['fill', '#990000', false]]],
        [12, [['fill', '#aa0000', false]]],
        [13, [['fill', '#bb0000', false]]],
        [14, [['fill', '#cc0000', false]]],
        [15, [['fill', '#dd0000', false]]],
        [16, [['fill', '#ee0000', false]]]
      )

      expect(width_and_styles).to eq(expected)
    end
  end

  describe '@font-face extraction' do
    let(:svg) do
      <<~SVG
        <svg>
          <style>
            @font-face {
              font-family: "CustomFont";
              src: url("custom.ttf") format("truetype");
              font-weight: bold;
            }
            rect { fill: red; }
          </style>
          <rect width="1" height="1" />
        </svg>
      SVG
    end

    it 'extracts @font-face rules separately from element styles' do
      stylesheets = Prawn::SVG::CSS::Stylesheets.new(CssParser::Parser.new, REXML::Document.new(svg))
      element_styles = stylesheets.load

      expect(stylesheets.font_face_rules.length).to eq(1)

      rule = stylesheets.font_face_rules.first
      decl_hash = {}
      rule.each { |name, value, _| decl_hash[name] = value }

      expect(decl_hash['font-family']).to eq('"CustomFont"')
      expect(decl_hash['src']).to eq('url("custom.ttf") format("truetype")')
      expect(decl_hash['font-weight']).to eq('bold')

      width_and_styles = element_styles.map { |k, v| [k.attributes['width'].to_i, v] }
      expect(width_and_styles).to eq([[1, [['fill', 'red', false]]]])
    end

    it 'handles multiple @font-face rules' do
      svg_with_two = <<~SVG
        <svg>
          <style>
            @font-face { font-family: "Font1"; src: url("font1.ttf"); }
            @font-face { font-family: "Font2"; src: url("font2.ttf"); font-weight: bold; }
          </style>
        </svg>
      SVG

      stylesheets = Prawn::SVG::CSS::Stylesheets.new(CssParser::Parser.new, REXML::Document.new(svg_with_two))
      stylesheets.load

      expect(stylesheets.font_face_rules.length).to eq(2)
    end
  end

  describe '@import' do
    let(:url_loader) { instance_double(Prawn::SVG::UrlLoader) }
    let(:warnings) { [] }

    it 'loads @import url() rules via the url_loader' do
      imported_css = 'rect { stroke: blue; }'
      allow(url_loader).to receive(:load).with('external.css').and_return(imported_css)

      svg = <<~SVG
        <svg>
          <style>
            @import url("external.css");
            rect { fill: red; }
          </style>
          <rect width="1" height="1" />
        </svg>
      SVG

      stylesheets = Prawn::SVG::CSS::Stylesheets.new(
        CssParser::Parser.new, REXML::Document.new(svg),
        url_loader: url_loader, warnings: warnings
      )
      result = stylesheets.load

      styles = result.values.first
      expect(styles).to include(['stroke', 'blue', false])
      expect(styles).to include(['fill', 'red', false])
    end

    it 'loads @import with bare string syntax' do
      imported_css = 'circle { fill: green; }'
      allow(url_loader).to receive(:load).with('styles.css').and_return(imported_css)

      svg = <<~SVG
        <svg>
          <style>
            @import "styles.css";
            rect { fill: red; }
          </style>
          <rect width="1" height="1" />
          <circle width="2" />
        </svg>
      SVG

      stylesheets = Prawn::SVG::CSS::Stylesheets.new(
        CssParser::Parser.new, REXML::Document.new(svg),
        url_loader: url_loader, warnings: warnings
      )
      result = stylesheets.load

      circle_styles = result.detect { |k, _| k.name == 'circle' }&.last
      expect(circle_styles).to include(['fill', 'green', false])
    end

    it 'handles nested @import rules' do
      allow(url_loader).to receive(:load).with('base.css').and_return('@import url("nested.css"); rect { stroke: blue; }')
      allow(url_loader).to receive(:load).with('nested.css').and_return('rect { stroke-width: 2; }')

      svg = <<~SVG
        <svg>
          <style>@import url("base.css");</style>
          <rect width="1" height="1" />
        </svg>
      SVG

      stylesheets = Prawn::SVG::CSS::Stylesheets.new(
        CssParser::Parser.new, REXML::Document.new(svg),
        url_loader: url_loader, warnings: warnings
      )
      result = stylesheets.load

      styles = result.values.first
      expect(styles).to include(['stroke-width', '2', false])
      expect(styles).to include(['stroke', 'blue', false])
    end

    it 'prevents circular @import references' do
      allow(url_loader).to receive(:load).with('a.css').and_return('@import url("b.css"); rect { fill: red; }')
      allow(url_loader).to receive(:load).with('b.css').and_return('@import url("a.css"); rect { stroke: blue; }')

      svg = <<~SVG
        <svg>
          <style>@import url("a.css");</style>
          <rect width="1" height="1" />
        </svg>
      SVG

      stylesheets = Prawn::SVG::CSS::Stylesheets.new(
        CssParser::Parser.new, REXML::Document.new(svg),
        url_loader: url_loader, warnings: warnings
      )
      result = stylesheets.load

      styles = result.values.first
      expect(styles).to include(['fill', 'red', false])
      expect(styles).to include(['stroke', 'blue', false])
    end

    it 'warns and continues when @import fails to load' do
      allow(url_loader).to receive(:load).with('missing.css').and_raise(Prawn::SVG::UrlLoader::Error, 'not found')

      svg = <<~SVG
        <svg>
          <style>
            @import url("missing.css");
            rect { fill: red; }
          </style>
          <rect width="1" height="1" />
        </svg>
      SVG

      stylesheets = Prawn::SVG::CSS::Stylesheets.new(
        CssParser::Parser.new, REXML::Document.new(svg),
        url_loader: url_loader, warnings: warnings
      )
      result = stylesheets.load

      expect(warnings).to include('Failed to load @import CSS from missing.css: not found')
      styles = result.values.first
      expect(styles).to include(['fill', 'red', false])
    end

    it 'does not attempt @import when no url_loader is provided' do
      svg = <<~SVG
        <svg>
          <style>
            @import url("external.css");
            rect { fill: red; }
          </style>
          <rect width="1" height="1" />
        </svg>
      SVG

      stylesheets = Prawn::SVG::CSS::Stylesheets.new(
        CssParser::Parser.new, REXML::Document.new(svg)
      )
      result = stylesheets.load

      styles = result.values.first
      expect(styles).to include(['fill', 'red', false])
    end
  end

  describe ':lang() pseudo-class' do
    it 'matches elements by xml:lang attribute' do
      svg = <<~SVG
        <svg xml:lang="en">
          <rect width="1" height="1" />
          <g xml:lang="fr">
            <rect width="2" height="2" />
          </g>
        </svg>
      SVG

      css_parser = CssParser::Parser.new
      css_parser.add_block!('rect:lang(en) { fill: red; } rect:lang(fr) { fill: blue; }')

      result = Prawn::SVG::CSS::Stylesheets.new(css_parser, REXML::Document.new(svg)).load
      width_and_styles = result.map { |k, v| [k.attributes['width'].to_i, v] }.sort_by(&:first)

      expect(width_and_styles).to eq([
                                       [1, [['fill', 'red', false]]],
                                       [2, [['fill', 'blue', false]]]
                                     ])
    end

    it 'matches with prefix matching (en matches en-US)' do
      svg = <<~SVG
        <svg xml:lang="en-US">
          <rect width="1" height="1" />
        </svg>
      SVG

      css_parser = CssParser::Parser.new
      css_parser.add_block!('rect:lang(en) { fill: red; }')

      result = Prawn::SVG::CSS::Stylesheets.new(css_parser, REXML::Document.new(svg)).load
      styles = result.values.first

      expect(styles).to eq([['fill', 'red', false]])
    end

    it 'inherits language from ancestors' do
      svg = <<~SVG
        <svg xml:lang="en">
          <g>
            <rect width="1" height="1" />
          </g>
        </svg>
      SVG

      css_parser = CssParser::Parser.new
      css_parser.add_block!('rect:lang(en) { fill: red; }')

      result = Prawn::SVG::CSS::Stylesheets.new(css_parser, REXML::Document.new(svg)).load
      styles = result.values.first

      expect(styles).to eq([['fill', 'red', false]])
    end
  end

  describe 'style tag parsing' do
    let(:svg) do
      <<~SVG
        <svg>
          <some-tag>
            <style>a
          before&gt;
          x <![CDATA[ y
          inside <>&gt;
          k ]]> j
          after
        z</style>
          </some-tag>

          <other-tag>
            <more-tag>
              <style>hello</style>
            </more-tag>
          </other-tag>
        </svg>
      SVG
    end

    it 'scans the document for style tags and adds the style information to the css parser' do
      css_parser = instance_double(CssParser::Parser)

      expect(css_parser).to receive(:add_block!).with("a\n  before>\n  x  y\n  inside <>&gt;\n  k  j\n  after\nz")
      expect(css_parser).to receive(:add_block!).with('hello')
      allow(css_parser).to receive(:each_rule_set)

      Prawn::SVG::CSS::Stylesheets.new(css_parser, REXML::Document.new(svg)).load
    end
  end
end
