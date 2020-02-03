import sys

from lxml import html
import re
import requests

url = sys.argv[1]
page = requests.get(url)
tree = html.fromstring(page.content)
pattern = re.compile('^CentOS.*Minimal.*iso$')
for _file in tree.xpath('//a/@href'):
    if pattern.match(_file):
        print(url + "/" + _file)
