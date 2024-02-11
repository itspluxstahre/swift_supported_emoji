import json
import subprocess
import os
import tempfile

# Function to test if Swift code compiles without errors
def test_swift_code(swift_code):
    with tempfile.NamedTemporaryFile(delete=False, suffix=".swift") as temp_file:
        temp_file_path = temp_file.name
        temp_file.write(swift_code.encode('utf-8'))
        temp_file.close()

        # Attempt to compile the Swift code
        # Modified to ignore encoding errors in stdout and stderr
        result = subprocess.run(['swift', temp_file_path], capture_output=True, text=True, errors='ignore')

        # Clean up the temporary file
        os.unlink(temp_file_path)

        # Return True if there's no error, False otherwise
        return result.stdout == "" and result.stderr == ""

# Prepare files to write supported and unsupported Swift code
supported_file = open('supported.swift', 'w', encoding='utf-8')
unsupported_file = open('unsupported.swift', 'w', encoding='utf-8')

# Read the JSON data
with open('data.raw.json', 'r', encoding='utf-8') as file:
    data = json.load(file)

for item in data:
    emoji = item['emoji']
    label = item['label'].replace(' ', '_')  # Replace spaces with underscores
    swift_line = f'let {emoji} = 1 /* {label} */\n'
    
    # Test if the Swift code compiles
    if test_swift_code(swift_line):
        supported_file.write(swift_line)
    else:
        unsupported_file.write(swift_line)

# Close the files
supported_file.close()
unsupported_file.close()

print('Done! Check supported.swift and unsupported.swift for the results.')
