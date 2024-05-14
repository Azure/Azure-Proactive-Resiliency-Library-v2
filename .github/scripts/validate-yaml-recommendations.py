required_packages = {
    "yamale": "yamale",
    "colorama": "colorama"
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
from colorama import init, Fore, Style

# Initialize colorama
init()

# Directories containing YAML files to validate
directories = {
    '../../azure-resources': './schemas/azure-resources-schema.yaml',
    '../../azure-specialized-workloads': './schemas/azure-specialized-workloads-schema.yaml',
    '../../azure-waf': './schemas/azure-waf-schema.yaml'
}

# Function to validate a YAML file against the schema
def validate_yaml_file(file_path, schema_path):
    # Make a schema object
    schema_obj = yamale.make_schema(schema_path)
    # Create a Data object
    data = yamale.make_data(file_path)
    try:
        # Validate data against the schema
        yamale.validate(schema_obj, data)
        print(f'{file_path}: {Fore.GREEN}Valid YAML{Style.RESET_ALL}')
    except ValueError as e:
        print(f'{file_path}: {Fore.RED}{e}{Style.RESET_ALL}')

print("Test Message: Validating YAML files against schemas")

# Loop through directories
for directory, schema_path in directories.items():
    print(f"Validating YAML files in directory: {directory}")
    for root, dirs, files in os.walk(directory):
        print(f"Validating YAML files in directory: {root}")
        for file in files:
            if file.endswith('.yaml'):
                file_path = os.path.join(root, file)
                validate_yaml_file(file_path, schema_path)
