#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
qxmlstream_header="${REPO_DIR}/qt/src/corelib/xml/qxmlstream.h"
ui4_cpp="${REPO_DIR}/qt/src/tools/uic/ui4.cpp"

for required_file in "${qxmlstream_header}" "${ui4_cpp}"; do
    if [[ ! -f "${required_file}" ]]; then
        echo "ERROR: ${required_file} not found; initialize the qt submodule first" >&2
        exit 1
    fi
done

python3 - "${qxmlstream_header}" "${ui4_cpp}" <<'PY'
from pathlib import Path
import sys

qxmlstream = Path(sys.argv[1])
ui4 = Path(sys.argv[2])

text = qxmlstream.read_text()
replacements = [
    (
        '''    inline QXmlStreamStringRef(const QStringRef &aString)\n        :m_string(aString.string()?*aString.string():QString()), m_position(aString.position()), m_size(aString.size()){}''',
        '''    inline QXmlStreamStringRef(const QStringRef &aString)\n        :m_string(aString.toString()), m_position(0), m_size(m_string.size()){}''',
    ),
    ('Q_DECLARE_TYPEINFO(QXmlStreamAttribute, Q_MOVABLE_TYPE);',
     'Q_DECLARE_TYPEINFO(QXmlStreamAttribute, Q_COMPLEX_TYPE);'),
    ('Q_DECLARE_TYPEINFO(QXmlStreamNamespaceDeclaration, Q_MOVABLE_TYPE);',
     'Q_DECLARE_TYPEINFO(QXmlStreamNamespaceDeclaration, Q_COMPLEX_TYPE);'),
    ('Q_DECLARE_TYPEINFO(QXmlStreamNotationDeclaration, Q_MOVABLE_TYPE);',
     'Q_DECLARE_TYPEINFO(QXmlStreamNotationDeclaration, Q_COMPLEX_TYPE);'),
    ('Q_DECLARE_TYPEINFO(QXmlStreamEntityDeclaration, Q_MOVABLE_TYPE);',
     'Q_DECLARE_TYPEINFO(QXmlStreamEntityDeclaration, Q_COMPLEX_TYPE);'),
]
changed = False
for old, new in replacements:
    if new in text:
        continue
    if old not in text:
        raise SystemExit(f"ERROR: patch target not found in {qxmlstream}: {old!r}")
    text = text.replace(old, new)
    changed = True
if changed:
    qxmlstream.write_text(text)
    print(f"{qxmlstream}: applied Qt4 XML stream copy-safety patches")
else:
    print(f"{qxmlstream}: Qt4 XML stream copy-safety patches already applied")

text = ui4.read_text()
old = '    foreach (const QXmlStreamAttribute &attribute, reader.attributes()) {\n'
new = ('    const QXmlStreamAttributes attributes = reader.attributes();\n'
       '    for (int attributeIndex = 0; attributeIndex < attributes.size(); ++attributeIndex) {\n'
       '        const QXmlStreamAttribute &attribute = attributes.at(attributeIndex);\n')
if old in text:
    text = text.replace(old, new)
    ui4.write_text(text)
    print(f"{ui4}: replaced direct foreach over reader.attributes()")
elif new in text:
    print(f"{ui4}: direct foreach over reader.attributes() already replaced")
else:
    raise SystemExit(f"ERROR: reader.attributes() foreach pattern not found in {ui4}")
PY
