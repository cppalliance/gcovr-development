#!/opt/homebrew/Cellar/gcovr/8.6/libexec/bin/python
"""
Wrapper for gcovr that registers .ipp files as C++ for syntax highlighting.
"""

import sys

# Register .ipp extension with Pygments before importing gcovr
from pygments.lexers import get_lexer_by_name, _mapping

# Add .ipp to C++ lexer's filenames
cpp_lexer_info = _mapping.LEXERS.get('CppLexer')
if cpp_lexer_info:
    # Format: (module, classname, names, filenames, mimetypes)
    module, classname, names, filenames, mimetypes = cpp_lexer_info
    if '*.ipp' not in filenames:
        filenames = filenames + ('*.ipp',)
        _mapping.LEXERS['CppLexer'] = (module, classname, names, filenames, mimetypes)

# Now run gcovr
from gcovr.__main__ import main
sys.exit(main())
