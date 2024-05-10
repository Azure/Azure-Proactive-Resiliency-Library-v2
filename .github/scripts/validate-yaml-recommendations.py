required_packages = {
    "yamale": "yamale"
}

missing_packages = []
for package, module in required_packages.items():
    try:
        __import__(module)
    except ImportError:
        missing_packages.append(package)

if missing_packages:
    import subprocess
    for package_name in missing_packages:
        subprocess.check_call(['pip', 'install', required_packages[package_name]])

    # Verify installation
    missing_packages = []
    for package, module in required_packages.items():
        try:
            __import__(module)
        except ImportError as e:
            print(f"Failed to import {module}: {e}")
            missing_packages.append(package)

    if missing_packages:
        print("Failed to install required packages:")
        print(missing_packages)
        exit(1)

import os
import yamale

# Define the path to the schema file
schema_path = '.\\recommendation-schema.yaml'

# Define the directory containing YAML files
directory = '..\\..\\azure-resources'

# Make a schema object
schema = yamale.make_schema(schema_path)

# Function to validate a YAML file against the schema
def validate_yaml_file(file_path):
    # Create a Data object
    data = yamale.make_data(file_path)
    # Validate data against the schema. Throws a ValueError if data is invalid.
    yamale.validate(schema, data)

# Loop through directories within azure-resources
for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith('.yaml'):
            file_path = os.path.join(root, file)
            try:
                validate_yaml_file(file_path)
                print(f'{file_path}: Valid YAML')
            except ValueError as e:
                print(f'{file_path}: {e}')


