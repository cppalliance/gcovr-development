#!/usr/bin/env python3
"""
Build a JSON tree structure from gcovr HTML output.
This enables true inline expand/collapse in the sidebar.
"""

import json
import os
import re
import sys
from html.parser import HTMLParser
from pathlib import Path


class FileListParser(HTMLParser):
    """Parse gcovr HTML to extract file list entries and current path."""

    def __init__(self):
        super().__init__()
        self.entries = []
        self.current_path = ''
        self.in_file_row = False
        self.current_entry = {}
        self.capture_text = None
        self.in_breadcrumb = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Detect breadcrumb to extract current path
        if tag == 'div' and attrs_dict.get('class') == 'breadcrumb':
            self.in_breadcrumb = True

        # Detect file-row divs
        if tag == 'div' and 'class' in attrs_dict:
            classes = attrs_dict['class'].split()
            if 'file-row' in classes:
                self.in_file_row = True
                self.current_entry = {
                    'name': attrs_dict.get('data-filename', ''),
                    'coverage': attrs_dict.get('data-coverage', '0'),
                    'is_dir': 'directory' in classes,
                    'link': None
                }

        # Capture links in file rows
        if self.in_file_row and tag == 'a':
            href = attrs_dict.get('href', '')
            if href and not self.current_entry.get('link'):
                self.current_entry['link'] = href

        # Capture coverage percent
        if self.in_file_row and tag == 'span' and 'class' in attrs_dict:
            if 'coverage-percent' in attrs_dict['class']:
                self.capture_text = 'coverage'

    def handle_data(self, data):
        if self.capture_text == 'coverage' and self.in_file_row:
            match = re.search(r'([\d.]+)%?', data.strip())
            if match:
                self.current_entry['coverage'] = match.group(1)
            self.capture_text = None

    def handle_endtag(self, tag):
        if tag == 'div' and self.in_file_row and self.current_entry.get('name'):
            self.entries.append(self.current_entry)
            self.current_entry = {}
            self.in_file_row = False
        if tag == 'div' and self.in_breadcrumb:
            self.in_breadcrumb = False


def parse_html_file(filepath):
    """Parse a single HTML file and extract entries."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        parser = FileListParser()
        parser.feed(content)
        return parser.entries
    except Exception as e:
        print(f"Error parsing {filepath}: {e}", file=sys.stderr)
        return []


def get_coverage_class(coverage):
    """Determine coverage class based on percentage."""
    try:
        pct = float(coverage)
        if pct >= 90:
            return 'coverage-high'
        elif pct >= 75:
            return 'coverage-medium'
        else:
            return 'coverage-low'
    except:
        return 'coverage-unknown'


def clean_path(name):
    """Remove relative path prefixes like '../../../' from a path.

    Returns the cleaned path preserving directory structure.
    E.g., '../../detail/impl/foo.hpp' -> 'detail/impl/foo.hpp'
    """
    name = name.rstrip('/')

    # Remove leading ./ or ../
    while name.startswith('./') or name.startswith('../'):
        if name.startswith('./'):
            name = name[2:]
        elif name.startswith('../'):
            name = name[3:]

    return name if name else 'unknown'


def clean_display_name(name):
    """Extract clean display name from path.

    Removes relative path prefixes like '../../../' and extracts
    just the filename or last meaningful path segment.
    """
    # First clean the path
    name = clean_path(name)

    # If it still contains slashes, get the last segment
    if '/' in name:
        name = name.split('/')[-1]

    # Fallback if empty
    return name if name else 'unknown'


def is_file_path(path):
    """Check if a path looks like a file (has a file extension).

    More reliable than gcovr's directory class detection for paths with '../'.
    """
    # Clean the path first
    clean = clean_path(path)
    # Check for common source file extensions
    return bool(re.search(r'\.(hpp|ipp|cpp|h|c|cc|cxx|hxx|tpp|inl)$', clean, re.IGNORECASE))


def build_tree(output_dir):
    """Build complete tree structure by following links recursively."""
    output_path = Path(output_dir)

    # Map from HTML filename to entries
    file_entries = {}

    # Parse all HTML files
    for html_file in output_path.glob('index*.html'):
        entries = parse_html_file(html_file)
        file_entries[html_file.name] = entries

    def add_to_tree(nodes, path_parts, entry_data, base_path=''):
        """Add an entry to the tree, creating intermediate directories as needed."""
        if not path_parts:
            return

        name = path_parts[0]
        remaining = path_parts[1:]
        current_full_path = base_path + '/' + name if base_path else name

        # Find existing node for this level
        existing = None
        for node in nodes:
            if node.get('name') == name:
                existing = node
                break

        if remaining:
            # This is an intermediate directory - create if needed
            if not existing:
                existing = {
                    'name': name,
                    'fullPath': current_full_path,
                    'coverage': '-',
                    'coverageClass': 'coverage-unknown',
                    'isDirectory': True,
                    'link': None,
                    'children': []
                }
                nodes.append(existing)
            # Recurse into children
            add_to_tree(existing['children'], remaining, entry_data, current_full_path)
        else:
            # This is the final entry (file or directory)
            if existing:
                # Update existing node with entry data (preserve children)
                children = existing.get('children', [])
                existing.update(entry_data)
                if children and not existing.get('children'):
                    existing['children'] = children
            else:
                nodes.append(entry_data)

    def build_node_from_file(html_filename, current_path='', visited=None):
        """Recursively build tree from HTML file."""
        if visited is None:
            visited = set()

        if html_filename in visited:
            return []
        visited.add(html_filename)

        entries = file_entries.get(html_filename, [])
        nodes = []

        for entry in entries:
            raw_name = entry['name']
            cleaned_path = clean_path(raw_name)
            display_name = clean_display_name(raw_name)
            is_dir = not is_file_path(raw_name) and (entry['is_dir'] or '.' not in display_name)
            coverage = entry['coverage']
            link = entry['link']

            # Calculate relative path from current directory
            if current_path and cleaned_path.startswith(current_path + '/'):
                relative_path = cleaned_path[len(current_path) + 1:]
            elif current_path and cleaned_path == current_path:
                relative_path = display_name
            else:
                relative_path = cleaned_path

            path_parts = relative_path.split('/') if '/' in relative_path else [display_name]

            node_data = {
                'name': path_parts[-1] if path_parts else display_name,
                'fullPath': cleaned_path,
                'coverage': coverage,
                'coverageClass': get_coverage_class(coverage),
                'isDirectory': is_dir,
                'link': link,
                'children': []
            }

            # If directory with a link, recursively get its children
            if is_dir and link and link in file_entries:
                node_data['children'] = build_node_from_file(link, cleaned_path, visited.copy())

            # Add to tree, creating intermediate directories if needed
            if len(path_parts) > 1:
                add_to_tree(nodes, path_parts, node_data)
            else:
                nodes.append(node_data)

        # Sort: directories first, then files, alphabetically
        def sort_nodes(node_list):
            node_list.sort(key=lambda x: (not x['isDirectory'], x['name'].lower()))
            for n in node_list:
                if n.get('children'):
                    sort_nodes(n['children'])

        sort_nodes(nodes)
        return nodes

    # Start from index.html
    tree = build_node_from_file('index.html')
    return tree


def inject_tree_data(output_dir, tree):
    """Inject tree data as JavaScript variable into all HTML files."""
    output_path = Path(output_dir)
    tree_script = f'<script>window.GCOVR_TREE_DATA={json.dumps(tree)};</script>'

    count = 0
    for html_file in output_path.glob('*.html'):
        try:
            with open(html_file, 'r', encoding='utf-8') as f:
                content = f.read()

            # Remove any existing GCOVR_TREE_DATA injection (from previous runs)
            content = re.sub(
                r'<script>window\.GCOVR_TREE_DATA=.*?;</script>\n?',
                '',
                content
            )

            # Inject before </body>
            if '</body>' in content:
                content = content.replace('</body>', f'{tree_script}\n</body>')
                with open(html_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                count += 1
        except Exception as e:
            print(f"Warning: Could not inject into {html_file}: {e}", file=sys.stderr)

    return count


def main():
    if len(sys.argv) < 2:
        print("Usage: build_tree.py <gcovr_output_dir>", file=sys.stderr)
        sys.exit(1)

    output_dir = sys.argv[1]

    if not os.path.isdir(output_dir):
        print(f"Error: {output_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    tree = build_tree(output_dir)

    # Write tree.json
    tree_file = os.path.join(output_dir, 'tree.json')
    with open(tree_file, 'w', encoding='utf-8') as f:
        json.dump(tree, f, indent=2)

    print(f"Generated {tree_file} with {len(tree)} root entries")

    # Inject tree data into HTML files for local file:// access
    injected = inject_tree_data(output_dir, tree)
    print(f"Injected tree data into {injected} HTML files")


if __name__ == '__main__':
    main()
