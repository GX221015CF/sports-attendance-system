"""Rasterize the approved SVG and generate Android vector/adaptive resources.

Run from any directory: python design/branding/generate_android.py
Requires PyMuPDF in the authoring environment; adds no App dependency.
The selected SVG is the geometry source. Generated files are versioned.
"""

from pathlib import Path
import xml.etree.ElementTree as ET

import pymupdf


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'design/branding/20261025/duiqi.svg'
RES = ROOT / 'mobile_app/android/app/src/main/res'
ANDROID = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID)


def write_xml(path, element):
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(element, space='    ')
    path.write_bytes(ET.tostring(element, encoding='utf-8', xml_declaration=True) + b'\n')


def a(name):
    return f'{{{ANDROID}}}{name}'


def foreground(source, monochrome=False):
    vector = ET.Element('vector', {
        a('width'): '108dp', a('height'): '108dp',
        a('viewportWidth'): '216', a('viewportHeight'): '216',
    })
    # Slight optical normalization: the complete mark occupies >=48dp
    # and stays inside the centered 66dp safe area on a 108dp layer.
    group = ET.SubElement(vector, 'group', {
        a('pivotX'): '108', a('pivotY'): '108',
        a('scaleX'): '1.02', a('scaleY'): '1.02',
    })
    for child in source:
        tag = child.tag.rsplit('}', 1)[-1]
        if tag in ('title', 'desc', 'rect'):
            continue
        attrs = child.attrib
        if tag == 'circle':
            x, y, r = (float(attrs[k]) for k in ('cx', 'cy', 'r'))
            data = f'M{x-r:g},{y:g}a{r:g},{r:g} 0 1,0 {r*2:g},0a{r:g},{r:g} 0 1,0 {-r*2:g},0'
            values = {a('pathData'): data, a('fillColor'): '#FFFFFF' if monochrome else attrs['fill']}
            if not monochrome and 'opacity' in attrs:
                values[a('fillAlpha')] = attrs['opacity']
        elif tag == 'path':
            values = {
                a('pathData'): attrs['d'], a('fillColor'): '#00000000',
                a('strokeColor'): '#FFFFFF' if monochrome else attrs['stroke'],
                a('strokeWidth'): attrs['stroke-width'],
                a('strokeLineCap'): attrs['stroke-linecap'],
                a('strokeLineJoin'): attrs['stroke-linejoin'],
            }
        else:
            raise ValueError(f'Unsupported source element: {tag}')
        ET.SubElement(group, 'path', values)
    return vector


def rasterize(source, path, size, rounded=False):
    # Rendering a vector, rather than resizing an existing bitmap, keeps every
    # density faithful to the approved geometry and preserves transparent edges.
    svg = ET.fromstring(ET.tostring(source))
    svg.set('width', '216')
    svg.set('height', '216')
    if rounded:
        svg.find('{http://www.w3.org/2000/svg}rect').set('rx', '54')
    with pymupdf.open(stream=ET.tostring(svg), filetype='svg') as image:
        pdf = image.convert_to_pdf()
    with pymupdf.open(stream=pdf, filetype='pdf') as document:
        pixmap = document[0].get_pixmap(matrix=pymupdf.Matrix(size / 216, size / 216), alpha=True)
        if (pixmap.width, pixmap.height) != (size, size):
            raise ValueError('Unexpected rendered icon dimensions')
        path.parent.mkdir(parents=True, exist_ok=True)
        pixmap.save(path)


def main():
    source = ET.parse(SOURCE).getroot()
    assert source.attrib['viewBox'] == '0 0 216 216'
    write_xml(RES / 'drawable/ic_launcher_foreground.xml', foreground(source))
    write_xml(RES / 'drawable/ic_launcher_monochrome.xml', foreground(source, monochrome=True))
    for version in (26, 33):
        icon = ET.Element('adaptive-icon')
        ET.SubElement(icon, 'background', {a('drawable'): '@color/brand_background'})
        ET.SubElement(icon, 'foreground', {a('drawable'): '@drawable/ic_launcher_foreground'})
        if version == 33:
            ET.SubElement(icon, 'monochrome', {a('drawable'): '@drawable/ic_launcher_monochrome'})
        write_xml(RES / f'mipmap-anydpi-v{version}/ic_launcher.xml', icon)
    brand = ET.Element('resources')
    ET.SubElement(brand, 'string', {'name': 'app_name', 'translatable': 'false'}).text = '队齐'
    ET.SubElement(brand, 'color', {'name': 'brand_background'}).text = '#1E40AF'
    write_xml(RES / 'values/brand.xml', brand)
    for density, size in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        rasterize(source, RES / f'mipmap-{density}/ic_launcher.png', size, rounded=True)
    rasterize(source, ROOT / 'mobile_app/assets/branding/duiqi.png', 432)
    print('Generated 5 Android XML resources, 5 legacy icons, and 1 Flutter mark.')


if __name__ == '__main__':
    main()
