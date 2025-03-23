from qgis.core import *
from qgis.gui import *
import math


@qgsfunction(args="auto", group="Custom")
def calculate_size(map_scale, default_font_size, print_scale, feature, parent):
    """
    Calculate the label/symbol using the equation: dynamic_size = (default_font_size/2)*(1 + 3*exp(- (ln(default_font_size^0.5)/print_scale)*map_scale))
    Desmos expression -> y=\frac{c}{2}\ \left(\ 1+3\cdot e^{\left(-\frac{\ln(c^{0.5})}{k}\cdot x\right)}\right)
    Parameters:
    map_scale (numeric): @map_scale
    default_font_size (numeric): Font size at print scale
    print_scale (numeric): Print scale (must be > 0).
    """

    if default_font_size <= 0 or print_scale <= 0:
        raise ValueError("default_font_size and print_scale must be positive.")
    exponent = -(math.log(default_font_size**0.5) / print_scale) * map_scale
    return (default_font_size / 2) * (1 + 3 * math.exp(exponent))
