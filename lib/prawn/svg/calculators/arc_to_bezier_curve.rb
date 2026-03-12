module Prawn::SVG::Calculators
  module ArcToBezierCurve
    protected

    # Convert the elliptical arc to a cubic bézier curve using this algorithm:
    # http://www.spaceroots.org/documents/ellipse/elliptical-arc.pdf
    #
    # eta_1 and eta_2 are the eccentric anomaly angles (the parametric angles on the
    # unit circle that map to points on the ellipse). theta is the ellipse rotation angle.
    def calculate_bezier_curve_points_for_arc(cx, cy, a, b, eta_1, eta_2, theta)
      e = lambda do |eta|
        [
          cx + (a * Math.cos(theta) * Math.cos(eta)) - (b * Math.sin(theta) * Math.sin(eta)),
          cy + (a * Math.sin(theta) * Math.cos(eta)) + (b * Math.cos(theta) * Math.sin(eta))
        ]
      end

      ep = lambda do |eta|
        [
          (-a * Math.cos(theta) * Math.sin(eta)) - (b * Math.sin(theta) * Math.cos(eta)),
          (-a * Math.sin(theta) * Math.sin(eta)) + (b * Math.cos(theta) * Math.cos(eta))
        ]
      end

      iterations = 1
      d_eta = eta_2 - eta_1

      while iterations < 1024
        break if d_eta.abs <= Math::PI / 2.0

        iterations *= 2
        d_eta = (eta_2 - eta_1) / iterations
      end

      (0...iterations).collect do |iteration|
        seg_eta_a = eta_1 + (iteration * d_eta)
        seg_eta_b = eta_1 + ((iteration + 1) * d_eta)
        seg_d_eta = seg_eta_b - seg_eta_a

        alpha = Math.sin(seg_d_eta) * ((Math.sqrt(4 + (3 * (Math.tan(seg_d_eta / 2)**2))) - 1) / 3)

        x1, y1 = e[seg_eta_a]
        x2, y2 = e[seg_eta_b]

        ep_eta1_x, ep_eta1_y = ep[seg_eta_a]
        q1_x = x1 + (alpha * ep_eta1_x)
        q1_y = y1 + (alpha * ep_eta1_y)

        ep_eta2_x, ep_eta2_y = ep[seg_eta_b]
        q2_x = x2 - (alpha * ep_eta2_x)
        q2_y = y2 - (alpha * ep_eta2_y)

        { p2: [x2, y2], q1: [q1_x, q1_y], q2: [q2_x, q2_y] }
      end
    end
  end
end
