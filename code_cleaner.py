#!/usr/bin/env python3
"""
X-Seti - June02-2025 Code Cleaner - Remove Hidden Unicode Characters and Fix Formatting
Detects and removes invisible Unicode characters that break Python scripts

# Analyze a single file
python code_cleaner.py script.py

# Clean a file (creates backup)
python code_cleaner.py --clean script.py

# Clean multiple files without backup
python code_cleaner.py --clean --no-backup *.py

# Recursively clean all Python files in directory
python code_cleaner.py --clean --recursive .
"""

import re
import os
import sys
from pathlib import Path

class CodeCleaner:
   def __init__(self):
       # Common problematic Unicode characters
       self.hidden_chars = {
           '\u200b': 'ZERO WIDTH SPACE',
           '\u200c': 'ZERO WIDTH NON-JOINER',
           '\u200d': 'ZERO WIDTH JOINER',
           '\u2060': 'WORD JOINER',
           '\ufeff': 'BYTE ORDER MARK (BOM)',
           '\u00a0': 'NON-BREAKING SPACE',
           '\u2028': 'LINE SEPARATOR',
           '\u2029': 'PARAGRAPH SEPARATOR',
           '\u180e': 'MONGOLIAN VOWEL SEPARATOR',
           '\u034f': 'COMBINING GRAPHEME JOINER',
           '\u202a': 'LEFT-TO-RIGHT EMBEDDING',
           '\u202b': 'RIGHT-TO-LEFT EMBEDDING',
           '\u202c': 'POP DIRECTIONAL FORMATTING',
           '\u202d': 'LEFT-TO-RIGHT OVERRIDE',
           '\u202e': 'RIGHT-TO-LEFT OVERRIDE',
           '\u2066': 'LEFT-TO-RIGHT ISOLATE',
           '\u2067': 'RIGHT-TO-LEFT ISOLATE',
           '\u2068': 'FIRST STRONG ISOLATE',
           '\u2069': 'POP DIRECTIONAL ISOLATE',
       }

       # Invisible characters that might appear
       self.invisible_chars = set(self.hidden_chars.keys())

       # Add more invisible ranges
       for i in range(0x2000, 0x200f + 1):  # General punctuation spaces
           self.invisible_chars.add(chr(i))

       self.found_issues = []
       self.fixed_files = []

   def scan_file(self, filepath):
       """Scan a file for hidden characters and formatting issues"""
       issues = []

       try:
           with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
               content = f.read()

           # Check for hidden characters
           for line_num, line in enumerate(content.splitlines(), 1):
               for char_pos, char in enumerate(line):
                   if char in self.invisible_chars:
                       char_name = self.hidden_chars.get(char, f'U+{ord(char):04X}')
                       issues.append({
                           'type': 'hidden_char',
                           'line': line_num,
                           'column': char_pos + 1,
                           'char': char,
                           'name': char_name,
                           'context': line[max(0, char_pos-10):char_pos+10]
                       })

           # Check for mixed indentation
           indent_issues = self._check_indentation(content)
           issues.extend(indent_issues)

           # Check for unusual whitespace
           whitespace_issues = self._check_whitespace(content)
           issues.extend(whitespace_issues)

           return issues

       except Exception as e:
           return [{'type': 'error', 'message': f"Error reading file: {e}"}]

   def _check_indentation(self, content):
       """Check for mixed tabs/spaces and inconsistent indentation"""
       issues = []
       lines = content.splitlines()

       has_tabs = False
       has_spaces = False
       space_counts = []

       for line_num, line in enumerate(lines, 1):
           if not line.strip():  # Skip empty lines
               continue

           # Count leading whitespace
           leading = len(line) - len(line.lstrip())
           if leading == 0:
               continue

           leading_chars = line[:leading]

           # Check for tabs vs spaces
           if '\t' in leading_chars:
               has_tabs = True
           if ' ' in leading_chars:
               has_spaces = True

           # Count spaces for consistency checking
           if leading_chars.replace(' ', '') == '':  # Only spaces
               space_counts.append((line_num, leading))

       # Report mixed indentation
       if has_tabs and has_spaces:
           issues.append({
               'type': 'mixed_indent',
               'message': 'File contains both tabs and spaces for indentation'
           })

       # Check for inconsistent space indentation
       if space_counts and not has_tabs:
           indents = [count for _, count in space_counts if count > 0]
           if indents:
               # Find common factors (2, 4, 8 spaces)
               factors = []
               for factor in [2, 4, 8]:
                   if all(indent % factor == 0 for indent in indents):
                       factors.append(factor)

               if not factors:
                   issues.append({
                       'type': 'inconsistent_indent',
                       'message': 'Inconsistent indentation spacing detected',
                       'indents': indents[:10]  # Show first 10 examples
                   })

       return issues

   def _check_whitespace(self, content):
       """Check for unusual whitespace characters"""
       issues = []

       # Check for trailing whitespace
       for line_num, line in enumerate(content.splitlines(), 1):
           if line.endswith(' ') or line.endswith('\t'):
               issues.append({
                   'type': 'trailing_whitespace',
                   'line': line_num,
                   'message': 'Line has trailing whitespace'
               })

       return issues

   def clean_file(self, filepath, backup=True):
       """Clean a file by removing hidden characters and fixing formatting"""
       try:
           with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
               content = f.read()

           original_content = content

           # Create backup if requested
           if backup:
               backup_path = f"{filepath}.backup"
               with open(backup_path, 'w', encoding='utf-8') as f:
                   f.write(content)
               print(f"📦 Created backup: {backup_path}")

           # Remove hidden characters
           for char in self.invisible_chars:
               if char in content:
                   char_name = self.hidden_chars.get(char, f'U+{ord(char):04X}')
                   count = content.count(char)
                   content = content.replace(char, '')
                   print(f"🧹 Removed {count} instances of {char_name}")

           # Fix indentation (convert tabs to spaces)
           if '\t' in content:
               lines = content.splitlines()
               fixed_lines = []
               for line in lines:
                   # Convert leading tabs to 4 spaces
                   leading_tabs = 0
                   for char in line:
                       if char == '\t':
                           leading_tabs += 1
                       else:
                           break

                   if leading_tabs > 0:
                       new_line = '    ' * leading_tabs + line[leading_tabs:]
                       fixed_lines.append(new_line)
                   else:
                       fixed_lines.append(line)

               content = '\n'.join(fixed_lines)
               print(f"🔧 Converted {content.count(chr(9))} tabs to spaces")

           # Remove trailing whitespace
           lines = content.splitlines()
           cleaned_lines = [line.rstrip() for line in lines]
           content = '\n'.join(cleaned_lines)

           # Ensure file ends with newline
           if content and not content.endswith('\n'):
               content += '\n'

           # Write cleaned content
           with open(filepath, 'w', encoding='utf-8') as f:
               f.write(content)

           changes_made = len(original_content) != len(content) or original_content != content

           if changes_made:
               print(f"✅ Cleaned: {filepath}")
               self.fixed_files.append(str(filepath))
               return True
           else:
               print(f"👍 Already clean: {filepath}")
               return False

       except Exception as e:
           print(f"❌ Error cleaning {filepath}: {e}")
           return False

   def analyze_file(self, filepath):
       """Analyze a file and show detailed report"""
       print(f"\n🔍 Analyzing: {filepath}")
       print("=" * 50)

       issues = self.scan_file(filepath)

       if not issues:
           print("✅ No issues found!")
           return

       # Group issues by type
       by_type = {}
       for issue in issues:
           issue_type = issue['type']
           if issue_type not in by_type:
               by_type[issue_type] = []
           by_type[issue_type].append(issue)

       # Report hidden characters
       if 'hidden_char' in by_type:
           print(f"\n👻 Hidden Characters Found: {len(by_type['hidden_char'])}")
           for issue in by_type['hidden_char'][:10]:  # Show first 10
               print(f"  Line {issue['line']}, Col {issue['column']}: {issue['name']}")
               print(f"    Context: '{issue['context']}'")

       # Report indentation issues
       if 'mixed_indent' in by_type:
           print(f"\n🔀 Mixed Indentation:")
           for issue in by_type['mixed_indent']:
               print(f"  {issue['message']}")

       if 'inconsistent_indent' in by_type:
           print(f"\n📏 Inconsistent Indentation:")
           for issue in by_type['inconsistent_indent']:
               print(f"  {issue['message']}")
               if 'indents' in issue:
                   print(f"    Examples: {issue['indents']}")

       # Report whitespace issues
       if 'trailing_whitespace' in by_type:
           print(f"\n🔚 Trailing Whitespace: {len(by_type['trailing_whitespace'])} lines")

def main():
   import argparse

   parser = argparse.ArgumentParser(description='Clean Python files of hidden Unicode characters')
   parser.add_argument('files', nargs='+', help='Python files to check/clean')
   parser.add_argument('--clean', action='store_true', help='Clean files (default: just analyze)')
   parser.add_argument('--no-backup', action='store_true', help='Skip creating backup files')
   parser.add_argument('--recursive', '-r', action='store_true', help='Process directories recursively')

   args = parser.parse_args()

   cleaner = CodeCleaner()

   # Collect all files to process
   files_to_process = []

   for file_path in args.files:
       path = Path(file_path)

       if path.is_file():
           files_to_process.append(path)
       elif path.is_dir() and args.recursive:
           # Find all Python files
           py_files = list(path.glob('**/*.py'))
           files_to_process.extend(py_files)
           print(f"📁 Found {len(py_files)} Python files in {path}")
       elif path.is_dir():
           # Just direct Python files
           py_files = list(path.glob('*.py'))
           files_to_process.extend(py_files)
           print(f"📁 Found {len(py_files)} Python files in {path}")

   if not files_to_process:
       print("❌ No Python files found to process")
       return 1

   print(f"🎯 Processing {len(files_to_process)} files...")

   # Process each file
   total_issues = 0
   total_cleaned = 0

   for file_path in files_to_process:
       if args.clean:
           # Clean the file
           success = cleaner.clean_file(file_path, backup=not args.no_backup)
           if success:
               total_cleaned += 1
       else:
           # Just analyze
           issues = cleaner.scan_file(file_path)
           if issues:
               cleaner.analyze_file(file_path)
               total_issues += len(issues)

   # Summary
   print(f"\n📊 SUMMARY")
   print("=" * 30)

   if args.clean:
       print(f"✅ Files cleaned: {total_cleaned}")
       print(f"📁 Files processed: {len(files_to_process)}")
       if cleaner.fixed_files:
           print("\n🔧 Fixed files:")
           for file in cleaner.fixed_files:
               print(f"  {file}")
   else:
       print(f"🔍 Files analyzed: {len(files_to_process)}")
       print(f"⚠️  Total issues found: {total_issues}")
       print("\n💡 To fix issues, run with --clean flag")

   return 0

if __name__ == "__main__":
   sys.exit(main())
